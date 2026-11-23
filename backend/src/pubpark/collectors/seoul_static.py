"""Monthly Seoul static inventory; no realtime counts or bus fields are stored."""
import argparse
from contextlib import closing
from datetime import datetime, timedelta, timezone
import json
import logging
import math
import sqlite3
import sys
import time
from urllib.parse import quote

import requests

from pubpark.config import data_dir, load_local_env, required_env

KST = timezone(timedelta(hours=9))
SEOUL_URL = "http://openapi.seoul.go.kr:8088"
GEOCODE_URL = "https://maps.apigw.ntruss.com/map-geocode/v2/geocode"
# Explicit allowlist prevents new realtime/bus fields leaking into storage.
STATIC_FIELDS = (
    "PKLT_CD", "PKLT_NM", "ADDR", "PKLT_TYPE", "PRK_TYPE_NM", "OPER_SE",
    "OPER_SE_NM", "TELNO", "TPKCT", "PAY_YN", "PAY_YN_NM", "NGHT_PAY_YN",
    "NGHT_PAY_YN_NM", "WD_OPER_BGNG_TM", "WD_OPER_END_TM", "WE_OPER_BGNG_TM",
    "WE_OPER_END_TM", "LHLDY_OPER_BGNG_TM", "LHLDY_OPER_END_TM",
    "SAT_CHGD_FREE_SE", "SAT_CHGD_FREE_NM", "LHLDY_CHGD_FREE_SE",
    "LHLDY_CHGD_FREE_SE_NAME", "PRD_AMT", "STRT_PKLT_MNG_NO", "BSC_PRK_CRG",
    "BSC_PRK_HR", "ADD_PRK_CRG", "ADD_PRK_HR", "DAY_MAX_CRG", "SHRN_PKLT_MNG_NM",
    "SHRN_PKLT_MNG_URL", "SHRN_PKLT_YN", "SHRN_PKLT_ETC",
)
logger = logging.getLogger(__name__)


class CollectionError(RuntimeError):
    pass


def request_json(session, url, *, params=None, headers=None):
    """Bounded retry; never expose URLs, keys or provider error bodies in logs."""
    provider = "서울시" if url.startswith(SEOUL_URL + "/") else "네이버"
    for attempt in range(3):
        try:
            response = session.get(url, params=params, headers=headers, timeout=(10, 30))
            if response.status_code in (401, 403, 429):
                raise CollectionError(f"{provider} API 인증·권한·한도 오류: HTTP {response.status_code}")
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, dict):
                raise ValueError("Expected object")
            return payload
        except (requests.RequestException, ValueError):
            if attempt == 2:
                raise CollectionError(f"{provider} API 요청 또는 JSON 해석 실패 (3회 시도)") from None
            time.sleep(2 ** attempt)


def fetch_parking_lots(session, key):
    rows, expected, start = [], None, 1
    while expected is None or start <= expected:
        url = f"{SEOUL_URL}/{quote(key, safe='')}/json/GetParkingInfo/{start}/{start + 999}/"
        payload = request_json(session, url)
        body = payload.get("GetParkingInfo", {})
        result = body.get("RESULT", payload.get("RESULT", {}))
        if result.get("CODE") != "INFO-000":
            raise CollectionError("서울시 API가 성공 상태를 반환하지 않았습니다.")
        try:
            count = int(body["list_total_count"])
            page = body["row"]
        except (KeyError, TypeError, ValueError):
            raise CollectionError("서울시 응답 구조 오류") from None
        if count <= 0 or (expected is not None and count != expected):
            raise CollectionError("서울시 전체 건수가 비었거나 수집 중 변경되었습니다.")
        expected = count
        if not isinstance(page, list) or not page:
            raise CollectionError("서울시 페이지가 비었습니다.")
        rows.extend(page)
        start += 1000
    ids = [str(row.get("PKLT_CD", "")).strip() for row in rows if isinstance(row, dict)]
    if len(rows) != expected or len(ids) != expected or not all(ids) or len(set(ids)) != expected:
        raise CollectionError("서울시 응답 건수·주차장 ID 불일치")
    return rows


