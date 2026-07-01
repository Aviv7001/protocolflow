import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:protocolflow/main.dart';

void main() {
  testWidgets('ProtocolFlow home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    expect(find.text('ProtocolFlow'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Today\'s Tasks'), findsOneWidget);
    expect(find.text('Running Protocols'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);
  });
}
