import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/task.dart';
import 'package:protocolflow/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('dashboard renders responsive sections with empty data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DashboardScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Protocol activity'), findsOneWidget);
    expect(find.text('Today\'s task status'), findsOneWidget);
    expect(find.text('Activity heatmap'), findsOneWidget);
    expect(find.text('Data health'), findsOneWidget);
    expect(find.text('Recent exports'), findsOneWidget);
    expect(find.text('30d'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard renders charts from persisted activity', (
    tester,
  ) async {
    final now = DateTime.now();
    final table = ProtocolTable(
      id: 'table-1',
      title: 'Serial dilution',
      type: TableType.serialDilution,
    );
    final protocol = Protocol(
      id: 'protocol-1',
      title: 'BCA assay',
      objective: '',
      description: '',
      createdAt: now.subtract(const Duration(days: 2)),
      steps: const [],
      tables: [table],
    );
    final completed = CompletedProtocol(
      id: 'completed-1',
      protocol: protocol,
      notes: const [],
      startedAt: now.subtract(const Duration(hours: 3)),
      completedAt: now.subtract(const Duration(hours: 1)),
    );
    final task = Task(
      id: 'task-1',
      title: 'Prepare standards',
      description: '',
      status: TaskStatus.inProgress,
      createdAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'protocols_library_json': jsonEncode([protocol.toJson()]),
      'completed_protocols_json': jsonEncode([completed.toJson()]),
      'saved_tables_json': jsonEncode([table.toJson()]),
      'saved_tables_sync_state': 'synced',
      'today_tasks_json': jsonEncode([task.toJson()]),
    });
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DashboardScreen())),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(PieChart), findsNWidgets(2));
    expect(find.text('BCA assay'), findsWidgets);
    expect(find.text('2h 0m'), findsOneWidget);
    expect(find.text('Protocols'), findsWidgets);
    expect(find.text('Templates'), findsWidgets);
    expect(find.text('Tables'), findsWidgets);
    final tableSynced = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('data-health-tables-synced')),
        matching: find.byType(Text),
      ),
    );
    expect(tableSynced.data, '1');
    expect(tester.takeException(), isNull);
  });
}
