import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
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
}
