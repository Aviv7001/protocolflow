import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/screens/completed_protocol_detail_screen.dart';
import 'package:protocolflow/screens/library_screen.dart';
import 'package:protocolflow/screens/protocol_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final protocol = Protocol(
    id: 'protocol-1',
    title: 'BCA assay',
    objective: 'Measure protein concentration',
    description: '',
    createdByName: 'Aviv Researcher',
    createdAt: DateTime(2026, 7, 23),
    projectId: 'project-1',
    steps: const [],
    isTemplate: true,
  );
  final project = Project(id: 'project-1', name: 'BCA Study');

  testWidgets('library shows protocol creation metadata', (tester) async {
    SharedPreferences.setMockInitialValues({
      'protocols_library_json': jsonEncode([protocol.toJson()]),
      'projects_json': jsonEncode([project.toJson()]),
    });

    await tester.pumpWidget(
      const MaterialApp(home: LibraryScreen(initialTabIndex: 0)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Created on: 2026-07-23'), findsOneWidget);
    expect(find.text('Created by: Aviv Researcher'), findsOneWidget);
    expect(find.text('Project: BCA Study'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library project filter can return to all projects', (
    tester,
  ) async {
    final unassigned = Protocol(
      id: 'protocol-2',
      title: 'Unassigned assay',
      objective: '',
      description: '',
      steps: const [],
    );
    SharedPreferences.setMockInitialValues({
      'protocols_library_json': jsonEncode([
        protocol.copyWith(isTemplate: false).toJson(),
        unassigned.toJson(),
      ]),
      'projects_json': jsonEncode([project.toJson()]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryScreen(initialTabIndex: 1, initialProjectId: 'project-1'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('BCA assay'), findsOneWidget);
    expect(find.text('Unassigned assay'), findsNothing);

    await tester.tap(find.text('BCA Study').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All projects'));
    await tester.pumpAndSettle();

    expect(find.text('BCA assay'), findsOneWidget);
    expect(find.text('Unassigned assay'), findsOneWidget);
  });

  testWidgets('protocol detail shows protocol creation metadata', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([project.toJson()]),
    });

    await tester.pumpWidget(
      MaterialApp(home: ProtocolDetailScreen(protocol: protocol)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Created on: 2026-07-23'), findsOneWidget);
    expect(find.text('Created by: Aviv Researcher'), findsOneWidget);
    expect(find.text('Project: BCA Study'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed detail shows creator and completer metadata', (
    tester,
  ) async {
    final completed = CompletedProtocol(
      id: 'completed-1',
      protocol: protocol,
      notes: const [],
      completedAt: DateTime(2026, 7, 23, 14, 30),
      completedByName: 'Lab Manager',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CompletedProtocolDetailScreen(completedProtocol: completed),
      ),
    );
    await tester.pump();

    expect(find.text('Created on: 2026-07-23'), findsOneWidget);
    expect(find.text('Created by: Aviv Researcher'), findsOneWidget);
    expect(find.text('Completed on: 2026-07-23 14:30'), findsOneWidget);
    expect(find.text('Completed by: Lab Manager'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
