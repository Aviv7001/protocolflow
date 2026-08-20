import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/features/measuring_tools/screens/measuring_tools_manager_screen.dart';
import 'package:protocolflow/main.dart';
import 'package:protocolflow/screens/dashboard_screen.dart';
import 'package:protocolflow/screens/more_screen.dart';
import 'package:protocolflow/screens/user_guide_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'home_explore_locally_v1': true});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];
    protocolRuns = [];
  });

  Future<void> openMore(WidgetTester tester) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
  }

  Future<void> openAndReturn(
    WidgetTester tester, {
    required Key tileKey,
    required Finder destination,
    VoidCallback? verify,
  }) async {
    final tile = find.byKey(tileKey);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(destination, findsOneWidget);
    verify?.call();
    Navigator.of(tester.element(destination)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
  }

  testWidgets('More keeps only the requested secondary destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openMore(tester);

    expect(find.byKey(const Key('more-saved-tables')), findsNothing);
    expect(find.byKey(const Key('more-task-history')), findsNothing);
    expect(find.byKey(const Key('more-completed-runs')), findsNothing);
    expect(find.byKey(const Key('more-account')), findsNothing);
    expect(find.byKey(const Key('more-sync')), findsNothing);
    await openAndReturn(
      tester,
      tileKey: const Key('more-dashboard'),
      destination: find.byType(DashboardScreen),
      verify: () => expect(find.byTooltip('Back'), findsOneWidget),
    );
  });

  testWidgets('More tools and guidance items open the correct screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openMore(tester);

    await openAndReturn(
      tester,
      tileKey: const Key('more-measuring-tools'),
      destination: find.byType(MeasuringToolsManagerScreen),
    );
    await openAndReturn(
      tester,
      tileKey: const Key('more-user-guide'),
      destination: find.byType(UserGuideScreen),
    );
  });

  testWidgets('More settings callback remains wired', (tester) async {
    var settingsCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MoreScreen(onOpenSettings: () => settingsCount++)),
      ),
    );

    final tile = find.byKey(const Key('more-settings'));
    await tester.scrollUntilVisible(
      tile,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pump();

    expect(settingsCount, 1);
  });

  testWidgets('More settings entry opens Settings workspace', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openMore(tester);

    final tile = find.byKey(const Key('more-settings'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Backup and restore'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
  });
}
