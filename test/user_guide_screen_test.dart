import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/screens/user_guide_screen.dart';

void main() {
  testWidgets('user guide shows topic list tiles with collapsed content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: UserGuideScreen(embedded: true)),
    );

    expect(find.text('User Guide'), findsOneWidget);
    expect(find.text('INSTALLING PROTOCOLFLOW'), findsOneWidget);
    expect(find.text('GOOGLE SYNC AND DATA SAFETY'), findsOneWidget);
    expect(find.text('Windows'), findsOneWidget);
    expect(find.textContaining('progressive web app'), findsNothing);

    await tester.tap(find.byTooltip('Expand Windows'));
    await tester.pumpAndSettle();
    expect(find.textContaining('progressive web app'), findsOneWidget);
  });

  testWidgets('Google Sync guide includes limited testing access details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: UserGuideScreen(embedded: true)),
    );

    expect(find.text('Request access'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand Request access'));
    await tester.pumpAndSettle();
    expect(find.textContaining('currently in limited testing'), findsOneWidget);
    expect(find.textContaining('Aviv7001@gmail.com'), findsOneWidget);
  });
}
