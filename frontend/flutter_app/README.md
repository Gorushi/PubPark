# PubPark Flutter 앱

네이버 Mobile Dynamic Map SDK 기반 Android/iOS 주차장 검색 화면입니다. 검색·경로·주차 현황·드래그 바텀시트를 제공합니다.

설치·Client ID 설정·실행·테스트는 [루트 README](../../README.md#앱-실행)를 참고하세요.

- lib/screens/naver_map_screen.dart: 네이버 지도와 설정·인증 오류 안내
- lib/services/naver_map_initializer.dart: 네이티브 SDK 초기화
- lib/config/app_config.dart: dart-define 설정
- test/: 스플래시 이동과 지도 오류 처리 테스트

기본 샘플 모드와 실제 Geocoding·Directions5·서울시 데이터 연동의 실행 방법은 [화면 안내](../../docs/mobile-parking-ui.md)를 참고하세요.
