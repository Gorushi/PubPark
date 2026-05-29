import requests
import math
import time
import threading
import api_key_priv as apikey

cached_parking_data = {}

def update_parking_cache_loop():
    base_url = 'https://apis.data.go.kr/B553881/Parking/PrkRealtimeInfo'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json'
    }

    while True:
        print("\n[배치 시스템] 데이터 동기화 시작")
        
        init_url = f"{base_url}?serviceKey={apikey.api_key}&pageNo=1&numOfRows=1&format=2"
        try:
            res_init = requests.get(init_url, headers=headers, timeout=10)
            res_init.raise_for_status()
            total_count = int(res_init.json()['totalCount'])
        except Exception as e:
            print(f"초기화 실패, 3초 후 재시도: {e}")
            time.sleep(3)
            continue

        rows_per_page = 5000
        total_pages = math.ceil(total_count / rows_per_page)
        
        temp_cache = {}
        page = 1

        while page <= total_pages:
            page_url = f"{base_url}?serviceKey={apikey.api_key}&pageNo={page}&numOfRows={rows_per_page}&format=2"
            
            try:
                res = requests.get(page_url, headers=headers, timeout=15)
                res.raise_for_status()
                items = res.json().get('PrkRealtimeInfo', [])
                
                for item in items:
                    pid = item.get('prk_center_id')
                    if pid:
                        temp_cache[pid] = item
                
                print(f"[{page}/{total_pages}] 페이지 수집 완료")
                page += 1
                time.sleep(0.1)

            except Exception as e:
                print(f"[{page}페이지] 에러 발생 ({e}). 1초 후 해당 페이지 재시도")
                time.sleep(1)
        
        if temp_cache:
            global cached_parking_data
            cached_parking_data = temp_cache
            print(f"동기화 완료. 총 {len(cached_parking_data)}개 캐시 로드 완료")
        
        print("30초 후 다음 전체 갱신 시작")
        time.sleep(30)

def search_parking_from_cache(target_id):
    if not cached_parking_data:
        return {"error": "현재 캐시 데이터 비어 있음. 잠시 후 다시 시도 요망."}
    return cached_parking_data.get(target_id, {"error": "해당 ID의 주차장 정보 검색 실패."})

bg_thread = threading.Thread(target=update_parking_cache_loop, daemon=True)
bg_thread.start()

while True:
    time.sleep(1)