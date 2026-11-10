# 데이터 계약

## 현재 앱 모델 (초안)

이 절은 기존 parking_lot.dart·parking_api_service.dart의 미연결 계약입니다. 새 모바일 검색 화면은 [검색 API 계약](mobile-parking-ui.md)을 사용하며 결측 현황을 null로 구분합니다.

| 필드 | 타입 | 의미 |
| --- | --- | --- |
| id | string | 제공처 내부 주차장 식별자 |
| name | string | 주차장 이름 |
| available_spaces | integer | 잔여 주차면수 |

기존 클라이언트는 GET /api/parking-lots의 객체 배열, GET /api/parking-lots/{id}의 단일 객체를 기대합니다. 서버는 미구현입니다. 모델은 누락 잔여면수를 0으로 처리하는 기존 동작이므로 데이터 품질 상태를 표현할 수 없습니다. 실제 연동 전에 nullable 값과 상태 필드를 함께 구현해야 합니다.

## 서울시 정적 정보 (구현)

SQLite 구조·필드·월별 갱신 정책은 [정적 정보 계약](seoul-static.md)을 참고하세요. 기존 앱 모델로 자동 변환하거나 화면에 제공하는 API는 아직 없습니다.

## 서울시 실시간 수집·이력 계약 제안 (미구현)

| 필드 | 원본/정의 |
| --- | --- |
| source | seoul, 제공처 구분 |
| parking_lot_id | PKLT_CD, 문자열 유지 |
| name | PKLT_NM |
| total_spaces | TPKCT |
| occupied_spaces | NOW_PRK_VHCL_CNT, 잔여면수가 아닌 주차 차량수 |
| source_updated_at | NOW_PRK_VHCL_UPDT_TM |
| collected_at | 수집기가 응답을 받은 시각 |
| linked | PRK_STTS_YN |
| quality_flags | 복수의 누락·초과·지연 상태 |
| available_spaces | 유효한 관측에 한해 total_spaces - occupied_spaces, 그 외 null |

시각은 Asia/Seoul 기준을 명시한 ISO 8601로 정규화하고 원본 시각도 보존합니다. 제공처와 ID를 함께 식별자로 사용합니다. 같은 원본 갱신 시각의 반복 수집과 실제 새 관측을 구분합니다. 현재 전국 수집기의 원본 JSON과 다르며 자동 변환은 아직 없습니다.
