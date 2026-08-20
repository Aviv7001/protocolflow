import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/task.dart';
import 'package:protocolflow/screens/project_detail_screen.dart';
import 'package:protocolflow/screens/library_screen.dart';
import 'package:protocolflow/widgets/protocolflow_app_bar.dart';
import 'package:protocolflow/screens/protocols_screen.dart';

void main() {
  testWidgets('empty project shows focused contextual creation actions', (
    tester,
  ) async {
    final project = Project(id: 'empty-project', name: 'AML');
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([project.toJson()]),
    });

    await tester.pumpWidget(
      MaterialApp(home: ProjectDetailScreen(project: project)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('empty-project-prompt')), findsOneWidget);
    expect(find.text('This project is empty.'), findsOneWidget);
    expect(find.text('Running'), findsNothing);
    expect(find.text('Tasks'), findsNothing);
    expect(find.text('Protocols'), findsNothing);
    expect(find.text('Tables & Calculations'), findsNothing);
    expect(find.text('Add protocol'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
    expect(find.text('Quick Tool'), findsOneWidget);

    await tester.tap(find.text('Quick Tool'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('table-tool-picker-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('table-tool-project-context-empty-project')),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(find.byKey(const Key('table-tool-picker-dialog'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add protocol'));
    await tester.pumpAndSettle();
    expect(find.text('Protocol Builder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project workspace derives only items assigned by projectId', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = Project(id: 'project-a', name: 'Cell Study');
    final assignedProtocol = Protocol(
      id: 'protocol-a',
      title: 'Assigned protocol',
      objective: '',
      description: '',
      projectId: project.id,
      steps: [
        ProtocolStep(
          id: 'step-a',
          title: 'Prepare cells',
          instructions: '',
          actionItems: const [],
          materials: const [],
        ),
      ],
    );
    final otherProtocol = Protocol(
      id: 'protocol-b',
      title: 'Other protocol',
      objective: '',
      description: '',
      steps: const [],
    );
    final running = ActiveProtocol(
      protocol: assignedProtocol,
      notes: const [],
      startedAt: DateTime(2026, 8, 13),
    );
    final assignedTask = Task(
      id: 'task-a',
      title: 'Assigned task',
      description: '',
      createdAt: DateTime(2026, 8, 13),
      projectId: project.id,
    );
    final otherTask = Task(
      id: 'task-b',
      title: 'Other task',
      description: '',
      createdAt: DateTime(2026, 8, 13),
    );
    final assignedTable = ProtocolTable(
      id: 'table-a',
      title: 'Assigned calculation',
      projectId: project.id,
    );
    final otherTable = ProtocolTable(id: 'table-b', title: 'Other table');

    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([project.toJson()]),
      'protocols_library_json': jsonEncode([
        assignedProtocol.toJson(),
        otherProtocol.toJson(),
      ]),
      'today_tasks_json': jsonEncode([
        assignedTask.toJson(),
        otherTask.toJson(),
      ]),
      'saved_tables_json': jsonEncode([
        assignedTable.toJson(),
        otherTable.toJson(),
      ]),
      'active_protocol_json': jsonEncode(running.toJson()),
    });

    await tester.pumpWidget(
      MaterialApp(home: ProjectDetailScreen(project: project)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Assigned task'), findsOneWidget);
    expect(find.text('Assigned protocol'), findsWidgets);
    expect(find.text('Assigned calculation'), findsOneWidget);
    expect(find.text('Other task'), findsNothing);
    expect(find.text('Other protocol'), findsNothing);
    expect(find.text('Other table'), findsNothing);
    expect(find.byType(ProtocolFlowAppBar), findsOneWidget);

    await tester.tap(find.text('Start protocol'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(ProtocolsScreen), findsOneWidget);
    expect(find.byType(ProtocolFlowAppBar), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
