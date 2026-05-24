import 'package:flutter_test/flutter_test.dart';

import 'package:scooter_bridge_arch/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ScooterBridgeApp());
    expect(find.text('Scooter Bridge Console'), findsOneWidget);
  });
}
