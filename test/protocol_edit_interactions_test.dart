import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/features/timeline/models/timeline_model.dart';
import 'package:protocolflow/features/timeline/widgets/timeline_preview.dart';
import 'package:protocolflow/screens/create_protocol_screen.dart';
import 'package:protocolflow/screens/generic_viewer_screen.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:protocolflow/widgets/protocol_step_actions_table.dart';
import 'package:protocolflow/widgets/protocol_step_notes_table.dart';
import 'package:protocolflow/widgets/protocol_table_preview.dart';

void main() {
  testWidgets('adding a step to a phase keeps it before the next phase', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final protocol = Protocol(
      id: 'phase-add-regression',
      title: 'Phase add regression',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'phase-one-step',
          title: 'First phase step',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Phase 1',
        ),
        ProtocolStep(
          id: 'phase-two-step',
          title: 'Second phase step',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Phase 2',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: CreateProtocolScreen(initialProtocol: protocol),
      ),
    );
    await tester.pumpAndSettle();

    final addToPhase = find.text('Add Step to Phase');
    expect(addToPhase, findsNWidgets(2));
    await tester.ensureVisible(addToPhase.first);
    await tester.tap(addToPhase.first);
    await tester.pump();

    final insertedStep = find.byKey(const Key('step-card-2'));
    final secondPhase = find.text('Phase 2');
    final originalSecondStep = find.byKey(const Key('step-card-3'));
    expect(
      tester.getTopLeft(insertedStep).dy,
      lessThan(tester.getTopLeft(secondPhase).dy),
    );
    expect(
      tester.getTopLeft(secondPhase).dy,
      lessThan(tester.getTopLeft(originalSecondStep).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('action and note text expose edit callbacks when unlocked', (
    tester,
  ) async {
    (int, String)? editedAction;
    (int, String)? editedNote;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            children: [
              ProtocolStepActionsTable(
                actions: const ['Add buffer'],
                onEdit: (index, value) => editedAction = (index, value),
              ),
              ProtocolStepNotesTable(
                notes: const ['Keep on ice'],
                onEdit: (index, value) => editedNote = (index, value),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add buffer'));
    await tester.tap(find.text('Keep on ice'));

    expect(editedAction, equals((0, 'Add buffer')));
    expect(editedNote, equals((0, 'Keep on ice')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded step details use flat collapsible sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: const Scaffold(
          body: Column(
            children: [
              ProtocolStepActionsTable(actions: ['Add buffer'], embedded: true),
              ProtocolStepNotesTable(notes: ['Keep on ice'], embedded: true),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.text('Add buffer'), findsOneWidget);
    expect(find.text('Keep on ice'), findsOneWidget);

    await tester.tap(find.byTooltip('Shrink actions'));
    await tester.tap(find.byTooltip('Shrink notes'));
    await tester.pump();

    expect(find.text('Add buffer'), findsNothing);
    expect(find.text('Keep on ice'), findsNothing);
    expect(find.byTooltip('Expand actions'), findsOneWidget);
    expect(find.byTooltip('Expand notes'), findsOneWidget);
  });

  testWidgets('protocol builder uses the flat collapsible step editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final protocol = Protocol(
      id: 'flat-step-editor',
      title: 'Flat step editor',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'editable-step',
          title: 'Prepare materials',
          instructions: 'Prepare the culture reagents.',
          actionItems: const ['Add buffer'],
          notes: const ['Keep on ice'],
          materials: const [],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: CreateProtocolScreen(initialProtocol: protocol),
      ),
    );
    await tester.pumpAndSettle();

    final stepCard = find.byKey(const Key('step-card-1'));
    await tester.ensureVisible(stepCard);
    expect(stepCard, findsOneWidget);
    expect(
      find.descendant(of: stepCard, matching: find.byType(Card)),
      findsNothing,
    );
    expect(find.text('Add buffer'), findsOneWidget);
    expect(find.text('Keep on ice'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse step'));
    await tester.pump();
    expect(find.text('Add buffer'), findsNothing);
    expect(find.text('Keep on ice'), findsNothing);

    await tester.tap(find.byTooltip('Expand step'));
    await tester.pump();
    expect(find.text('Add buffer'), findsOneWidget);
    expect(find.text('Keep on ice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked table title area opens the full-screen viewer', (
    tester,
  ) async {
    final table = ProtocolTable(
      id: 'linked-table',
      title: 'Linked Results',
      type: TableType.generic,
      columnHeaders: ['Value'],
      rowHeaders: ['1'],
      data: [
        ['42'],
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: Scaffold(body: ProtocolTablePreview(table: table)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-table-linked-table')));
    await tester.pumpAndSettle();

    expect(find.byType(GenericViewerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked timeline renders its generated figure inline', (
    tester,
  ) async {
    final table = const ExperimentTimeline(
      title: 'Treatment schedule',
      events: [
        TimelineEvent(id: 'dose', name: 'Dose', selectedTimePoints: [0, 2, 4]),
      ],
    ).toProtocolTable(id: 'timeline-table');

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: Scaffold(body: ProtocolTablePreview(table: table)),
      ),
    );
    await tester.pump();

    expect(find.byType(TimelinePreview), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
