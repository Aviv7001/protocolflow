import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/material.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/protocol_publication.dart';
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
        publication: ProtocolPublication(
          publicationId: 'publication-1',
          driveFileId: 'drive-file-1',
          version: 1,
          publishedAt: DateTime(2026, 6, 20),
          shareUri: 'https://example.com/shared-protocol',
          contentHash: 'hash',
          ownerGoogleUserId: 'owner-1',
          anonymous: false,
          status: ProtocolPublicationStatus.published,
        ),
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
            notes: const ['Keep chilled'],
            phaseName: 'Phase 1',
            tableIds: const ['t1'],
          ),
          ProtocolStep(
            id: 's2',
            title: 'Incubate sample',
            instructions: 'Incubate at room temperature.',
            actionItems: const ['Start incubation'],
            materials: const [],
            phaseName: 'Phase 1',
          ),
          ProtocolStep(
            id: 's3',
            title: 'Wash sample',
            instructions: 'Wash twice with buffer.',
            actionItems: const ['Add wash buffer'],
            materials: const [],
            phaseName: 'Phase 1',
          ),
          ...List.generate(
            12,
            (index) => ProtocolStep(
              id: 'long-${index + 1}',
              title: 'Extended phase step ${index + 1}',
              instructions:
                  'Perform this extended operation carefully and document '
                  'every observation before proceeding to the next action.',
              actionItems: const [
                'Prepare the required solution and verify its concentration',
                'Record the result in the protocol before continuing',
              ],
              materials: const [],
              notes: const ['Keep the sample protected from light.'],
              phaseName: 'Phase 2',
            ),
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
      expect(names, contains('word/media/image2.png'));
      expect(names, contains('word/footer1.xml'));

      final document = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      final relationships = utf8.decode(
        archive.findFile('word/_rels/document.xml.rels')!.content as List<int>,
      );
      final numbering = utf8.decode(
        archive.findFile('word/numbering.xml')!.content as List<int>,
      );
      final footer = utf8.decode(
        archive.findFile('word/footer1.xml')!.content as List<int>,
      );
      expect(document, contains('DOCX Test Protocol'));
      expect(document, contains('Observed expected staining.'));
      expect(document, contains('Sample table'));
      expect(document, contains('rIdImage1'));
      expect(document, contains('<w:cols w:num="1" w:space="0"/>'));
      expect(document, isNot(contains('<w:cols w:num="2"')));
      expect(document, contains('<w:br w:type="page"/>'));
      expect(document, contains('w:fill="D7F0F3"'));
      expect(document, contains('<w:numId w:val="100"/>'));
      expect(document, contains('Tables: Sample table'));
      expect(RegExp('Phase 1').allMatches(document), hasLength(1));
      expect(document, isNot(contains('Phase 1 (continued)')));
      expect(document, contains('Phase 2 (continued)'));
      expect(document, contains('<w:t xml:space="preserve">Notes</w:t>'));
      expect(numbering, contains('<w:startOverride w:val="1"/>'));
      expect(
        numbering.indexOf('<w:abstractNum w:abstractNumId="1"'),
        lessThan(numbering.indexOf('<w:num w:numId="1"')),
      );
      expect(footer, contains('<w:t xml:space="preserve">Page </w:t>'));
      expect(relationships, contains('rIdFooter'));
      expect(relationships, contains('https://example.com/reference'));
    },
  );
}
