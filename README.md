# PubPark

서울시 일부 시영주차장 현황을 축적하고 특정 시각의 잔여 주차면수를 예측하는 앱을 목표로 합니다.

현재는 검색·경로·주차장 바텀시트 화면, 서울시 정적 정보·좌표 월별 수집기, 실시간 현황·주소·경로를 연결하는 로컬 HTTP API가 있습니다. 검증된 예측 모델과 실시간 이력 축적은 아직 구현되지 않았습니다. [모바일 화면 실행 안내](docs/mobile-parking-ui.md)

## 구조

- frontend/flutter_app/: Flutter 앱. lib/screens/ 화면, lib/services/ 통신, lib/models/ 모델.
- backend/src/pubpark/: collectors/ 수집, storage/ 최신 캐시 저장, analysis/ 실험.
- backend/scripts/: 수동 연결 확인. backend/tests/: 자동 테스트.
- docs/: [구성](docs/architecture.md), [데이터 계약](docs/data-contract.md), [품질 기준](docs/data-quality.md).
- [협업 규칙](CONTRIBUTING.md)

## 백엔드 실행 (PowerShell, Python 3.11 이상)

서울시 정적 정보 월별 갱신은 [서울시 수집 안내](docs/seoul-static.md)를 참고하세요. backend/.env를 읽어 정적 정보를 SQLite에 저장하고 주소를 네이버 Geocoding으로 변환합니다. 버스 필드와 실시간 주차대수는 제외합니다.

저장소 루트에서 실행합니다.

```powershell
python -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -e ./backend
$env:PUBLIC_DATA_API_KEY = '본인의 전국 공공데이터 API 키'
backend/.venv/Scripts/pubpark-check-api.exe
backend/.venv/Scripts/pubpark-collect.exe
```

위 명령은 기존 PrkRealtimeInfo 실험용이며 서울시 GetParkingInfo용이 아닙니다. 키는 서로 대체할 수 없습니다. 이 기존 실험은 셸 환경변수만 사용하며 .env는 자동으로 읽지 않습니다. 기본 저장 경로는 backend/data/parking_cache.json이고 PUBPARK_DATA_DIR 환경변수로 바꿀 수 있습니다. 캐시는 최신 스냅샷이며 이력이 아닙니다.

분석 의존성은 아래와 같이 설치합니다.

```powershell
backend/.venv/Scripts/python.exe -m pip install -e './backend[analysis]'
backend/.venv/Scripts/pubpark-legacy-analysis.exe
```

이 분석은 기존 실험 보존용이며 현재 캐시로 유효한 시계열 예측을 수행하지 못합니다. 상세 한계는 구성 문서를 참고하세요.

## 앱 실행

기본값은 샘플 데이터 모드입니다. 실제 서울시 현황 연결·서버 실행은 [모바일 화면 안내](docs/mobile-parking-ui.md)를 참고하세요.

Flutter SDK가 필요합니다. Dart SDK 요구 버전은 pubspec.yaml을 참고하세요.

```powershell
cd frontend/flutter_app
flutter pub get
flutter run --dart-define=NAVER_MAPS_CLIENT_ID=본인의_Client_ID
```

네이버 Mobile Dynamic Map SDK를 flutter_naver_map 플러그인으로 사용합니다. Android와 iOS를 지원하며 초기 지도 위치는 서울시청입니다. Client ID가 없으면 설정 안내를, 지원하지 않는 플랫폼에서는 지원 범위를 표시합니다. SDK 초기화 오류와 인증 실패도 화면에 표시합니다.

네이버 클라우드 콘솔에서 Dynamic Map을 활성화하고 Android 패키지명 `com.PubPark.PubPark` (대소문자 포함) 또는 iOS Bundle ID를 등록하세요. 새 Maps 서비스에서 발급된 Client ID를 사용하며 구형 인증 방식 키와 호환되지 않습니다. Client ID는 위 명령으로 SDK에 전달되므로 AndroidManifest.xml에 중복 설정하지 않습니다. `backend/.env`는 Flutter에서 읽지 않습니다. Client Secret과 서울시 API 키는 앱에 전달하지 마세요.

Android 최소 SDK는 23 이상, iOS 배포 대상은 13.0 이상입니다. iOS는 macOS에서 `flutter pub get`과 `cd ios; pod install` 후 빌드하세요. Windows에서 플러그인 설치 시 symlink 오류가 발생하면 개발자 모드를 활성화하거나 심볼릭 링크 생성 권한이 있는 환경에서 실행하세요. 실제 기기 지도 인증·로딩은 유효한 Client ID로 별도 확인해야 합니다.

Android 빌드는 Gradle 9.1.0을 사용하며 Java 25.0.4에서 디버그 APK 빌드를 확인했습니다. AGP와 Kotlin에 대한 향후 지원 중단 경고는 별도 업그레이드 대상으로 관리합니다.

실제 API 모드는 USE_MOCK_DATA=false와 API_BASE_URL을 지정합니다. Geocoding·Directions5는 백엔드에서 호출하고, 앱은 현재 위치를 전송해 경로를 요청합니다.

## 검증

```powershell
# 저장소 루트
$env:PYTHONPATH = "$PWD/backend/src"
backend/.venv/Scripts/python.exe -m unittest discover -s backend/tests -v
# frontend/flutter_app 에서 (별도 dart-define 없이)
flutter analyze
flutter test
```

자동 테스트는 실제 API를 호출하지 않습니다. 로컬 키·수집 데이터·학습 결과를 커밋하지 마세요. 추적되던 키 모듈 바이트코드는 제거했지만 과거 Git 이력은 그대로이므로 키 소유자는 노출 여부와 교체 필요성을 확인해야 합니다.
