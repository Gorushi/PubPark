# 구성과 구현 상태

## 현재 흐름

서울시 GetParkingInfo → collectors/seoul_static.py → 네이버 Geocoding (주소 신규·변경·미해결) → SQLite 정적 정보. Windows 월별 작업으로 실행합니다. [실행·저장 계약](seoul-static.md)을 참고하세요.

전국 PrkRealtimeInfo API → collectors/public_data.py → storage/cache.py → 최신 JSON 캐시.

Flutter main.dart → app.dart → 스플래시 → NaverMapScreen → flutter_naver_map → 네이버 Android/iOS 지도 SDK. services/naver_map_initializer.dart에서 SDK를 초기화하며 Client ID는 NAVER_MAPS_CLIENT_ID dart-define으로 전달합니다. Client Secret은 앱에 넣지 않습니다. 새 검색 화면은 parking_repository.dart로 샘플 또는 실제 HTTP API를 사용합니다. 기존 parking_api_service.dart는 이전 목록 계약용이며 새 화면에서는 사용하지 않습니다.

실제 모드: 앱 → pubpark.api → 정적 SQLite + 서울시 실시간 현황(5분 캐시) + 네이버 Geocoding/Directions5. 화면·API 계약은 [모바일 화면 안내](mobile-parking-ui.md)를 참고하세요.

## 이동 내역

| 이전 | 현재 |
| --- | --- |
| 루트 lib/models, lib/services | frontend/flutter_app/lib/models, services |
| backend/test_api.py | backend/scripts/check_public_api.py 및 pubpark-check-api |
| backend/test_api_scraper.py | backend/src/pubpark/collectors/public_data.py, storage/cache.py |
| backend/test_tsa.py | backend/src/pubpark/analysis/legacy_demand.py |
| Flutter main.dart의 화면 | app.dart 및 screens/ |

## 분석 실험의 한계

legacy_demand.py는 기존 코드 보존용입니다. 최신 캐시에는 필요한 timestamp 이력이 없으며 주차장이 섞인 행에 lag를 적용할 수 없습니다. 전체 데이터로 스케일러를 학습하는 코드도 있어 평가에 미래 정보가 들어갑니다. 현재 성능 지표를 실제 예측 성능으로 사용하지 마세요. 입력 경로와 import 시 실행은 정리했지만 모델 재설계는 포함하지 않았습니다.

## 다음 단계

실시간 이력 수집과 상태 요약의 상세 구현 조건은 [개발 요구사항](realtime-history-requirements.md)을 따른다. 해당 문서는 구현 전 요구사항이다.

1. 서울시 실시간 현황 수집기 (정적 수집기는 구현 완료).
2. 원본 관측과 품질 상태를 보존하는 이력 저장소.
3. 주차장별 이력 생성, 시간순 검증, 현재값 유지·요일 시간대 기준 예측과 비교.
4. 개발용 HTTP API의 운영 환경 구성과 예측 결과 연동.

빈 API·예측 서비스 구현은 만들지 않았습니다. 계약을 합의한 뒤 실제 기능과 함께 추가하세요.
