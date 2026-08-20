import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/screens/tasks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([
        {
          'id': 'project-a',
          'name': 'Alpha',
          'description': '',
          'colorValue': 0xFF156F7A,
          'createdAt': '2026-07-01T08:00:00.000',
          'updatedAt': '2026-07-01T08:00:00.000',
        },
      ]),
      'today_tasks_json': jsonEncode([
        {
          'id': 'waiting',
          'title': 'Prepare standards',
          'description': 'Use fresh stock',
          'status': 'notStarted',
          'createdAt': '2026-07-20T08:00:00.000',
          'projectId': 'project-a',
        },
        {
          'id': 'working',
          'title': 'Run PCR',
          'description': '',
          'status': 'inProgress',
          'createdAt': '2026-07-21T08:00:00.000',
        },
        {
          'id': 'finished',
          'title': 'Export results',
          'description': '',
          'status': 'completed',
          'createdAt': '2026-07-22T08:00:00.000',
          'completedAt': '2026-07-22T09:00:00.000',
          'projectId': 'project-a',
        },
      ]),
      'history_tasks_json': jsonEncode([
        {
          'id': 'archived',
          'title': 'Clean bench',
          'description': '',
          'status': 'completed',
          'createdAt': '2026-07-19T08:00:00.000',
          'completedAt': '2026-07-19T09:00:00.000',
        },
      ]),
    });
  });

  Future<void> pumpTasks(
    WidgetTester tester, {
    String? initialProjectId,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksScreen(embedded: true, initialProjectId: initialProjectId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('active states share one tab and archive stays separate', (
    tester,
  ) async {
    await pumpTasks(tester);

    expect(find.text('Prepare standards'), findsOneWidget);
    expect(find.text('Run PCR'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Export results'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Export results'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsWidgets);

    await tester.tap(find.byKey(const Key('tasks-tab-archive')));
    await tester.pumpAndSettle();
    expect(find.text('Clean bench'), findsOneWidget);
    expect(find.byIcon(Icons.archive_outlined), findsWidgets);
  });

  testWidgets(
    'task actions advance, archive, and restore without schema changes',
    (tester) async {
      await pumpTasks(tester);

      await tester.tap(find.byKey(const Key('advance-task-waiting')));
      await tester.pumpAndSettle();
      expect(find.text('Prepare standards'), findsOneWidget);

      await tester.tap(find.byKey(const Key('advance-task-waiting')));
      await tester.pumpAndSettle();
      expect(find.text('Prepare standards'), findsOneWidget);

      await tester.tap(find.byKey(const Key('archive-task-waiting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tasks-tab-archive')));
      await tester.pumpAndSettle();
      expect(find.text('Prepare standards'), findsOneWidget);

      await tester.tap(find.byKey(const Key('restore-task-waiting')));
      await tester.pumpAndSettle();
      expect(find.text('Prepare standards'), findsNothing);

      final preferences = await SharedPreferences.getInstance();
      final active =
          jsonDecode(preferences.getString('today_tasks_json')!) as List;
      final restored = active.cast<Map>().singleWhere(
        (task) => task['id'] == 'waiting',
      );
      expect(restored['status'], 'completed');
      expect(restored.containsKey('projectId'), isTrue);
    },
  );

  testWidgets(
    'search, project filter, and oldest-first sorting work together',
    (tester) async {
      await pumpTasks(tester);

      await tester.enterText(
        find.byKey(const Key('tasks-search-field')),
        'standards',
      );
      await tester.pumpAndSettle();
      expect(find.text('Prepare standards'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('tasks-search-field')),
        'none',
      );
      await tester.pumpAndSettle();
      expect(find.text('Prepare standards'), findsNothing);

      await tester.enterText(find.byKey(const Key('tasks-search-field')), '');
      await tester.tap(find.byKey(const Key('home-task-project-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha').last);
      await tester.pumpAndSettle();
      expect(find.text('Prepare standards'), findsOneWidget);

      expect(find.text('Run PCR'), findsNothing);
      expect(find.text('Export results'), findsOneWidget);
    },
  );

  testWidgets('tasks can open with a project filter', (tester) async {
    await pumpTasks(tester, initialProjectId: 'project-a');

    expect(find.text('Prepare standards'), findsOneWidget);
    expect(find.text('Run PCR'), findsNothing);
  });
}
