import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// Native SDK setup is separate from the screen and from REST API credentials.
class NaverMapInitializer {
  const NaverMapInitializer();

  Future<void> initialize(String clientId, VoidCallback onAuthFailed) {
    return FlutterNaverMap().init(
      clientId: clientId,
      onAuthFailed: (error) {
        debugPrint('PubPark Naver authentication failed: ${error.runtimeType}');
        onAuthFailed();
      },
    );
  }
}
