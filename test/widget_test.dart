import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protocolflow/main.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_run.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/screens/library_screen.dart';
import 'package:protocolflow/screens/more_screen.dart';
import 'package:protocolflow/screens/protocol_detail_screen.dart';
import 'package:protocolflow/screens/user_guide_screen.dart';
import 'package:protocolflow/services/storage_service.dart';
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
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('Protocols'), findsWidgets);
    expect(find.text('Saved Tables'), findsOneWidget);
    expect(find.byKey(const Key('home-projects-section')), findsOneWidget);
    expect(find.byKey(const Key('home-project-global')), findsOneWidget);
    expect(find.byKey(const Key('home-protocols-section')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byTooltip('Refresh running protocols'), findsNothing);
    expect(find.byKey(const Key('home-today-tasks-section')), findsOneWidget);
    expect(find.byKey(const Key('home-saved-tables-section')), findsOneWidget);
    expect(find.byKey(const Key('home-task-project-filter')), findsNothing);
    expect(find.byKey(const Key('home-table-project-filter')), findsNothing);
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

    expect(find.byTooltip('Add task'), findsOneWidget);
    expect(find.byTooltip('Add project'), findsOneWidget);
    expect(find.byTooltip('Add protocol'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Add table'));
    expect(find.byTooltip('Add table'), findsOneWidget);
    expect(find.text('Working locally'), findsOneWidget);
  });

  testWidgets('Protocols navigation opens running and paused protocols', (
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
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Protocols'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    await tester.tap(find.text('Running').first);
    await tester.pumpAndSettle();
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
    expect(find.byKey(const Key('home-projects-section')), findsOneWidget);
    expect(find.byKey(const Key('home-protocols-section')), findsOneWidget);
    expect(find.byKey(const Key('home-saved-tables-section')), findsOneWidget);
    expect(find.text('Welcome to ProtocolFlow'), findsNothing);
  });

  testWidgets('Protocols navigation opens the four-tab library', (
    tester,
  ) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Protocols'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LibraryScreen), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.tabs.length, 4);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Protocols'), findsWidgets);
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
    expect(navigation.destinations.length, 5);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('Protocols'), findsWidgets);
    expect(find.text('Add'), findsOneWidget);
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

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Tasks'),
      ),
    );
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

  testWidgets('Project cards filter Home lists and Global restores them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'today_tasks_json': jsonEncode([
        {
          'id': 'task-a',
          'title': 'Alpha task',
          'description': '',
          'status': 'notStarted',
          'createdAt': '2026-07-22T08:00:00.000',
          'projectId': 'project-a',
        },
        {
          'id': 'task-b',
          'title': 'Beta task',
          'description': '',
          'status': 'notStarted',
          'createdAt': '2026-07-22T09:00:00.000',
          'projectId': 'project-b',
        },
      ]),
    });
    await StorageService().saveProjects([
      Project(id: 'project-a', name: 'Alpha', colorValue: 0xFF00897B),
      Project(id: 'project-b', name: 'Beta', colorValue: 0xFFAB47BC),
    ]);
    await StorageService().saveProtocols([
      Protocol(
        id: 'protocol-a',
        title: 'Alpha protocol',
        objective: '',
        description: '',
        projectId: 'project-a',
        steps: const [],
      ),
      Protocol(
        id: 'protocol-b',
        title: 'Beta protocol',
        objective: '',
        description: '',
        projectId: 'project-b',
        steps: const [],
      ),
    ]);
    await StorageService().saveProtocolRuns([
      for (final projectId in ['project-a', 'project-b'])
        ProtocolRun(
          id: 'run-$projectId',
          protocolId: 'active-$projectId',
          projectId: projectId,
          protocolSnapshot: Protocol(
            id: 'active-$projectId',
            title: 'Active $projectId',
            objective: '',
            description: '',
            projectId: projectId,
            steps: const [],
          ),
          status: ProtocolRunStatus.running,
          startedAt: DateTime(2026, 7, 22),
          createdAt: DateTime(2026, 7, 22),
          updatedAt: DateTime(2026, 7, 22),
        ),
    ]);
    await StorageService().saveSavedTables([
      ProtocolTable(
        id: 'table-a',
        title: 'Alpha plate',
        projectId: 'project-a',
      ),
      ProtocolTable(id: 'table-b', title: 'Beta mix', projectId: 'project-b'),
    ]);

    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Alpha task'), findsOneWidget);
    expect(find.text('Beta task'), findsOneWidget);
    expect(find.byKey(const Key('home-protocol-protocol-a')), findsOneWidget);
    expect(find.byKey(const Key('home-protocol-protocol-b')), findsOneWidget);
    expect(
      find.byKey(const Key('home-running-protocol-run-project-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-running-protocol-run-project-b')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-table-table-a')), findsOneWidget);
    expect(find.byKey(const Key('home-table-table-b')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-project-project-a')));
    await tester.pumpAndSettle();

    expect(find.text('Alpha task'), findsOneWidget);
    expect(find.text('Beta task'), findsNothing);
    expect(find.byKey(const Key('home-protocol-protocol-a')), findsOneWidget);
    expect(find.byKey(const Key('home-protocol-protocol-b')), findsNothing);
    expect(
      find.byKey(const Key('home-running-protocol-run-project-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-running-protocol-run-project-b')),
      findsNothing,
    );
    expect(find.byKey(const Key('home-table-table-a')), findsOneWidget);
    expect(find.byKey(const Key('home-table-table-b')), findsNothing);
    expect(find.byKey(const Key('home-project-project-a')), findsOneWidget);
    expect(find.byKey(const Key('home-project-project-b')), findsOneWidget);
    final alphaTableIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('home-table-table-a')),
        matching: find.byIcon(Icons.table_chart_outlined),
      ),
    );
    expect(alphaTableIcon.color, const Color(0xFF00897B));
    final alphaProtocolIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('home-protocol-protocol-a')),
        matching: find.byIcon(Icons.description_outlined),
      ),
    );
    expect(alphaProtocolIcon.color, const Color(0xFF00897B));
    final alphaRunningIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('home-running-protocol-run-project-a')),
        matching: find.byIcon(Icons.play_circle_outline),
      ),
    );
    expect(alphaRunningIcon.color, const Color(0xFF00897B));
    final alphaTaskColor = tester.widget<Container>(
      find.byKey(const Key('home-task-project-color-task-a')),
    );
    expect(
      (alphaTaskColor.decoration! as BoxDecoration).color,
      const Color(0xFF00897B),
    );

    await tester.tap(find.byKey(const Key('home-project-global')));
    await tester.pumpAndSettle();
    expect(find.text('Beta task'), findsOneWidget);
    expect(find.byKey(const Key('home-protocol-protocol-b')), findsOneWidget);
    expect(
      find.byKey(const Key('home-running-protocol-run-project-b')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-table-table-b')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Desktop Projects controls scroll the Home carousel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await StorageService().saveProjects([
      for (var index = 0; index < 6; index++)
        Project(id: 'project-$index', name: 'Project $index'),
    ]);

    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    final carousel = find.descendant(
      of: find.byKey(const Key('home-projects-section')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(carousel).position;
    expect(position.pixels, 0);
    expect(find.byTooltip('Next projects'), findsOneWidget);
    final projectScrollbar = tester.widget<Scrollbar>(
      find.descendant(
        of: find.byKey(const Key('home-projects-section')),
        matching: find.byType(Scrollbar),
      ),
    );
    expect(projectScrollbar.thumbVisibility, isTrue);
    expect(projectScrollbar.trackVisibility, isTrue);
    expect(projectScrollbar.scrollbarOrientation, ScrollbarOrientation.bottom);

    await tester.tap(find.byTooltip('Next projects'));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));

    await tester.tap(find.byTooltip('Previous projects'));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shows three recent protocols below highlighted runs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await StorageService().saveProtocols([
      for (var index = 0; index < 5; index++)
        Protocol(
          id: 'recent-$index',
          title: 'Recent protocol $index',
          objective: '',
          description: '',
          updatedAt: DateTime(2026, 7, index + 1),
          steps: const [],
        ),
      Protocol(
        id: 'recent-template',
        title: 'Recent template',
        objective: '',
        description: '',
        updatedAt: DateTime(2026, 8, 1),
        isTemplate: true,
        steps: const [],
      ),
    ]);

    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('home-running-protocols')), findsOneWidget);
    expect(find.text('Running protocols'), findsOneWidget);
    expect(find.text('Recent protocols'), findsOneWidget);
    for (var index = 0; index < 2; index++) {
      expect(find.byKey(Key('home-protocol-recent-$index')), findsNothing);
    }
    for (var index = 2; index < 5; index++) {
      expect(find.byKey(Key('home-protocol-recent-$index')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('home-protocol-recent-template')),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.text('Recent protocol 4')).dy,
      lessThan(tester.getTopLeft(find.text('Recent protocol 3')).dy),
    );
  });

  testWidgets('Home limits and sorts running and recent protocols separately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runningProtocols = [
      for (var index = 0; index < 4; index++)
        Protocol(
          id: 'running-$index',
          title: 'Running protocol $index',
          objective: '',
          description: '',
          steps: const [],
        ),
    ];
    final recentProtocols = [
      for (var index = 0; index < 5; index++)
        Protocol(
          id: 'recent-$index',
          title: 'Recent protocol $index',
          objective: '',
          description: '',
          updatedAt: DateTime(2026, 7, index + 1),
          steps: const [],
        ),
    ];
    await StorageService().saveProtocols([
      ...runningProtocols,
      ...recentProtocols,
    ]);
    await StorageService().saveProtocolRuns([
      for (var index = 0; index < runningProtocols.length; index++)
        ProtocolRun(
          id: 'run-$index',
          protocolId: runningProtocols[index].id,
          protocolSnapshot: runningProtocols[index],
          status: index == 1
              ? ProtocolRunStatus.paused
              : ProtocolRunStatus.running,
          startedAt: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, index + 1),
        ),
    ]);

    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));

    final highlighted = tester.widget<Container>(
      find.byKey(const Key('home-running-protocols')),
    );
    expect((highlighted.decoration! as BoxDecoration).color, isNotNull);
    expect(find.byKey(const Key('home-running-protocol-run-0')), findsNothing);
    for (var index = 1; index < 4; index++) {
      expect(
        find.byKey(Key('home-running-protocol-run-$index')),
        findsOneWidget,
      );
    }
    for (var index = 0; index < 2; index++) {
      expect(find.byKey(Key('home-protocol-recent-$index')), findsNothing);
    }
    for (var index = 2; index < 5; index++) {
      expect(find.byKey(Key('home-protocol-recent-$index')), findsOneWidget);
    }
    expect(find.byKey(const Key('home-protocol-running-3')), findsNothing);
    expect(
      tester.getTopLeft(find.text('Running protocol 3')).dy,
      lessThan(tester.getTopLeft(find.text('Running protocol 2')).dy),
    );

    await tester.ensureVisible(
      find.byKey(const Key('home-running-protocol-run-3')),
    );
    await tester.tap(find.byKey(const Key('home-running-protocol-run-3')));
    await tester.pumpAndSettle();
    final detail = tester.widget<ProtocolDetailScreen>(
      find.byType(ProtocolDetailScreen),
    );
    expect(detail.activeState?.runId, 'run-3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add navigation offers task and table creation', (tester) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to ProtocolFlow'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Table or lab tool'), findsOneWidget);
  });

  testWidgets('Home task preview filters by project and caps at four rows', (
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
          'id': 'earliest-alpha',
          'title': 'Earliest Alpha task',
          'description': '',
          'status': 'notStarted',
          'createdAt': '2026-07-19T08:00:00.000',
          'projectId': 'project-a',
        },
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

    expect(find.text('Earliest Alpha task'), findsNothing);
    expect(
      tester.getTopLeft(find.text('New completed task')).dy,
      lessThan(tester.getTopLeft(find.text('Old completed task')).dy),
    );

    await tester.tap(find.byKey(const Key('home-project-project-a')));
    await tester.pumpAndSettle();

    expect(find.text('Beta task'), findsNothing);
    expect(find.text('Old completed task'), findsOneWidget);
    expect(find.text('New completed task'), findsOneWidget);
    expect(find.text('Earliest Alpha task'), findsOneWidget);
    expect(find.byKey(const Key('home-project-global')), findsOneWidget);

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    final projectDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(projectDropdown.initialValue, 'project-a');
  });
}
