import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/screens/user_guide_screen.dart';

void main() {
  testWidgets('user guide sections and subsections start collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: UserGuideScreen(embedded: true)),
    );

    expect(find.text('User Guide'), findsOneWidget);
    expect(find.text('Installing ProtocolFlow'), findsOneWidget);
    expect(find.text('Google Sync and Data Safety'), findsOneWidget);
    expect(find.text('Windows'), findsNothing);

    await tester.tap(find.byTooltip('Expand Installing ProtocolFlow'));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byTooltip('Expand Google Sync and Data Safety'));
    await tester.pumpAndSettle();
    expect(find.text('Request access'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand Request access'));
    await tester.pumpAndSettle();
    expect(find.textContaining('currently in limited testing'), findsOneWidget);
    expect(find.textContaining('Aviv7001@gmail.com'), findsOneWidget);
  });
}
