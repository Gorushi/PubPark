# PubPark

서울시 일부 시영주차장 현황을 축적하고 특정 시각의 잔여 주차면수를 예측하는 앱을 목표로 합니다.

현재는 스플래시·카카오 지도 화면, 기존 전국 공공데이터 API 수집 실험, 분석 실험이 있습니다. 서울시 수집기, 이력 DB, HTTP 서버, 검증된 예측 모델과 앱 데이터 연동은 아직 구현되지 않았습니다.

## 구조

- frontend/flutter_app/: Flutter 앱. lib/screens/ 화면, lib/services/ 통신, lib/models/ 모델.
- backend/src/pubpark/: collectors/ 수집, storage/ 최신 캐시 저장, analysis/ 실험.
- backend/scripts/: 수동 연결 확인. backend/tests/: 자동 테스트.
- docs/: [구성](docs/architecture.md), [데이터 계약](docs/data-contract.md), [품질 기준](docs/data-quality.md).
- [협업 규칙](CONTRIBUTING.md)

## 백엔드 실행 (PowerShell, Python 3.11 이상)

저장소 루트에서 실행합니다.

```powershell
python -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -e ./backend
$env:PUBLIC_DATA_API_KEY = '본인의 전국 공공데이터 API 키'
backend/.venv/Scripts/pubpark-check-api.exe
backend/.venv/Scripts/pubpark-collect.exe
```

위 수집기는 기존 PrkRealtimeInfo용이며 서울시 GetParkingInfo용이 아닙니다. 키는 서로 대체할 수 없습니다. backend/.env.example은 설정 목록이며 자동으로 읽지 않습니다. 기본 저장 경로는 backend/data/parking_cache.json이고 PUBPARK_DATA_DIR 환경변수로 바꿀 수 있습니다. 캐시는 최신 스냅샷이며 이력이 아닙니다. 예전 캐시가 있다면 새 경로로 직접 복사하세요.

분석 의존성은 아래와 같이 설치합니다.

```powershell
backend/.venv/Scripts/python.exe -m pip install -e './backend[analysis]'
backend/.venv/Scripts/pubpark-legacy-analysis.exe
```

이 분석은 기존 실험 보존용이며 현재 캐시로 유효한 시계열 예측을 수행하지 못합니다. 상세 한계는 구성 문서를 참고하세요.

## 앱 실행

Flutter SDK가 필요합니다. Dart SDK 요구 버전은 pubspec.yaml을 참고하세요.

```powershell
cd frontend/flutter_app
flutter pub get
flutter run --dart-define=KAKAO_JAVASCRIPT_KEY=본인의_JS키
```

키가 없으면 설정 안내를 표시합니다. 기존 WebView 지도 방식과 청주 중심 좌표는 유지했습니다. 카카오 콘솔의 플랫폼·허용 도메인 설정과 실제 기기 지도 로딩은 별도 확인이 필요합니다. 클라이언트 지도 키는 앱에 포함되므로 플랫폼 제한을 설정하세요.

향후 자체 HTTP 서버가 준비되면 --dart-define=API_BASE_URL=https://서버주소 를 추가합니다. API 서비스는 아직 화면에서 호출하지 않습니다. 사용하지 않는 Android 네이티브 SDK 키 설정은 제거했습니다.

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
