import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/naver_map_screen.dart';

void main() {
  testWidgets('Export offline UI preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    if (Platform.isWindows) {
      final font = File('${Platform.environment['WINDIR']}/Fonts/malgun.ttf');
      await tester.runAsync(() async {
        final loader = FontLoader('PreviewKorean')
          ..addFont(font.readAsBytes().then((b) => ByteData.sublistView(b)));
        await loader.load();
        final latin = FontLoader('Roboto')
          ..addFont(font.readAsBytes().then((b) => ByteData.sublistView(b)));
        await latin.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'PreviewKorean',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F6B)),
        ),
        home: RepaintBoundary(key: key, child: const NaverMapScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/previews/pubpark-home.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
