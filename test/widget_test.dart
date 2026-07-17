import 'package:flutter_test/flutter_test.dart';
import 'package:tetris/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TetrisApp());
    expect(find.text('TETRIS'), findsOneWidget);
  });
}
