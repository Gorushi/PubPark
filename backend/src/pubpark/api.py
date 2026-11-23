"""Local mobile API: geocoding, nearest parking, 5-minute Seoul availability, routes."""
import argparse
from contextlib import closing
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import sqlite3
import threading
import time

import requests

from pubpark.config import data_dir, load_local_env, required_env
from pubpark.collectors.seoul_static import (
    CollectionError, KST, fetch_parking_lots, geocode_address, request_json,
)


def distance_m(a, b):
    lat1, lat2 = math.radians(a["latitude"]), math.radians(b["latitude"])
    delta = math.radians(b["longitude"] - a["longitude"])
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(delta / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(min(1, max(0, h))))


def is_bus_only(fields):
    """Use operating category and explicit exclusive-use names, not bus fee fields."""
    category = "".join(str(fields.get("OPER_SE_NM") or "").split())
    name = "".join(str(fields.get("PKLT_NM") or "").split())
    return "버스전용" in category or "관광버스전용" in name


def point(value):
    if not isinstance(value, dict):
        raise ValueError("좌표가 필요합니다.")
    lat, lon = float(value["latitude"]), float(value["longitude"])
    if not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError("유효하지 않은 좌표입니다.")
    return {"latitude": lat, "longitude": lon}


def availability(row, total, now):
    """Unknown is never treated as empty; over-capacity observations are rejected."""
    if not row or str(row.get("PRK_STTS_YN")) != "1":
        return None, "unlinked", None
    stamp = str(row.get("NOW_PRK_VHCL_UPDT_TM") or "")
    try:
        updated = datetime.fromisoformat(stamp)
        if updated.tzinfo is None:
            updated = updated.replace(tzinfo=KST)
        age = (now - updated).total_seconds()
        if age > 1200 or age < -300:
            return None, "stale", updated.isoformat()
        occupied = float(row["NOW_PRK_VHCL_CNT"])
        if not occupied.is_integer() or total is None or total <= 0 or not 0 <= occupied <= total:
            return None, "inconsistent", updated.isoformat()
        return total - int(occupied), "ok", updated.isoformat()
    except (ValueError, TypeError, KeyError):
        return None, "invalid", None


