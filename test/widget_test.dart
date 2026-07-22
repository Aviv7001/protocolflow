import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protocolflow/main.dart';
import 'package:protocolflow/screens/library_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ProtocolFlow home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    expect(find.text('ProtocolFlow'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Today\'s Tasks'), findsOneWidget);
    expect(find.text('Resume Work'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);
    expect(find.text('New protocol'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Lab tools'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Sign in to sync with Google Drive'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byTooltip('Refresh running protocols'), findsNothing);
  });

  testWidgets('Quick Start Library opens the Protocols tab', (tester) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    await tester.ensureVisible(find.text('Library'));
    await tester.pump();
    await tester.tap(find.text('Library'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LibraryScreen), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller?.index, 1);
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
    expect(find.text('2 tasks'), findsOneWidget);

    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);

    await tester.tap(find.byTooltip('Task options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final savedTasks =
        jsonDecode(preferences.getString('today_tasks_json')!) as List<dynamic>;
    expect(savedTasks.first['id'], 'task-2');
    expect(savedTasks.last['status'], 'completed');

    await tester.tap(find.byTooltip('Shrink tasks'));
    await tester.pump();

    expect(find.text('Prepare BSA standards'), findsNothing);
    expect(find.byTooltip('Expand tasks'), findsOneWidget);
  });
}
