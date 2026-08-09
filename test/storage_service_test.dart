import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_publication.dart';
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

  test('deleting a publication clears every attached protocol link', () async {
    SharedPreferences.setMockInitialValues({});
    final service = StorageService();
    final publication = ProtocolPublication(
      publicationId: 'publication-1',
      driveFileId: 'manifest-1',
      version: 1,
      publishedAt: DateTime.utc(2026, 8, 9),
      shareUri: 'https://aviv7001.github.io/protocolflow/?import=manifest-1',
      contentHash: 'hash',
      ownerGoogleUserId: 'owner-1',
      anonymous: false,
      status: ProtocolPublicationStatus.published,
    );
    final published = Protocol(
      id: 'protocol-1',
      title: 'Published protocol',
      objective: '',
      description: '',
      steps: const [],
      publication: publication,
    );
    final unrelated = Protocol(
      id: 'protocol-2',
      title: 'Unrelated protocol',
      objective: '',
      description: '',
      steps: const [],
      publication: ProtocolPublication(
        publicationId: 'publication-2',
        driveFileId: 'manifest-2',
        version: 1,
        publishedAt: DateTime.utc(2026, 8, 9),
        shareUri: 'https://aviv7001.github.io/protocolflow/?import=manifest-2',
        contentHash: 'other-hash',
        ownerGoogleUserId: 'owner-1',
        anonymous: false,
        status: ProtocolPublicationStatus.published,
      ),
    );
    await service.saveProtocols([published, unrelated]);
    await service.saveActiveProtocol(
      ActiveProtocol(
        protocol: published,
        notes: const [],
        startedAt: DateTime.utc(2026, 8, 9),
      ),
    );
    await service.saveRunningProtocols([
      ActiveProtocol(
        protocol: published,
        notes: const [],
        startedAt: DateTime.utc(2026, 8, 8),
      ),
      ActiveProtocol(
        protocol: unrelated,
        notes: const [],
        startedAt: DateTime.utc(2026, 8, 8),
      ),
    ]);
    await service.saveCompletedProtocols([
      CompletedProtocol(
        id: 'completed-1',
        protocol: published,
        notes: const [],
        completedAt: DateTime.utc(2026, 8, 9),
      ),
      CompletedProtocol(
        id: 'completed-2',
        protocol: unrelated,
        notes: const [],
        completedAt: DateTime.utc(2026, 8, 9),
      ),
    ]);

    await service.clearPublicationReferences('publication-1');

    final protocols = await service.loadProtocols();
    expect(protocols.first.publication, isNull);
    expect(protocols.first.syncStatus, ProtocolSyncStatus.modified);
    expect(protocols.last.publication?.publicationId, 'publication-2');
    expect((await service.loadActiveProtocol())?.protocol.publication, isNull);
    final running = await service.loadRunningProtocols();
    expect(running.first.protocol.publication, isNull);
    expect(running.first.protocol.syncStatus, ProtocolSyncStatus.modified);
    expect(running.last.protocol.publication?.publicationId, 'publication-2');
    final completed = await service.loadCompletedProtocols();
    expect(completed.first.protocol.publication, isNull);
    expect(completed.first.syncStatus, ProtocolSyncStatus.modified);
    expect(completed.last.protocol.publication?.publicationId, 'publication-2');
    expect(
      await service.loadSyncBundleState(SyncBundleType.completedProtocols),
      SyncBundleState.pending,
    );
  });
}
