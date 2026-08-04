import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protocolflow/main.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/screens/library_screen.dart';
import 'package:protocolflow/screens/user_guide_screen.dart';
import 'package:protocolflow/widgets/running_protocol_summary_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];
  });

  testWidgets('ProtocolFlow home screen renders', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    expect(find.text('ProtocolFlow'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byKey(const Key('user-guide-banner')), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Today\'s Tasks'), findsOneWidget);
    expect(find.text('Resume Work'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);
    expect(find.text('New protocol'), findsOneWidget);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Lab tools'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Sync Status'), findsOneWidget);
    expect(find.text('ProtocolFlow User Guide'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Sign in to sync with Google Drive'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byTooltip('Refresh running protocols'), findsNothing);
    expect(find.byKey(const Key('home-resume-work-section')), findsOneWidget);
    expect(find.byKey(const Key('home-today-tasks-section')), findsOneWidget);
    expect(find.byKey(const Key('home-quick-start-section')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('home-today-tasks-section'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('home-resume-work-section'))).dy,
      ),
    );
  });

  testWidgets('Resume Work uses the shared Running protocol card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final protocol = Protocol(
      id: 'home-running-protocol',
      title: 'Cell viability run',
      objective: '',
      description: '',
      projectId: 'project-1',
      steps: [
        ProtocolStep(
          id: 'home-step-1',
          title: 'Prepare plate',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Preparation',
        ),
        ProtocolStep(
          id: 'home-step-2',
          title: 'Read plate',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Measurement',
        ),
      ],
    );
    activeProtocol = ActiveProtocol(
      protocol: protocol,
      currentStepIndex: 1,
      notes: const [],
      startedAt: DateTime(2026, 7, 30),
      completedStepIds: const {'home-step-1'},
    );
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([
        {
          'id': 'project-1',
          'name': 'Viability Study',
          'colorValue': 4280391411,
        },
      ]),
    });

    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    final runningCard = find.byType(RunningProtocolSummaryCard);
    expect(runningCard, findsOneWidget);
    expect(
      tester.widget<RunningProtocolSummaryCard>(runningCard).compact,
      isTrue,
    );
    expect(tester.getSize(runningCard).height, lessThan(240));
    expect(find.text('RUNNING'), findsOneWidget);
    expect(find.text('Viability Study'), findsOneWidget);
    expect(find.text('1 running protocol'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(
      find.byKey(
        const Key('home-running-phase-progress-home-running-protocol'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final viewAll = find.byKey(const Key('home-view-all-running'));
    await tester.ensureVisible(viewAll);
    await tester.tap(viewAll);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);
  });

  testWidgets('Quick Start Library opens the Protocols tab', (tester) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    final quickStartLibrary = find.text('Library').first;
    await tester.ensureVisible(quickStartLibrary);
    await tester.pump();
    await tester.tap(quickStartLibrary);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LibraryScreen), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller?.index, 1);
  });

  testWidgets('Active navigation opens the Running tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    await tester.tap(find.text('Active'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LibraryScreen), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller?.index, 2);
  });

  testWidgets('home cards expand at desktop widths', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    final quickStartCard = find
        .ancestor(of: find.text('New protocol'), matching: find.byType(Card))
        .first;
    expect(tester.getSize(quickStartCard).height, greaterThanOrEqualTo(150));
    expect(
      tester.getSize(find.byKey(const Key('user-guide-banner'))).height,
      240,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    final floatingNavigation = find.byKey(
      const Key('floating-primary-navigation'),
    );
    expect(floatingNavigation, findsOneWidget);
    expect(tester.getSize(floatingNavigation).width, 560);
    expect(
      tester.getBottomLeft(floatingNavigation).dy,
      lessThan(tester.view.physicalSize.height),
    );
  });

  testWidgets('sidebar opens the user guide', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Open sidebar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('User Guide'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('User Guide'));
    await tester.pumpAndSettle();

    expect(find.byType(UserGuideScreen), findsOneWidget);
    expect(find.text('Installing ProtocolFlow'), findsOneWidget);
  });

  testWidgets('Today tasks shows status and collapses its rows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'today_tasks_json': jsonEncode([
        {
          'id': 'task-1',
          'title': 'Prepare BSA standards',
          'description': 'Use the fresh stock',
          'status': 'inProgress',
          'createdAt': '2026-07-22T08:00:00.000',
        },
        {
          'id': 'task-2',
          'title': 'Export results',
          'description': '',
          'status': 'notStarted',
          'createdAt': '2026-07-22T09:00:00.000',
        },
      ]),
    });

    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Prepare BSA standards'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('2 tasks remaining'), findsOneWidget);

    await tester.ensureVisible(find.text('In progress'));
    await tester.pump();
    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Task options').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Task options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final savedTasks =
        jsonDecode(preferences.getString('today_tasks_json')!) as List<dynamic>;
    expect(savedTasks.first['id'], 'task-2');
    expect(savedTasks.last['status'], 'completed');

    await tester.ensureVisible(find.byTooltip('Shrink tasks'));
    await tester.pump();
    await tester.tap(find.byTooltip('Shrink tasks'));
    await tester.pump();

    expect(find.text('Prepare BSA standards'), findsNothing);
    expect(find.byTooltip('Expand tasks'), findsOneWidget);
  });
}
