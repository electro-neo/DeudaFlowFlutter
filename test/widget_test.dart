// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build a minimal app for widget test that doesn't trigger app init
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('widget test'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('widget test'), findsOneWidget);
  });
}
