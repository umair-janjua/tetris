import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubicles/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CubiclesApp());
    expect(find.text('CUBICLES'), findsOneWidget);
  });

  testWidgets('Tablet layout and tap hit test smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CubiclesApp());
    expect(find.text('CUBICLES'), findsOneWidget);

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('HOLD'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    // Hit test on the screen
    await tester.tap(find.text('HOLD'));
    await tester.pump(const Duration(milliseconds: 50));
  });
}
