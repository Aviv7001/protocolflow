import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saved table sync health follows local and Drive changes', () async {
    SharedPreferences.setMockInitialValues({
      'saved_tables_sync_state': SavedTablesSyncState.synced.name,
    });
    final service = StorageService();

    await service.upsertSavedTable(
      ProtocolTable(id: 'table-1', title: 'Plate map'),
    );
    expect(
      await service.loadSavedTablesSyncState(),
      SavedTablesSyncState.pending,
    );

    await service.markSavedTablesSynced();
    expect(
      await service.loadSavedTablesSyncState(),
      SavedTablesSyncState.synced,
    );

    await service.markSavedTablesSyncError();
    expect(
      await service.loadSavedTablesSyncState(),
      SavedTablesSyncState.error,
    );
  });
}
