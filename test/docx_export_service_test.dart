import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/material.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/services/docx_export_service.dart';

void main() {
  test(
    'DOCX export contains protocol content, links, tables, and photos',
    () async {
      const pixelPng =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      final protocol = Protocol(
        id: 'docx-test',
        title: 'DOCX Test Protocol',
        objective: 'Verify editable Word export.',
        description: 'A representative protocol document.',
        materials: [MaterialItem(id: 'm1', name: 'PBS', quantity: '10 mL')],
        samples: const ['Sample A'],
        steps: [
          ProtocolStep(
            id: 's1',
            title: 'Prepare sample',
            instructions: 'Keep the tube on ice.',
            actionItems: const ['Add PBS', 'Incubate'],
            materials: const [],
            actionTimers: const {1: 300},
            tableIds: const ['t1'],
          ),
        ],
        tables: [
          ProtocolTable(
            id: 't1',
            title: 'Sample table',
            columnHeaders: const ['Sample', 'Volume'],
            data: const [
              ['A', '100 uL'],
            ],
          ),
        ],
        additionalData: [
          ProtocolAdditionalData(
            id: 'd1',
            title: 'Reference',
            description: 'Supporting data.',
            link: 'https://example.com/reference',
            photoPaths: const [pixelPng],
          ),
        ],
      );
      final notes = [
        StepNote(
          id: 'n1',
          stepId: 's1',
          note: 'Observed expected staining.',
          photoPaths: const [pixelPng],
          createdAt: DateTime(2026, 6, 20),
        ),
      ];

      final bytes = await const DocxExportService().buildDocument(
        protocol,
        notes: notes,
        completedAt: DateTime(2026, 6, 20, 12, 30),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((file) => file.name).toSet();

      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('word/document.xml'));
      expect(names, contains('word/styles.xml'));
      expect(names, contains('word/numbering.xml'));
      expect(names, contains('word/media/image1.png'));

      final document = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      final relationships = utf8.decode(
        archive.findFile('word/_rels/document.xml.rels')!.content as List<int>,
      );
      expect(document, contains('DOCX Test Protocol'));
      expect(document, contains('Observed expected staining.'));
      expect(document, contains('Sample table'));
      expect(document, contains('rIdImage1'));
      expect(relationships, contains('https://example.com/reference'));
    },
  );
}