class ParkingApplication:
    def __init__(self, database, seoul_key, client_id, client_secret):
        self.database, self.seoul_key = database, seoul_key
        self.client_id, self.client_secret = client_id, client_secret
        self._lock = threading.Lock()
        self._rows, self._loaded_at = {}, 0.0

    def live_rows(self):
        with self._lock:
            if time.monotonic() - self._loaded_at < 300 and self._rows:
                return self._rows
            with requests.Session() as session:
                rows = fetch_parking_lots(session, self.seoul_key)
            self._rows = {str(row["PKLT_CD"]): row for row in rows}
            self._loaded_at = time.monotonic()
            return self._rows

    def nearby(self, destination):
        target = point(destination)
        if not self.database.exists():
            raise CollectionError("정적 주차장 DB가 없습니다. 월별 수집기를 먼저 실행해주세요.")
        with closing(sqlite3.connect(self.database.as_uri() + "?mode=ro", uri=True)) as connection:
            stored = connection.execute("SELECT id, static_json, latitude, longitude FROM parking_lots WHERE geocode_status='ok'").fetchall()
        now = datetime.now(KST)
        notice = None
        try:
            live = self.live_rows()
        except CollectionError:
            # Do not present cached counts as a successful new observation.
            live = {}
            notice = "서울시 주차 현황을 조회하지 못했습니다. 주차 가능 대수는 확인 불가로 표시합니다."
        lots = []
        for pid, text, lat, lon in stored:
            fields = json.loads(text)
            if is_bus_only(fields):
                continue
            try:
                total = int(fields["TPKCT"])
            except (ValueError, TypeError, KeyError):
                total = None
            row = live.get(pid)
            # Prefer current capacity for valid availability calculations when available.
            if row is not None:
                try:
                    total = int(row["TPKCT"])
                except (ValueError, TypeError, KeyError):
                    total = None
            available, status, timestamp = availability(row, total, now)
            position = {"latitude": lat, "longitude": lon}
            lots.append({"id": pid, "name": fields.get("PKLT_NM") or "이름 없음",
                         "address": fields.get("ADDR") or "주소 없음", **position,
                         "distance_m": distance_m(target, position), "total_spaces": total,
                         "available_spaces": available, "status": status,
                         "source_updated_at": timestamp})
        lots.sort(key=lambda lot: (lot["distance_m"], lot["id"]))
        return {"destination": {**target, "name": str(destination.get("name") or "목적지")},
                "parkings": lots[:10], "fetched_at": now.isoformat(), "route": None, "notice": notice}

    def search(self, query, origin):
        if not isinstance(query, str) or not 1 <= len(query.strip()) <= 200:
            raise ValueError("목적지 주소를 1~200자로 입력해주세요.")
        with requests.Session() as session:
            geo = geocode_address(session, query.strip(), self.client_id, self.client_secret)
        if geo["geocode_status"] != "ok":
            raise ValueError("주소를 하나로 찾지 못했습니다. 서울시 도로명·지번 주소를 구체적으로 입력해주세요.")
        result = self.nearby({**geo, "name": query.strip()})
        if origin is None:
            result["notice"] = (result["notice"] or "") + " 현재 위치 버튼을 누르면 목적지까지의 이동 경로를 안내합니다."
            return result
        start, goal = point(origin), point(geo)
        try:
            with requests.Session() as session:
                payload = request_json(session, "https://maps.apigw.ntruss.com/map-direction/v1/driving",
                    params={"start": f"{start['longitude']},{start['latitude']}",
                            "goal": f"{goal['longitude']},{goal['latitude']}", "option": "traoptimal"},
                    headers={"x-ncp-apigw-api-key-id": self.client_id,
                             "x-ncp-apigw-api-key": self.client_secret})
            if payload.get("code") != 0:
                raise CollectionError("경로 없음")
            route = payload["route"]["traoptimal"][0]
            result["route"] = {"path": route["path"], "distance_m": route["summary"]["distance"],
                               "duration_ms": route["summary"]["duration"]}
        except (CollectionError, KeyError, TypeError, IndexError):
            result["notice"] = (result["notice"] or "") + " 자동차 경로를 조회하지 못했습니다. 주차장 목록은 이용할 수 있습니다."
        return result


def handler_for(application):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass  # Do not log user addresses, keys or request bodies.

        def send_json(self, status, body):
            data = json.dumps(body, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            if self.path not in ("/api/search", "/api/nearby"):
                return self.send_json(404, {"error": "요청 경로가 없습니다."})
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 8192:
                    raise ValueError("요청 크기 오류")
                body = json.loads(self.rfile.read(length))
                if not isinstance(body, dict):
                    raise ValueError("JSON 객체가 필요합니다.")
                result = application.search(body.get("query"), body.get("origin")) if self.path == "/api/search" else application.nearby(body.get("destination"))
                self.send_json(200, result)
            except (ValueError, TypeError, KeyError):
                self.send_json(400, {"error": "주소 또는 좌표를 확인해주세요. 서울시 도로명·지번 주소를 입력하세요."})
            except (CollectionError, sqlite3.Error, OSError):
                self.send_json(503, {"error": "데이터를 조회하지 못했습니다. 서버 설정과 API 이용 상태를 확인해주세요."})
    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    load_local_env()
    app = ParkingApplication(data_dir() / "seoul_parking_static.sqlite3", required_env("SEOUL_API_KEY"),
                             required_env("NAVER_MAPS_CLIENT_ID"), required_env("NAVER_MAPS_CLIENT_SECRET"))
    server = ThreadingHTTPServer((args.host, args.port), handler_for(app))
    server.daemon_threads = True
    print(f"PubPark local API: {args.host}:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
