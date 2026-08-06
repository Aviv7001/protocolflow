import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/services/drive_sync_service.dart';
import 'package:protocolflow/services/sync_journal.dart';

void main() {
  test('rejects a cloud protocol whose payload ID does not match its key', () {
    const record = SyncEntityRecord(
      entityType: 'protocol',
      entityId: 'cloud-key',
      clock: 4,
      deviceId: 'other-device',
      data: {'id': 'different-id', 'title': 'Hidden protocol'},
    );

    final error = DriveSyncService.instance.recordValidationErrorForTesting(
      record,
    );

    expect(error, contains('mismatched ID'));
  });

  test('accepts a valid cloud protocol', () {
    const record = SyncEntityRecord(
      entityType: 'protocol',
      entityId: 'protocol-1',
      clock: 4,
      deviceId: 'other-device',
      data: {'id': 'protocol-1', 'title': 'Visible protocol'},
    );

    expect(
      DriveSyncService.instance.recordValidationErrorForTesting(record),
      isNull,
    );
  });
}
