# 구성과 구현 상태

## 현재 흐름

전국 PrkRealtimeInfo API → collectors/public_data.py → storage/cache.py → 최신 JSON 캐시.

Flutter main.dart → app.dart → 스플래시 → WebView 카카오 지도. services/parking_api_service.dart는 자체 서버용 미연결 클라이언트입니다. HTTP 서버는 없습니다.

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

1. 서울시 GetParkingInfo 전용 수집기와 응답 검증.
2. 원본 관측과 품질 상태를 보존하는 이력 저장소.
3. 주차장별 이력 생성, 시간순 검증, 현재값 유지·요일 시간대 기준 예측과 비교.
4. 자체 HTTP API와 앱 상태 연동.

빈 API·예측 서비스 구현은 만들지 않았습니다. 계약을 합의한 뒤 실제 기능과 함께 추가하세요.
