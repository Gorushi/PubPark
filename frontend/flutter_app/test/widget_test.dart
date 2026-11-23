import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';

void main() {
  testWidgets('ParkingApp loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ParkingApp());
    expect(find.byType(ParkingApp), findsOneWidget);
  });
}
