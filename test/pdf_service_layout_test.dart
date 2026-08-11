import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_publication.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/services/pdf_service.dart';

void main() {
  test('builds one-column content with a full-width table appendix', () async {
    final materialTable = ProtocolTable(
      id: 'materials',
      title: 'Material List',
      type: TableType.materialList,
      columnHeaders: const [
        'Material name',
        'Quantity',
        'Stock concentration',
        'Catalog number',
        'Manufacturer',
      ],
      rowHeaders: List.generate(18, (index) => '${index + 1}'),
      data: List.generate(
        18,
        (index) => [
          'Primary antibody with descriptive name ${index + 1}',
          '${index + 1} mL',
          '${index + 1} mg/mL',
          'CAT-${1000 + index}',
          'ProtocolFlow Laboratories',
        ],
      ),
    );
    final resultsTable = ProtocolTable(
      id: 'results',
      title: 'Measurement Results',
      columnHeaders: const ['Sample', 'Reading', 'Unit'],
      data: const [
        ['Control', '1.24', 'AU'],
        ['Treatment', '2.68', 'AU'],
      ],
    );
    final protocol = Protocol(
      id: 'pdf-layout-test',
      title: 'Two-column PDF layout verification',
      objective: 'Verify readable tables and ordered narrow-layout columns.',
      description:
          'This fixture deliberately contains enough content to span columns '
          'and pages while keeping each protocol step intact.',
      createdByName: 'ProtocolFlow Test',
      createdAt: DateTime(2026, 8, 9),
      materialListTableId: materialTable.id,
      publication: ProtocolPublication(
        publicationId: 'publication-1',
        driveFileId: 'drive-file-1',
        version: 1,
        publishedAt: DateTime(2026, 8, 9),
        shareUri: 'https://aviv7001.github.io/protocolflow/?import=preview',
        contentHash: 'preview-hash',
        ownerGoogleUserId: 'owner-1',
        anonymous: false,
        status: ProtocolPublicationStatus.published,
      ),
      samples: const ['Control sample', 'Treatment sample', 'Blank sample'],
      tables: [materialTable, resultsTable],
      steps: List.generate(
        12,
        (index) => ProtocolStep(
          id: 'step-${index + 1}',
          title: 'Verification step ${index + 1}',
          instructions:
              'Prepare the sample carefully, record every observation, and '
              'confirm the measured value before continuing to the next step. '
              'Keep all labels visible and preserve the original sample order.',
          actionItems: const [
            'Mix gently without introducing bubbles',
            'Record the measured value in the protocol',
          ],
          materials: const [],
          timerInSeconds: 300,
          day: index < 6 ? 1 : 2,
          tableIds: index == 0 ? [resultsTable.id] : const [],
        ),
      ),
    );

    final bytes = await PdfService.buildProtocolPdf(
      protocol,
      theme: pw.ThemeData(),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
