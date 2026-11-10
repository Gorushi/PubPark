# 모바일 주차장 탐색 화면

## 바로 실행: 샘플 모드 (기본값)

```powershell
cd frontend/flutter_app
flutter pub get
flutter run --dart-define=NAVER_MAPS_CLIENT_ID=본인의_Client_ID
```

USE_MOCK_DATA의 기본값은 true입니다. 서울시청·세종문화회관·강남역을 검색할 수 있습니다. 명시하지 않은 임의 주소를 성공한 것처럼 처리하지 않습니다. 주차장 이름·주소·현황·경로·출발지는 모두 샘플이며 화면에 DEMO와 샘플 안내를 표시합니다. 네이버 Client ID가 없거나 데스크톱이면 좌표 기반의 UI 미리보기를 대신 그립니다. 실제 지도 타일은 Android/iOS와 유효한 Client ID가 필요합니다.

## 실제 서울시 데이터 모드

Client ID 입력 실수를 방지하려면 앱 폴더에서 아래 스크립트를 사용하세요. backend/.env의 NAVER_MAPS_CLIENT_ID만 읽으며 Client Secret은 Flutter에 전달하지 않습니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/run_app.ps1 -Mode Live
# 샘플 모드: -Mode Demo
```

수동으로 실행하는 flutter run은 backend/.env를 자동으로 읽지 않습니다. 예제의 '본인의_Client_ID'를 그대로 입력하면 인증이 실패합니다.

1. backend/.env에 SEOUL_API_KEY, NAVER_MAPS_CLIENT_ID, NAVER_MAPS_CLIENT_SECRET을 설정하고 네이버 콘솔에서 Geocoding·Directions5를 활성화합니다.
2. 월별 정적 수집기로 DB를 준비합니다. 기존 수집 결과가 있으면 재수집하지 않아도 됩니다.
3. 저장소 루트에서 개발용 HTTP 서버를 실행합니다.

```powershell
backend/.venv/Scripts/python.exe -m pubpark.api
```

다른 터미널의 앱 폴더에서 Android 에뮬레이터용으로 실행합니다.

```powershell
flutter run --dart-define=NAVER_MAPS_CLIENT_ID=본인의_Client_ID --dart-define=USE_MOCK_DATA=false --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

서울특별시 중구 세종대로 110 같은 도로명·지번 주소를 입력합니다. Geocoding은 장소명 검색·자동완성 API가 아닙니다. 현재 위치 버튼을 눌러 위치 서비스를 켜고 권한을 허용하면 현재 위치에서 목적지까지 자동차 경로를 계산합니다. 위치를 확인하지 못해도 주변 주차장 검색은 가능합니다. 출발지가 바뀌면 검색을 다시 실행해 경로를 계산합니다.

서버 기본 바인딩은 127.0.0.1:8000입니다. 실기기 개발 시 같은 네트워크에서 서버의 --host 옵션과 API_BASE_URL을 맞춰야 합니다. 이 서버는 인증 없는 로컬 개발용이며 외부 서비스 배포용 구성이 아닙니다. Android의 평문 HTTP 허용은 debug manifest에만 적용되므로 릴리스에서는 HTTPS 서버가 필요합니다. iOS의 위치 권한 문구는 추가했으며 실제 iOS 빌드는 macOS에서 검증해야 합니다.

## 화면과 동작

- 상단: 메뉴, 목적지 검색, 데모 목적지 바로가기, 자동차 이동 시간·거리.
- 지도: 출발지·목적지·주차장 마커와 파란 경로선. 지도 위 거리는 도로 주행 거리입니다.
- 바텀시트: 화면 17%·39%·83%로 드래그/스냅. 최대 10곳을 목적지와의 Haversine 직선거리로 정렬합니다. 검색 반경 제한 없이 좌표가 확인된 시영주차장 중 가까운 순서입니다.
- 카드: 이름·주소·잔여/총면수·직선거리·원본 갱신 시각. 선택하면 시트가 접히고 해당 핀과 카메라를 강조합니다.
- 관광버스 전용 주차장은 목록과 지도 핀에서 제외합니다. 운영구분명이 버스전용이거나 이름에 관광버스전용(공백 무시)이 포함된 곳을 거리 정렬·10곳 제한 전에 제외합니다. 일반 주차장에 버스 요금 필드가 있다는 이유만으로 제외하지는 않습니다. 원본 정적 DB는 보존합니다.
- 여유: 잔여 비율 20% 이상, 혼잡: 20% 미만, 만차: 0대. 이 기준은 화면용 분류이며 예측 확률이 아닙니다.
- 앱 사용 중 5분마다 현황을 다시 조회합니다. 수동 새로고침과 앱 복귀 후 갱신도 지원합니다. 서버는 서울시 응답을 최대 5분 캐시해 여러 요청이 중복 호출하지 않도록 합니다. 앱·서버가 종료된 동안 실시간 이력을 수집하는 배치는 아닙니다.
- 미연계·20분 초과 지연·미래 시각 이상·총면수 초과·결측은 확인 불가로 표시합니다. API 장애 시 정상 0대로 표시하지 않습니다. 갱신 통신 실패 시 기존 결과와 이전 조회 시각을 유지하고 실패 안내를 표시합니다.
- 주차장 현황 갱신은 Directions5 경로를 재요청하지 않습니다. 경로·시간은 마지막 검색 시점의 결과입니다.

## 컴포넌트

| 파일 | 역할 |
| --- | --- |
| lib/screens/naver_map_screen.dart | 검색·위치·주기 갱신·지도 연동 |
| lib/widgets/parking_sheet.dart | 드래그 시트와 목록 |
| lib/widgets/parking_card.dart | 현황·거리·선택 상태 카드 |
| lib/widgets/demo_map_preview.dart | 키 없이 실행할 때의 오프라인 시각 미리보기 |
| lib/models/parking_search.dart | 좌표·검색·경로·주차 현황 모델 |
| lib/services/parking_repository.dart | 샘플/실제 HTTP 데이터 공급 |
| backend/src/pubpark/api.py | Geocoding·Directions5·SQLite·실시간 현황 결합 |

POST /api/search: {query, origin?: {latitude, longitude}}.
POST /api/nearby: {destination: {latitude, longitude, name}}.
두 엔드포인트는 destination, parkings, fetched_at, route, notice를 반환합니다. route.path는 네이버 원본 순서인 [경도, 위도] 배열, duration_ms는 밀리초입니다. API 키·Client Secret은 응답에 포함하지 않습니다.

## 검증

```powershell
# 앱 폴더
flutter analyze
flutter test
flutter build apk --debug
# 키 없이 정적 UI 이미지 생성 (Windows 기본 한국어 폰트 사용)
flutter test tool/preview_ui_test.dart
# 저장소 루트
backend/.venv/Scripts/python.exe -m unittest discover -s backend/tests -v
```

UI 미리보기는 앱 폴더의 build/previews/pubpark-home.png에 생성됩니다. 미리보기의 지도·경로·주차 현황은 모두 샘플입니다.
