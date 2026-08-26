import 'package:flutter_test/flutter_test.dart';
import 'package:cubicles/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CubiclesApp());
    expect(find.text('CUBICLES'), findsOneWidget);
  });
}
