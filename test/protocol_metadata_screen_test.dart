import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_publication.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/screens/completed_protocol_detail_screen.dart';
import 'package:protocolflow/screens/library_screen.dart';
import 'package:protocolflow/screens/protocol_detail_screen.dart';
import 'package:protocolflow/widgets/protocolflow_app_bar.dart';
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
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'protocols_library_json': jsonEncode([protocol.toJson()]),
      'projects_json': jsonEncode([project.toJson()]),
    });

    await tester.pumpWidget(
      const MaterialApp(home: LibraryScreen(initialTabIndex: 0)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('TEMPLATE'), findsOneWidget);
    expect(find.text('CREATED ON'), findsOneWidget);
    expect(find.text('2026-07-23'), findsOneWidget);
    expect(find.text('CREATED BY'), findsOneWidget);
    expect(find.text('Aviv Researcher'), findsOneWidget);
    expect(find.text('BCA Study'), findsOneWidget);
    expect(
      find.byKey(const Key('library-tags-placeholder-protocol-1')),
      findsOneWidget,
    );
    final typeBadge = tester.getSize(
      find.byKey(const Key('library-type-badge-protocol-1')),
    );
    final syncBadge = tester.getSize(
      find.byKey(const Key('library-sync-badge-protocol-1')),
    );
    final projectBadge = tester.getSize(
      find.byKey(const Key('library-project-badge-protocol-1')),
    );
    expect(typeBadge.height, syncBadge.height);
    expect(projectBadge.height, syncBadge.height);
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

  testWidgets('library cards identify protocols, running, and completed', (
    tester,
  ) async {
    final ready = protocol.copyWith(
      id: 'ready-1',
      isTemplate: false,
      steps: [
        ProtocolStep(
          id: 'prepare-step',
          title: 'Prepare',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Preparation',
        ),
        ProtocolStep(
          id: 'measure-step',
          title: 'Measure',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Measurement',
        ),
      ],
    );
    final running = ActiveProtocol(
      protocol: ready,
      currentStepIndex: 1,
      notes: const [],
      startedAt: DateTime(2026, 7, 23, 9),
      completedStepIds: const {'prepare-step'},
    );
    final completed = CompletedProtocol(
      id: 'completed-1',
      protocol: ready,
      notes: const [],
      completedAt: DateTime(2026, 7, 24),
      completedByName: 'Lab Manager',
    );
    runningProtocols = [running];
    completedProtocols = [completed];
    activeProtocol = null;
    addTearDown(() {
      runningProtocols = [];
      completedProtocols = [];
      activeProtocol = null;
    });
    SharedPreferences.setMockInitialValues({
      'protocols_library_json': jsonEncode([ready.toJson()]),
      'projects_json': jsonEncode([project.toJson()]),
    });

    await tester.pumpWidget(
      const MaterialApp(home: LibraryScreen(initialTabIndex: 1)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PROTOCOL'), findsOneWidget);
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    expect(find.text('RUNNING'), findsOneWidget);
    expect(
      find.byKey(const Key('running-library-phase-progress-ready-1')),
      findsOneWidget,
    );
    expect(find.text('Preparation'), findsOneWidget);
    expect(find.text('Measurement'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('COMPLETED BY'), findsOneWidget);
    expect(find.text('Lab Manager'), findsOneWidget);
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
    expect(find.byType(ProtocolFlowAppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('published protocol shows badges and attached QR section', (
    tester,
  ) async {
    final published = protocol.copyWith(
      isTemplate: false,
      publication: ProtocolPublication(
        publicationId: 'publication-1',
        driveFileId: 'drive-file-1',
        permissionId: 'permission-1',
        version: 2,
        publishedAt: DateTime(2026, 8, 5),
        shareUri:
            'https://aviv7001.github.io/protocolflow/?import=drive-file-1',
        contentHash: 'hash-1',
        ownerGoogleUserId: 'owner-1',
        authorName: 'Aviv Researcher',
        anonymous: false,
        status: ProtocolPublicationStatus.published,
      ),
    );
    SharedPreferences.setMockInitialValues({
      'protocols_library_json': jsonEncode([published.toJson()]),
    });

    await tester.pumpWidget(
      MaterialApp(home: LibraryScreen(initialTabIndex: 1)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('library-publication-badge-protocol-1')),
      findsOneWidget,
    );

    await tester.tap(find.text('BCA assay'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-publication')), findsOneWidget);
    expect(find.text('PUBLISHED'), findsWidgets);
    expect(find.byKey(const Key('published-protocol-qr')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('protocol detail mirrors builder layout and step timeline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([project.toJson()]),
    });
    final materialTable = createMaterialListTable(id: 'materials');
    final detailProtocol = protocol.copyWith(
      isTemplate: false,
      samples: const ['HEK293 cells'],
      materialListTableId: materialTable.id,
      tables: [
        materialTable,
        ProtocolTable(
          id: 'plate-layout',
          title: 'Plate Layout',
          type: TableType.plateLayout,
        ),
      ],
      additionalData: [
        ProtocolAdditionalData(id: 'reference', title: 'Reference article'),
      ],
      steps: [
        ProtocolStep(
          id: 'step-1',
          title: 'Prepare cells',
          instructions: 'Wash the cells.',
          actionItems: const ['Add buffer'],
          materials: const [],
          tableIds: const ['plate-layout'],
          phaseName: 'Preparation',
        ),
        ProtocolStep(
          id: 'step-2',
          title: 'Read plate',
          instructions: 'Measure absorbance.',
          actionItems: const [],
          materials: const [],
          phaseName: 'Measurement',
        ),
      ],
    );

    Future<void> pumpAtSize(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(home: ProtocolDetailScreen(protocol: detailProtocol)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAtSize(const Size(1400, 1800));

    final information = find.byKey(const Key('detail-protocol-information'));
    final materials = find.byKey(const Key('detail-materials'));
    final steps = find.byKey(const Key('detail-steps'));
    final tables = find.byKey(const Key('detail-tables'));
    final additionalData = find.byKey(const Key('detail-additional-data'));
    final phaseProgress = find.byKey(
      const Key('detail-phase-progress-section'),
    );

    expect(phaseProgress, findsOneWidget);
    expect(find.byKey(const Key('detail-phase-progress-0')), findsOneWidget);
    expect(find.byKey(const Key('detail-phase-progress-1')), findsOneWidget);
    expect(find.byKey(const Key('detail-phase-progress-add')), findsOneWidget);
    expect(
      tester.getTopLeft(phaseProgress).dy,
      lessThan(tester.getTopLeft(information).dy),
    );

    expect(
      tester.getRect(information).right,
      lessThan(tester.getRect(materials).left),
    );
    expect(
      tester.getTopLeft(tables).dy,
      greaterThan(tester.getTopLeft(information).dy),
    );
    expect(
      tester.getTopLeft(steps).dy,
      greaterThan(tester.getTopLeft(materials).dy),
    );
    expect(
      tester.getTopLeft(additionalData).dy,
      greaterThan(tester.getTopLeft(tables).dy),
    );

    for (var number = 1; number <= 2; number++) {
      final marker = find.byKey(Key('detail-step-number-$number'));
      final card = find.byKey(Key('detail-step-card-$number'));
      expect(marker, findsOneWidget);
      expect(card, findsOneWidget);
      expect(tester.getRect(marker).right, lessThan(tester.getRect(card).left));
      expect(find.byKey(Key('detail-step-connector-$number')), findsOneWidget);
    }

    await pumpAtSize(const Size(390, 1800));
    final mobileOrder = [
      information,
      find.byKey(const Key('detail-samples')),
      materials,
      steps,
      tables,
      additionalData,
    ].map((finder) => tester.getTopLeft(finder).dy).toList();
    expect(mobileOrder, orderedEquals([...mobileOrder]..sort()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('running protocol detail shows progress and can add a phase', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([project.toJson()]),
    });
    final runningProtocol = protocol.copyWith(
      id: 'running-detail',
      isTemplate: false,
      steps: [
        ProtocolStep(
          id: 'running-step-1',
          title: 'Prepare',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Preparation',
        ),
        ProtocolStep(
          id: 'running-step-2',
          title: 'Measure',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Measurement',
        ),
      ],
    );
    final runningState = ActiveProtocol(
      protocol: runningProtocol,
      currentStepIndex: 1,
      notes: const [],
      startedAt: DateTime(2026, 7, 23),
      completedStepIds: const {'running-step-1'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProtocolDetailScreen(
          protocol: runningProtocol,
          activeState: runningState,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('detail-phase-progress')), findsOneWidget);
    expect(find.byKey(const Key('detail-phase-progress-add')), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-phase-progress-add')));
    await tester.pumpAndSettle();

    expect(find.text('Protocol Builder'), findsOneWidget);
    expect(find.text('Phase 3'), findsWidgets);
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
    expect(find.byType(ProtocolFlowAppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed detail keeps the published parent QR', (tester) async {
    final published = protocol.copyWith(
      isTemplate: false,
      publication: ProtocolPublication(
        publicationId: 'publication-1',
        driveFileId: 'manifest-file',
        version: 2,
        publishedAt: DateTime.utc(2026, 8, 9),
        shareUri:
            'https://aviv7001.github.io/protocolflow/?import=manifest-file',
        contentHash: 'hash-2',
        ownerGoogleUserId: 'owner-1',
        anonymous: false,
        status: ProtocolPublicationStatus.published,
      ),
    );
    final completed = CompletedProtocol(
      id: 'completed-published',
      protocol: published,
      notes: const [],
      completedAt: DateTime(2026, 8, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CompletedProtocolDetailScreen(completedProtocol: completed),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('completed-detail-publication')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('published-protocol-qr')), findsOneWidget);
    expect(find.text('Version 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed detail mirrors builder layout and timeline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'projects_json': jsonEncode([project.toJson()]),
    });
    final materialTable = createMaterialListTable(id: 'completed-materials');
    final completedProtocol = CompletedProtocol(
      id: 'completed-layout',
      protocol: protocol.copyWith(
        isTemplate: false,
        samples: const ['Primary cells'],
        materialListTableId: materialTable.id,
        tables: [
          materialTable,
          ProtocolTable(
            id: 'completed-plate',
            title: 'Completed Plate',
            type: TableType.plateLayout,
          ),
        ],
        additionalData: [
          ProtocolAdditionalData(
            id: 'completed-reference',
            title: 'Result reference',
          ),
        ],
        steps: [
          ProtocolStep(
            id: 'completed-step-1',
            title: 'Prepare samples',
            instructions: 'Wash samples.',
            actionItems: const ['Add buffer'],
            materials: const [],
            tableIds: const ['completed-plate'],
          ),
          ProtocolStep(
            id: 'completed-step-2',
            title: 'Collect results',
            instructions: 'Read the plate.',
            actionItems: const [],
            materials: const [],
          ),
        ],
      ),
      notes: [
        StepNote(
          id: 'overview-note',
          stepId: 'overview',
          note: 'Run completed successfully.',
          createdAt: DateTime(2026, 7, 23),
        ),
      ],
      completedAt: DateTime(2026, 7, 24, 12),
      completedByName: 'Lab Manager',
    );

    Future<void> pumpAtSize(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: CompletedProtocolDetailScreen(
            completedProtocol: completedProtocol,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAtSize(const Size(1400, 1800));

    final information = find.byKey(
      const Key('completed-detail-protocol-information'),
    );
    final materials = find.byKey(const Key('completed-detail-materials'));
    final steps = find.byKey(const Key('completed-detail-steps'));
    final notes = find.byKey(const Key('completed-detail-general-notes'));
    final tables = find.byKey(const Key('completed-detail-tables'));
    final additionalData = find.byKey(
      const Key('completed-detail-additional-data'),
    );

    expect(
      tester.getRect(information).right,
      lessThan(tester.getRect(materials).left),
    );
    expect(
      tester.getTopLeft(notes).dy,
      greaterThan(tester.getTopLeft(information).dy),
    );
    expect(
      tester.getTopLeft(steps).dy,
      greaterThan(tester.getTopLeft(materials).dy),
    );
    expect(
      tester.getTopLeft(additionalData).dy,
      greaterThan(tester.getTopLeft(tables).dy),
    );
    expect(find.text('COMPLETED'), findsOneWidget);

    for (var number = 1; number <= 2; number++) {
      final marker = find.byKey(Key('completed-detail-step-number-$number'));
      final card = find.byKey(Key('completed-detail-step-card-$number'));
      expect(marker, findsOneWidget);
      expect(card, findsOneWidget);
      expect(tester.getRect(marker).right, lessThan(tester.getRect(card).left));
      expect(
        find.byKey(Key('completed-detail-step-connector-$number')),
        findsOneWidget,
      );
    }

    await pumpAtSize(const Size(390, 1800));
    final mobileOrder = [
      information,
      find.byKey(const Key('completed-detail-samples')),
      materials,
      steps,
      notes,
      tables,
      additionalData,
    ].map((finder) => tester.getTopLeft(finder).dy).toList();
    expect(mobileOrder, orderedEquals([...mobileOrder]..sort()));
    expect(find.text('Project: BCA Study'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
