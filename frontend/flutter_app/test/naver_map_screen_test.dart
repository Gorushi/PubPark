import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/naver_map_screen.dart';
import 'package:flutter_app/services/naver_map_initializer.dart';

class FailingInitializer extends NaverMapInitializer {
  @override
  Future<void> initialize(String clientId, VoidCallback onAuthFailed) async {
    throw StateError('native initialization failed');
  }
}

class UnauthorizedInitializer extends NaverMapInitializer {
  @override
  Future<void> initialize(String clientId, VoidCallback onAuthFailed) async {
    onAuthFailed();
  }
}

void main() {
  testWidgets('Unsupported platforms do not initialize the SDK', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NaverMapScreen(
          clientId: 'test-id',
          initializer: FailingInitializer(),
        ),
      ),
    );
    expect(find.text('네이버 지도는 Android와 iOS 앱에서 사용할 수 있습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('Initialization failure shows guidance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NaverMapScreen(
          clientId: 'test-id',
          initializer: FailingInitializer(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('네이버 지도를 초기화하지 못했습니다. 앱을 다시 실행해주세요.'), findsOneWidget);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets(
    'Authentication failure is not hidden by initialization completion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NaverMapScreen(
            clientId: 'test-id',
            initializer: UnauthorizedInitializer(),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('네이버 지도 인증에 실패했습니다.'), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
