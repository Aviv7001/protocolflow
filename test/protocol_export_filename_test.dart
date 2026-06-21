import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/services/protocol_export_filename.dart';

void main() {
  final protocol = Protocol(
    id: 'PT-20260621-AY-K7Q2',
    title: 'Cell Staining',
    objective: '',
    description: '',
    steps: const [],
  );

  test('builds a consistent protocol export filename', () {
    expect(
      ProtocolExportFilename.protocol(protocol, '.json'),
      'ProtocolFlow_Cell_Staining_PT-20260621-AY-K7Q2_protocol.json',
    );
  });

  test('completed export filename includes the completion time', () {
    expect(
      ProtocolExportFilename.completed(
        protocol,
        DateTime(2026, 6, 21, 15, 40),
        'docx',
      ),
      'ProtocolFlow_Cell_Staining_PT-20260621-AY-K7Q2_completed_20260621-1540.docx',
    );
  });

  test('replaces unsafe filename characters', () {
    final unsafe = protocol.copyWith(title: 'Cell: Staining / Run*');

    expect(
      ProtocolExportFilename.protocol(unsafe, 'pdf'),
      'ProtocolFlow_Cell_Staining_Run_PT-20260621-AY-K7Q2_protocol.pdf',
    );
  });
}
