# 서울시 정적 주차장 정보

## 실행과 설정

backend/.env의 SEOUL_API_KEY, NAVER_MAPS_CLIENT_ID, NAVER_MAPS_CLIENT_SECRET을 사용합니다. 새 정적 정보 CLI만 .env를 자동 로드하며 셸 환경변수가 우선합니다. Geocoding을 네이버 콘솔에서 활성화해야 합니다.

저장소 루트에서 실행합니다.

```powershell
python -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -e ./backend
backend/.venv/Scripts/python.exe -m pubpark.collectors.seoul_static
# 수동 재시도가 필요한 경우에만 같은 달에 강제 갱신
backend/.venv/Scripts/python.exe -m pubpark.collectors.seoul_static --force
```

## 저장

기본 DB는 backend/data/seoul_parking_static.sqlite3입니다. PUBPARK_DATA_DIR로 위치를 바꿀 수 있습니다. 로컬 DB와 .env는 Git에서 제외됩니다.

parking_lots 테이블:

| 열 | 의미 |
| --- | --- |
| id | PKLT_CD 문자열 |
| static_json | 서울시 정적 필드 원본 이름·값을 보존한 JSON |
| latitude, longitude | 위도·경도 실수, 미확정은 NULL |
| geocode_status | ok, missing_address, no_match, ambiguous, invalid_coordinates |
| geocode_json | 질의 주소, 변환 시각, 결과 주소 및 좌표 상태 |
| refreshed_at | 해당 주차장 정적 정보 갱신 시각 (UTC+09:00) |

refresh_state는 마지막으로 성공한 한국시간 기준 YYYY-MM과 갱신 시각을 저장합니다. 같은 달의 재실행은 API 호출 없이 건너뜁니다. 전체 수집과 좌표 변환이 끝난 뒤 하나의 DB 트랜잭션으로 목록과 성공 시각을 교체합니다. 실패 시 기존 목록을 보존하며 다음 실행 때 재시도합니다. 월별 이력을 쌓는 DB가 아닌 최신 정적 목록입니다. DB 쓰기 잠금으로 동시 갱신을 막습니다.

저장 필드는 collectors/seoul_static.py의 STATIC_FIELDS 허용 목록입니다. 이름·주소·종류·운영구분·전화번호·총 주차면수·운영시간·일반 차량 요금·정기권·공유주차장 정보 등을 포함합니다. BUS_ 필드 4개와 향후 추가되는 미승인 필드는 저장하지 않습니다. NOW_PRK_VHCL_CNT, NOW_PRK_VHCL_UPDT_TM, PRK_STTS_YN, PRK_STTS_NM도 저장하지 않습니다. HHMM의 선행 0과 빈 값은 원본대로 유지합니다.

주소에는 필요한 경우 서울특별시를 붙여 Geocoding합니다. 주소가 그대로이고 기존 변환이 성공했다면 좌표를 재사용하고, 새 주소·변경 주소·미해결 주소만 다시 요청합니다. 여러 결과가 나오면 첫 결과를 임의 채택하지 않습니다. 좌표는 건물·주소 기준이며 주차장 차량 진입구임을 보장하지 않습니다. 좌표 범위 검사는 넓은 서울권 범위로, 서울 행정경계 판정은 아닙니다.

## 월별 Windows 작업

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/register_seoul_static_task.ps1
Get-ScheduledTaskInfo -TaskName PubPark-SeoulStaticMonthly
```

매월 1일 03:00 한국시간, 등록한 사용자의 로그인 상태에서 실행합니다. PC가 꺼져 있으면 정시에 실행할 수 없으며 이후 실행 가능한 시점에 누락 실행을 시도합니다. 실패하면 1시간 간격으로 최대 3회 재시도합니다. 서버의 24시간 무인 실행이 필요하면 이 CLI를 서버 스케줄러에 등록해야 합니다. 등록 스크립트는 같은 이름의 기존 작업을 덮어쓰지 않습니다.

스케줄러는 run_seoul_static.ps1을 호출하고 backend/data/logs/seoul-static-YYYY-MM.log에 결과를 추가합니다. 실제 키는 작업 정의·명령 인자에 포함하지 않습니다. 프로젝트 폴더를 이동하면 작업을 다시 등록해야 합니다.

## 출처

- 서울시: https://data.seoul.go.kr/dataList/OA-21709/A/1/datasetView.do
- 서울시 문서에 명시된 HTTP :8088 엔드포인트 사용. HTTPS :8088은 현재 연결 검사에서 TLS 오류로 확인됐습니다.
- 네이버 Geocoding: https://api.ncloud-docs.com/docs/application-maps-geocoding
- 네이버 인증: https://api.ncloud-docs.com/docs/application-maps-overview