def geocode_address(session, address, client_id, client_secret):
    address = " ".join(str(address or "").split())
    if not address:
        return {"latitude": None, "longitude": None, "geocode_status": "missing_address"}
    query = address if address.startswith(("서울특별시", "서울시", "서울 ")) else f"서울특별시 {address}"
    payload = request_json(session, GEOCODE_URL, params={"query": query, "count": 2}, headers={
        "x-ncp-apigw-api-key-id": client_id,
        "x-ncp-apigw-api-key": client_secret,
        "Accept": "application/json",
    })
    if payload.get("status") != "OK":
        raise CollectionError("네이버 Geocoding 응답 오류")
    matches = payload.get("addresses")
    if not isinstance(matches, list):
        raise CollectionError("네이버 Geocoding 응답 구조 오류")
    result = {"latitude": None, "longitude": None, "geocode_query": query}
    if not matches:
        return {**result, "geocode_status": "no_match"}
    if len(matches) != 1 or int(payload.get("meta", {}).get("totalCount", len(matches))) != 1:
        return {**result, "geocode_status": "ambiguous"}
    match = matches[0]
    try:
        longitude, latitude = float(match["x"]), float(match["y"])
        if not (math.isfinite(latitude) and math.isfinite(longitude) and
                37 <= latitude <= 38 and 126 <= longitude <= 128):
            raise ValueError("Outside Seoul region")
    except (KeyError, TypeError, ValueError):
        return {**result, "geocode_status": "invalid_coordinates"}
    return {**result, "latitude": latitude, "longitude": longitude, "geocode_status": "ok",
            "geocoded_address": match.get("roadAddress") or match.get("jibunAddress")}


def refresh(database, session, seoul_key, client_id, client_secret, *, now=None, force=False):
    now = now or datetime.now(KST)
    if now.tzinfo is None:
        raise ValueError("now must have timezone")
    month = now.astimezone(KST).strftime("%Y-%m")
    timestamp = now.astimezone(KST).isoformat()
    database.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(database, timeout=1)) as connection, connection:
        connection.execute("CREATE TABLE IF NOT EXISTS refresh_state (id INTEGER PRIMARY KEY, month TEXT, refreshed_at TEXT)")
        connection.execute("CREATE TABLE IF NOT EXISTS parking_lots (id TEXT PRIMARY KEY, static_json TEXT NOT NULL, latitude REAL, longitude REAL, geocode_status TEXT NOT NULL, geocode_json TEXT NOT NULL, refreshed_at TEXT NOT NULL)")
        connection.commit()
        connection.execute("BEGIN IMMEDIATE")
        previous = connection.execute("SELECT month FROM refresh_state WHERE id=1").fetchone()
        if previous and previous[0] == month and not force:
            return {"status": "skipped", "month": month}
        old = {row[0]: (json.loads(row[1]), json.loads(row[2])) for row in
               connection.execute("SELECT id, static_json, geocode_json FROM parking_lots")}
        rows = fetch_parking_lots(session, seoul_key)
        prepared, resolved, reused = [], 0, 0
        for row in rows:
            pid = str(row["PKLT_CD"]).strip()
            static = {field: row.get(field) for field in STATIC_FIELDS}
            address = " ".join(str(row.get("ADDR") or "").split())
            prior = old.get(pid)
            if prior and " ".join(str(prior[0].get("ADDR") or "").split()) == address and prior[1].get("geocode_status") == "ok":
                geo = prior[1]
                reused += 1
            else:
                geo = geocode_address(session, address, client_id, client_secret)
                geo["geocoded_at"] = timestamp
            resolved += geo["geocode_status"] == "ok"
            prepared.append((pid, json.dumps(static, ensure_ascii=False), geo["latitude"],
                             geo["longitude"], geo["geocode_status"],
                             json.dumps(geo, ensure_ascii=False), timestamp))
        # Replacement and success marker commit together. Failure preserves old inventory.
        connection.execute("DELETE FROM parking_lots")
        connection.executemany("INSERT INTO parking_lots VALUES (?, ?, ?, ?, ?, ?, ?)", prepared)
        connection.execute("INSERT OR REPLACE INTO refresh_state VALUES (1, ?, ?)", (month, timestamp))
        return {"status": "updated", "month": month, "count": len(rows), "geocoded": resolved,
                "unresolved": len(rows) - resolved, "reused_coordinates": reused}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="이미 갱신한 달에도 다시 실행")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, stream=sys.stdout)
    try:
        load_local_env()
        with requests.Session() as session:
            result = refresh(data_dir() / "seoul_parking_static.sqlite3", session,
                             required_env("SEOUL_API_KEY"), required_env("NAVER_MAPS_CLIENT_ID"),
                             required_env("NAVER_MAPS_CLIENT_SECRET"), force=args.force)
        logger.info("서울시 정적 정보 갱신: %s", result)
    except CollectionError as error:
        logger.error("%s. 기존 데이터를 보존합니다.", error)
        raise SystemExit(1) from None
    except (ValueError, sqlite3.Error, OSError):
        logger.error("정적 정보 갱신 실패. .env 설정·API 권한·네트워크·DB 상태를 확인하세요. 기존 데이터는 보존됩니다.")
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
