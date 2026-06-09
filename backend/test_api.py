import requests
import time
import api_key_priv as apikey

url = f"https://apis.data.go.kr/B553881/Parking/PrkRealtimeInfo?serviceKey={apikey.api_key}&pageNo=1&numOfRows=10&format=2"

headers = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json'
}

max_retries = 3

for attempt in range(max_retries):
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()

        print(f"Status Code: {response.status_code}")
        print("데이터 호출 성공!")
        print(response.text)
        break

    except requests.exceptions.HTTPError as err:
        if response.status_code == 502:
            print(f"[{attempt+1}/{max_retries}] 502 에러 발생. 5초 후 재시도합니다.")
            time.sleep(5)
        else:
            print(f"HTTP 에러 발생: {err}")
            break
    except Exception as e:
        print(f"알 수 없는 에러 발생: {e}")
        break
