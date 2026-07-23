import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/screens/run_protocol_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('files action shows unlinked protocol tables', (tester) async {
    SharedPreferences.setMockInitialValues({});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];

    final linkedTable = ProtocolTable(
      id: 'linked-table',
      title: 'Step Dilution Table',
      columnHeaders: const ['Sample', 'Dilution'],
      rowHeaders: const ['1'],
      data: const [
        ['A1', '1:10'],
      ],
    );
    final unlinkedTable = ProtocolTable(
      id: 'unlinked-table',
      title: 'Reference Plate Map',
      columnHeaders: const ['Well', 'Sample'],
      rowHeaders: const ['1'],
      data: const [
        ['A1', 'Control'],
      ],
    );
    final materialList = createMaterialListTable(
      id: 'materials',
      data: const [
        ['PBS', '10 mL', '', '', ''],
      ],
    );
    final protocol = Protocol(
      id: 'protocol-1',
      title: 'Reference table protocol',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'step-1',
          title: 'Prepare samples',
          instructions: 'Prepare samples.',
          actionItems: [],
          materials: [],
          tableIds: ['linked-table'],
        ),
      ],
      materialListTableId: 'materials',
      tables: [linkedTable, unlinkedTable, materialList],
      additionalData: [
        ProtocolAdditionalData(
          id: 'data-1',
          title: 'Antibody Datasheet',
          description: 'Vendor instructions.',
          link: 'https://example.com/datasheet',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunProtocolScreen(protocol: protocol, initialStepIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Files'));
    await tester.pumpAndSettle();

    final sheet = find.byType(DraggableScrollableSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Reference Tables')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Additional Data')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Reference Plate Map')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Control')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Antibody Datasheet')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Step Dilution Table')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Material List')),
      findsNothing,
    );
  });
}
