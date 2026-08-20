import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/screens/projects_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('projects screen shows direct workspace categories and counts', (
    tester,
  ) async {
    final project = Project(id: 'project-1', name: 'BCA Study');
    final protocol = Protocol(
      id: 'protocol-1',
      title: 'BCA assay',
      objective: '',
      description: '',
      projectId: project.id,
      steps: const [],
    );
    final template = Protocol(
      id: 'template-1',
      title: 'BCA template',
      objective: '',
      description: '',
      projectId: project.id,
      steps: const [],
      isTemplate: true,
    );
    final unassigned = Protocol(
      id: 'protocol-2',
      title: 'Free protocol',
      objective: '',
      description: '',
      steps: const [],
    );

    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([project.toJson()]),
      'protocols_library_json': jsonEncode([
        protocol.toJson(),
        template.toJson(),
        unassigned.toJson(),
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: ProjectsScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('BCA Study'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.byKey(const Key('project-project-1-tasks')), findsOneWidget);
    expect(
      find.byKey(const Key('project-project-1-templates')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('project-project-1-protocols')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('project-project-1-running')), findsOneWidget);
    expect(
      find.byKey(const Key('project-project-1-completed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('project-project-1-tables')), findsOneWidget);
  });

  testWidgets('project categories open filtered destination callbacks', (
    tester,
  ) async {
    final project = Project(id: 'project-1', name: 'BCA Study');
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([project.toJson()]),
    });
    String? tasksProject;
    String? tablesProject;
    String? protocolProject;
    int? protocolTab;

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(
          embedded: true,
          onTasksSelected: (projectId) => tasksProject = projectId,
          onProtocolSelected: (tabIndex, projectId) {
            protocolTab = tabIndex;
            protocolProject = projectId;
          },
          onTablesSelected: (projectId) => tablesProject = projectId,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('project-project-1-tasks')));
    expect(tasksProject, 'project-1');

    await tester.tap(find.byKey(const Key('project-project-1-running')));
    expect(protocolProject, 'project-1');
    expect(protocolTab, 2);

    await tester.tap(find.byKey(const Key('project-project-1-tables')));
    expect(tablesProject, 'project-1');
  });
}
