class AppConfig {
  static const useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: true,
  );
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const naverMapsClientId = String.fromEnvironment(
    'NAVER_MAPS_CLIENT_ID',
  );
}
