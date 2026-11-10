import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/parking_search.dart';
import 'package:flutter_app/screens/naver_map_screen.dart';
import 'package:flutter_app/services/parking_repository.dart';
import 'package:flutter_app/widgets/demo_map_preview.dart';
import 'package:flutter_app/widgets/parking_card.dart';
import 'package:flutter_app/widgets/parking_sheet.dart';

class CountingRepository extends MockParkingRepository {
  int refreshes = 0;
  @override
  Future<SearchResult> refresh(SearchResult current) {
    refreshes++;
    return super.refresh(current);
  }
}

void main() {
  test(
    'Demo caps results at ten and sorts by straight-line distance',
    () async {
      final result = await MockParkingRepository().search('서울시청', null);
      expect(result.parkings.length, 10);
      for (var i = 1; i < result.parkings.length; i++) {
        expect(
          result.parkings[i].distance,
          greaterThanOrEqualTo(result.parkings[i - 1].distance),
        );
      }
      expect(result.route!.points.length, greaterThan(1));
      expect(result.parkings.any((p) => p.available == null), isTrue);
    },
  );

  testWidgets('Search, card selection and five-minute refresh work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = CountingRepository();
    await tester.pumpWidget(
      MaterialApp(home: NaverMapScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('DEMO'), findsOneWidget);
    await tester.drag(find.text('목적지 주변 주차장'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ParkingSheet>(find.byType(ParkingSheet)).controller!.size,
      greaterThan(.6),
    );
    final first = tester.widget<ParkingCard>(find.byType(ParkingCard).first);
    await tester.tap(find.byType(ParkingCard).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ParkingSheet>(find.byType(ParkingSheet)).controller!.size,
      closeTo(.39, .02),
    );
    expect(
      tester.widget<DemoMapPreview>(find.byType(DemoMapPreview)).selectedId,
      first.parking.id,
    );
    await tester.enterText(find.byType(TextField), '강남역');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DemoMapPreview>(find.byType(DemoMapPreview))
          .result!
          .destinationName,
      '강남역',
    );
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(repository.refreshes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Small screen remains usable and unknown demo query is explicit',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: NaverMapScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '모르는 목적지');
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();
      expect(find.textContaining('데모에서는 서울시청'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
