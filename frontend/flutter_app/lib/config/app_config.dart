class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const kakaoJavascriptKey = String.fromEnvironment(
    'KAKAO_JAVASCRIPT_KEY',
  );
}
