import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevalink/main.dart';

void main() {
  testWidgets('JeevaLinkApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JeevaLinkApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
