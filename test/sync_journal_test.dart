import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/services/sync_journal.dart';
import 'package:protocolflow/services/sync_journal_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SyncEntityRecord record({
    required String type,
    required String id,
    required int clock,
    required String device,
    bool deleted = false,
    String? value,
  }) {
    return SyncEntityRecord(
      entityType: type,
      entityId: id,
      clock: clock,
      deviceId: device,
      deleted: deleted,
      data: deleted ? null : {'id': id, 'value': value},
    );
  }

  test('unrelated concurrent device edits are both retained', () {
    final project = record(
      type: 'project',
      id: 'project-a',
      clock: 4,
      device: 'device-a',
      value: 'renamed',
    );
    final task = record(
      type: 'todayTask',
      id: 'task-b',
      clock: 4,
      device: 'device-b',
      value: 'new task',
    );

    final result = mergeSyncJournals([
      SyncJournal(deviceId: 'device-a', entries: {project.key: project}),
      SyncJournal(deviceId: 'device-b', entries: {task.key: task}),
    ]);

    expect(result.winners.keys, containsAll([project.key, task.key]));
    expect(result.conflicts, isEmpty);
  });

  test('same-record concurrent edits are reported as a conflict', () {
    final fromA = record(
      type: 'protocol',
      id: 'p1',
      clock: 8,
      device: 'device-a',
      value: 'A',
    );
    final fromB = record(
      type: 'protocol',
      id: 'p1',
      clock: 8,
      device: 'device-b',
      value: 'B',
    );

    final result = mergeSyncJournals([
      SyncJournal(deviceId: 'device-a', entries: {fromA.key: fromA}),
      SyncJournal(deviceId: 'device-b', entries: {fromB.key: fromB}),
    ]);

    expect(result.winners[fromA.key]?.deviceId, 'device-b');
    expect(result.conflicts, hasLength(1));
    expect(result.conflicts.single.loser.deviceId, 'device-a');
  });

  test('newer tombstone prevents stale data from being restored', () {
    final stale = record(
      type: 'savedTable',
      id: 'table-1',
      clock: 2,
      device: 'device-b',
      value: 'stale',
    );
    final deletion = record(
      type: 'savedTable',
      id: 'table-1',
      clock: 6,
      device: 'device-a',
      deleted: true,
    );

    final result = mergeSyncJournals([
      SyncJournal(deviceId: 'device-b', entries: {stale.key: stale}),
      SyncJournal(deviceId: 'device-a', entries: {deletion.key: deletion}),
    ]);

    expect(result.winners[stale.key]?.deleted, isTrue);
    expect(result.conflicts, isEmpty);
  });

  test('explicit restore revision overrides a deletion tombstone', () {
    final deletion = record(
      type: 'protocol',
      id: 'p1',
      clock: 6,
      device: 'device-a',
      deleted: true,
    );
    final restore = record(
      type: 'protocol',
      id: 'p1',
      clock: 7,
      device: 'device-b',
      value: 'restored',
    );

    final result = mergeSyncJournals([
      SyncJournal(deviceId: 'device-a', entries: {deletion.key: deletion}),
      SyncJournal(deviceId: 'device-b', entries: {restore.key: restore}),
    ]);

    expect(result.winners[deletion.key]?.deleted, isFalse);
    expect(result.winners[deletion.key]?.data?['value'], 'restored');
  });

  test('journal rejects an unrelated JSON bundle', () {
    expect(
      () => SyncJournal.fromJson({
        'updatedAt': '2026-08-01T00:00:00Z',
        'today': <dynamic>[],
      }),
      throwsFormatException,
    );
  });

  test('journal and baseline survive local persistence round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SyncJournalStore();
    final deviceId = await store.loadOrCreateDeviceId();
    final item = record(
      type: 'measuringTool',
      id: 'tool-1',
      clock: 3,
      device: deviceId,
      value: 'P20',
    );
    final journal = SyncJournal(deviceId: deviceId, entries: {item.key: item});

    await store.saveLocalJournal(journal);
    await store.saveBaseline(journal.entries);

    expect(
      (await store.loadLocalJournal(deviceId)).entries[item.key]?.clock,
      3,
    );
    expect((await store.loadBaseline())[item.key]?.data?['value'], 'P20');
  });

  test('damaged baseline is rejected instead of becoming empty data', () async {
    SharedPreferences.setMockInitialValues({
      'drive_sync_baseline_v2': jsonEncode({'not': 'a list'}),
    });

    expect(SyncJournalStore().loadBaseline(), throwsFormatException);
  });
}
