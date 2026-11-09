# 협업 안내

## 작업 경계

| 역할 | 주 작업 위치 | 합의할 내용 |
| --- | --- | --- |
| 수집·저장 | backend/src/pubpark/collectors, storage | 제공처 스키마, 갱신 시각, 원본 보존 |
| 분석·예측 | backend/src/pubpark/analysis | 학습 대상, 시간순 검증, 기준 예측 비교 |
| 앱 | frontend/flutter_app/lib | 화면 상태, 데이터 계약, 설정 |

데이터 필드를 바꾸면 docs/data-contract.md를 같은 PR에서 수정하고 소비하는 팀원의 검토를 받습니다. 실제 인원별 담당자는 팀에서 배정하세요.

## 작업 순서

1. 이슈에 목적, 변경 범위, 완료 조건을 적습니다.
2. 작업별 브랜치를 만듭니다. 예: feature/seoul-collector, fix/cache-write, docs/setup.
3. 한 PR은 한 목적에 집중하고 무관한 파일을 바꾸지 않습니다.
4. 관련 테스트를 실행하고 PR에 변경 이유, 검증 결과, 남은 한계를 기록합니다.
5. 다른 팀원 검토 후 병합합니다. 실제 데이터와 가상 데이터를 구분하세요.

## 코드와 설정

- Python 모듈 import 시 네트워크·파일 쓰기·무한 루프를 실행하지 않습니다.
- 실행 스크립트와 자동 테스트를 구분합니다. 테스트는 모의 응답과 임시 경로를 사용합니다.
- 키는 환경변수, Flutter 설정은 --dart-define으로 전달합니다. 예제에는 실제 키를 넣지 않습니다.
- 개인 개발 환경 경로를 하드코딩하지 않습니다.
- Flutter 변경은 dart format lib test, flutter analyze, flutter test로 확인합니다.
