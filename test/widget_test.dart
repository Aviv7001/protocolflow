import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protocolflow/main.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_run.dart';
import 'package:protocolflow/screens/library_screen.dart';
import 'package:protocolflow/screens/more_screen.dart';
import 'package:protocolflow/screens/user_guide_screen.dart';
import 'package:protocolflow/widgets/running_protocol_summary_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'home_explore_locally_v1': true});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];
    protocolRuns = [];
  });

  testWidgets('ProtocolFlow home screen renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('first-use-login-screen')), findsOneWidget);
    expect(find.text('Welcome to ProtocolFlow'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Explore locally'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Explore locally'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-stable-dashboard')), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Protocols'), findsWidgets);
    expect(find.text('Lab Tools'), findsOneWidget);
    expect(find.text('Saved Tables'), findsOneWidget);
    expect(find.byKey(const Key('home-projects-section')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byTooltip('Refresh running protocols'), findsNothing);
    expect(find.byKey(const Key('home-resume-work-section')), findsOneWidget);
    expect(find.byKey(const Key('home-today-tasks-section')), findsOneWidget);
    expect(find.byKey(const Key('home-quick-start-section')), findsOneWidget);
    expect(find.byKey(const Key('home-saved-tables-section')), findsOneWidget);
    expect(find.byTooltip('Sync and account'), findsNothing);
    expect(
      tester.getCenter(find.byKey(const Key('home-profile-button'))).dx,
      greaterThan(
        tester
            .getCenter(
              find.textContaining(RegExp(r'^Good (morning|afternoon|evening)')),
            )
            .dx,
      ),
    );

    expect(find.text('Calculators and layouts'), findsOneWidget);
    expect(find.text('Add Task'), findsOneWidget);
    expect(find.text('Create/Import Protocol'), findsOneWidget);
    expect(find.text('Create Project'), findsOneWidget);
    expect(find.text('Create Table'), findsOneWidget);
  });

  testWidgets('Home summarizes running and paused protocols in Library', (
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
    final run = ProtocolRun(
      id: 'RUN-20260730-HOME0001',
      protocolId: protocol.id,
      projectId: protocol.projectId,
      protocolSnapshot: protocol,
      status: ProtocolRunStatus.running,
      currentStepIndex: 0,
      notes: const [],
      startedAt: DateTime(2026, 7, 30),
      createdAt: DateTime(2026, 7, 30),
      updatedAt: DateTime(2026, 7, 30),
      completedStepIds: const {'home-step-1'},
    );
    final pausedProtocol = Protocol(
      id: 'home-paused-protocol',
      title: 'Paused staining run',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'paused-step-1',
          title: 'Add antibodies',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Staining',
        ),
      ],
    );
    final pausedRun = ProtocolRun(
      id: 'RUN-20260730-HOME0002',
      protocolId: pausedProtocol.id,
      protocolSnapshot: pausedProtocol,
      status: ProtocolRunStatus.paused,
      currentStepIndex: 0,
      notes: const [],
      startedAt: DateTime(2026, 7, 29),
      createdAt: DateTime(2026, 7, 29),
      updatedAt: DateTime(2026, 7, 30),
    );
    SharedPreferences.setMockInitialValues({
      'protocol_runs_json': jsonEncode([run.toJson(), pausedRun.toJson()]),
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

    expect(find.byType(RunningProtocolSummaryCard), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-protocol-count-running')));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(RunningProtocolSummaryCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('local protocol still shows the stable home dashboard', (
    tester,
  ) async {
    final protocol = Protocol(
      id: 'first-run-protocol',
      title: 'First local protocol',
      objective: '',
      description: '',
      steps: const [],
    );
    SharedPreferences.setMockInitialValues({
      'protocols_library_json': jsonEncode([protocol.toJson()]),
    });

    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('home-stable-dashboard')), findsOneWidget);
    expect(find.byKey(const Key('home-today-tasks-section')), findsOneWidget);
    expect(find.byKey(const Key('home-resume-work-section')), findsOneWidget);
    expect(find.byKey(const Key('home-projects-section')), findsOneWidget);
    expect(find.byKey(const Key('home-quick-start-section')), findsOneWidget);
    expect(find.byKey(const Key('home-saved-tables-section')), findsOneWidget);
    expect(find.text('Welcome to ProtocolFlow'), findsNothing);
  });

  testWidgets('Library navigation opens the four-tab library', (tester) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    await tester.tap(find.text('Library'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LibraryScreen), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.tabs.length, 4);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Protocols'), findsOneWidget);
    expect(find.text('Running'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);

    await tester.tap(find.byKey(const Key('library-import-button')));
    await tester.pumpAndSettle();

    expect(find.text('Import from file'), findsOneWidget);
    expect(find.text('Scan QR code'), findsOneWidget);
  });

  testWidgets('More navigation keeps secondary features accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    await tester.tap(find.text('More'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.text('Saved Tables'), findsNothing);
    expect(find.text('Task History'), findsNothing);
    expect(find.text('Completed Runs'), findsNothing);
    expect(find.text('Google Account'), findsNothing);
    expect(find.text('Sync now'), findsNothing);
    expect(find.text('Measuring Tools'), findsOneWidget);
  });

  testWidgets('desktop uses the floating primary navigation bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NavigationRail), findsNothing);
    expect(
      find.byKey(const Key('floating-primary-navigation')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations.length, 4);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('More opens the user guide', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('User Guide'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('User Guide'));
    await tester.pumpAndSettle();

    expect(find.byType(UserGuideScreen), findsOneWidget);
    expect(find.text('INSTALLING PROTOCOLFLOW'), findsOneWidget);
  });

  testWidgets('Tasks shows project-ready status and preserves completion', (
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

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tasks-tab-active')), findsOneWidget);
    expect(find.byKey(const Key('tasks-tab-archive')), findsOneWidget);
    expect(find.text('Export results'), findsOneWidget);
    expect(find.text('Prepare BSA standards'), findsOneWidget);

    await tester.tap(find.byKey(const Key('advance-task-task-1')));
    await tester.pumpAndSettle();
    expect(find.text('Prepare BSA standards'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);

    final preferences = await SharedPreferences.getInstance();
    final savedTasks =
        jsonDecode(preferences.getString('today_tasks_json')!) as List<dynamic>;
    expect(
      savedTasks.singleWhere((task) => task['id'] == 'task-1')['status'],
      'completed',
    );

    expect(find.text('Prepare BSA standards'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });

  testWidgets('Tasks are chronological, filter by project, and archive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([
        {'id': 'project-a', 'name': 'Alpha', 'colorValue': 4280391411},
        {'id': 'project-b', 'name': 'Beta', 'colorValue': 4283215696},
      ]),
      'today_tasks_json': jsonEncode([
        {
          'id': 'old-completed',
          'title': 'Old completed task',
          'description': '',
          'status': 'completed',
          'createdAt': '2026-07-20T08:00:00.000',
          'projectId': 'project-a',
        },
        {
          'id': 'open-alpha',
          'title': 'Open Alpha task',
          'description': '',
          'status': 'notStarted',
          'createdAt': '2026-07-21T08:00:00.000',
          'projectId': 'project-a',
        },
        {
          'id': 'new-completed',
          'title': 'New completed task',
          'description': '',
          'status': 'completed',
          'createdAt': '2026-07-22T08:00:00.000',
          'projectId': 'project-a',
        },
        {
          'id': 'beta-task',
          'title': 'Beta task',
          'description': '',
          'status': 'completed',
          'createdAt': '2026-07-23T08:00:00.000',
          'projectId': 'project-b',
        },
      ]),
    });

    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Old completed task')).dy,
      lessThan(tester.getTopLeft(find.text('New completed task')).dy),
    );

    await tester.tap(find.byKey(const Key('home-task-project-filter')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Alpha'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beta task'), findsNothing);
    expect(find.text('Archive all (2)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('archive-task-old-completed')));
    await tester.pumpAndSettle();
    expect(find.text('Old completed task'), findsNothing);
    expect(find.text('Archive all (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-archive-completed-tasks')));
    await tester.pumpAndSettle();
    expect(find.text('New completed task'), findsNothing);

    await tester.tap(find.byKey(const Key('tasks-tab-archive')));
    await tester.pumpAndSettle();
    expect(find.text('Old completed task'), findsOneWidget);
    expect(find.text('New completed task'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final history =
        jsonDecode(preferences.getString('history_tasks_json')!)
            as List<dynamic>;
    expect(
      history.map((task) => task['id']),
      containsAll(['old-completed', 'new-completed']),
    );

    await tester.tap(find.byKey(const Key('restore-task-old-completed')));
    await tester.pumpAndSettle();
    expect(find.text('Old completed task'), findsNothing);

    await tester.tap(find.byKey(const Key('tasks-tab-active')));
    await tester.pumpAndSettle();
    expect(find.text('Old completed task'), findsOneWidget);
  });
}
