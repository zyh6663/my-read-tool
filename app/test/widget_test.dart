// Basic smoke test: app root builds without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('ReaderRootApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ReaderRootApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}