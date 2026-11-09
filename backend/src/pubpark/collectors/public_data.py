"""Legacy national public-data collector, not Seoul GetParkingInfo."""
import logging
import math
import time

import requests

from pubpark.config import data_dir, public_data_api_key
from pubpark.storage.cache import load_cache, save_cache

URL = "https://apis.data.go.kr/B553881/Parking/PrkRealtimeInfo"
logger = logging.getLogger(__name__)


def fetch_page(session, key, page, rows, attempts=3):
    for attempt in range(attempts):
        try:
            response = session.get(URL, params={"serviceKey": key, "pageNo": page,
                                   "numOfRows": rows, "format": 2}, timeout=15)
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, dict):
                raise ValueError("API 응답이 JSON 객체가 아닙니다.")
            return payload
        except (requests.RequestException, ValueError):
            # Never log exceptions containing request URLs and API keys.
            logger.warning("페이지 %s 수집 실패 (%s/%s)", page, attempt + 1, attempts)
            if attempt + 1 == attempts:
                raise RuntimeError("공공데이터 요청 실패: 응답과 키 설정을 확인하세요.") from None
            time.sleep(1)


def collect_snapshot(session, key):
    count = int(fetch_page(session, key, 1, 1)["totalCount"])
    snapshot = {}
    for page in range(1, math.ceil(count / 5000) + 1):
        items = fetch_page(session, key, page, 5000)["PrkRealtimeInfo"]
        if not isinstance(items, list):
            raise ValueError("PrkRealtimeInfo가 목록이 아닙니다.")
        for item in items:
            pid = item.get("prk_center_id")
            if pid:
                snapshot[str(pid)] = item
    return snapshot


def check_api():
    key = public_data_api_key()
    with requests.Session() as session:
        print(fetch_page(session, key, 1, 10))


def main():
    logging.basicConfig(level=logging.INFO)
    key = public_data_api_key()
    path = data_dir() / "parking_cache.json"
    try:
        logger.info("기존 캐시 %s개", len(load_cache(path)))
    except (OSError, ValueError):
        logger.warning("기존 캐시를 읽지 못했습니다. 수집을 계속합니다.")
    with requests.Session() as session:
        try:
            while True:
                try:
                    snapshot = collect_snapshot(session, key)
                    if snapshot:
                        save_cache(path, snapshot)
                        logger.info("캐시 %s개 갱신", len(snapshot))
                except (RuntimeError, ValueError, KeyError, TypeError, OSError):
                    logger.warning("이번 갱신 실패. 기존 캐시를 보존합니다.")
                time.sleep(30)
        except KeyboardInterrupt:
            logger.info("수집 종료")


if __name__ == "__main__":
    main()
