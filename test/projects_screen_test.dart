import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/screens/projects_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('projects screen shows project and unassigned counts', (
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
    expect(find.text('1 protocols, 1 templates'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.text('1 protocols, 0 templates'), findsOneWidget);
  });
}
