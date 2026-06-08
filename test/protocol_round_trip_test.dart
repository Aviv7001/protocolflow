import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/material.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/utils/protocol_id.dart';

void main() {
  test('protocol JSON round trip preserves nested step data', () {
    final protocol = Protocol(
      id: 'proto_round_trip',
      title: 'Nested protocol',
      objective: 'Verify save/load',
      description: 'Actions, timers, tables, materials, notes, files',
      materials: [
        MaterialItem(
          id: 'mat_1',
          name: 'PBS',
          quantity: '10 mL',
          catalogNumber: 'PBS-123',
          manufacturer: 'LabCo',
          location: 'Fridge A',
          stockConcentration: '1x',
        ),
      ],
      samples: ['Sample A'],
      files: ['protocol.pdf'],
      steps: [
        ProtocolStep(
          id: 'step_1',
          title: 'Stain cells',
          instructions: 'Keep protected from light.',
          actionItems: ['Add antibody', 'Incubate', 'Wash twice'],
          materials: [
            MaterialItem(id: 'mat_2', name: 'Antibody', quantity: '5 uL'),
          ],
          timerInSeconds: 120,
          day: 2,
          phaseName: 'Staining',
          actionTimers: {1: 1800},
          attachedFiles: ['step-image.png'],
          tableIds: ['table_1'],
        ),
      ],
      tables: [
        ProtocolTable(
          id: 'table_1',
          title: 'Plate layout',
          type: TableType.plateLayout,
          columnHeaders: ['A', 'B'],
          rowHeaders: ['1'],
          data: [
            ['Sample A', 'Control'],
          ],
          cellColors: [
            ['#FFFFFF', '#EEEEEE'],
          ],
          metadata: {'wizard_state': '{"plateSize":"96"}'},
        ),
      ],
      isTemplate: true,
    );

    final jsonString = jsonEncode(protocol.toJson());
    final restored = Protocol.fromJson(jsonDecode(jsonString));

    expect(restored.toJson(), equals(protocol.toJson()));
    expect(
      restored.steps.single.actionItems,
      equals(protocol.steps.single.actionItems),
    );
    expect(
      restored.steps.single.actionTimers,
      equals(protocol.steps.single.actionTimers),
    );
    expect(
      restored.steps.single.tableIds,
      equals(protocol.steps.single.tableIds),
    );
  });

  test('legacy actions key is restored as actionItems', () {
    final restored = ProtocolStep.fromJson({
      'id': 'step_legacy',
      'title': 'Legacy',
      'instructions': 'Imported old JSON',
      'actions': ['Legacy action'],
      'materials': [],
    });

    expect(restored.actionItems, equals(['Legacy action']));
  });

  test('protocol IDs include display name initials and random suffix', () {
    expect(initialsFromDisplayName('Aviv Yehuda'), equals('AY'));
    expect(initialsFromDisplayName('John Smith'), equals('JS'));
    expect(initialsFromDisplayName('Sarah Kim Lee'), equals('SL'));
    expect(initialsFromDisplayName('Madonna'), equals('MA'));
    expect(initialsFromDisplayName(''), equals('XX'));

    final id = generateProtocolId(
      date: DateTime(2026, 6, 6),
      initials: initialsFromDisplayName('Aviv Yehuda'),
    );

    expect(id, matches(RegExp(r'^PT-20260606-AY-[A-Z0-9]{4}$')));
    expect(isProtocolId(id), isTrue);
  });
}
