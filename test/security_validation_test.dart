import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/measuring_tools/models/measuring_tool.dart';
import 'package:protocolflow/features/measuring_tools/services/measuring_tool_service.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/services/drive_sync_service.dart';
import 'package:protocolflow/services/import_service.dart';
import 'package:protocolflow/services/storage_service.dart';
import 'package:protocolflow/services/sync_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('direct protocol save rejects missing required title', () async {
    SharedPreferences.setMockInitialValues({});

    await expectLater(
      StorageService().upsertProtocol(
        Protocol(
          id: 'protocol-1',
          title: '',
          objective: '',
          description: '',
          steps: const [],
        ),
      ),
      throwsFormatException,
    );

    expect(await StorageService().loadProtocols(), isEmpty);
  });

  test('direct saved-table write rejects malformed table shape', () async {
    SharedPreferences.setMockInitialValues({});

    await expectLater(
      StorageService().saveSavedTables([
        ProtocolTable(
          id: 'table-1',
          title: 'Bad table',
          columnHeaders: ['A'],
          data: [
            ['one', 'extra'],
          ],
        ),
      ]),
      throwsFormatException,
    );

    expect(await StorageService().loadSavedTables(), isEmpty);
  });

  test(
    'legacy protocol import rejects invalid payload before persistence',
    () async {
      SharedPreferences.setMockInitialValues({});

      final result = await ImportService().importDecodedData({
        'id': 'protocol-1',
        'title': '',
        'steps': const [],
      });

      expect(result.success, isFalse);
      expect(result.message, contains('Protocol title is required'));
      expect(await StorageService().loadProtocols(), isEmpty);
    },
  );

  test('local backup restore rejects unsupported preference keys', () async {
    SharedPreferences.setMockInitialValues({'current': 'keep'});

    final result = await ImportService().importDecodedData({
      'format': 'protocolflow-local-backup',
      'version': 1,
      'preferences': {
        'untrusted_key': {'type': 'string', 'value': 'payload'},
      },
    }, confirmRestore: (_) async => true);

    final preferences = await SharedPreferences.getInstance();
    expect(result.success, isFalse);
    expect(result.message, contains('unsupported setting'));
    expect(preferences.getString('current'), 'keep');
    expect(preferences.getString('untrusted_key'), isNull);
  });

  test(
    'Drive backup restore validates file contents before authorization',
    () async {
      await expectLater(
        DriveSyncService.instance.restoreAppDataBackup(
          const DriveAppDataBackup(
            files: [
              DriveAppDataBackupFile(
                name: 'projects.json',
                content: '[{"id":"project-1","name":""}]',
              ),
            ],
          ),
          promptIfNecessary: false,
        ),
        throwsFormatException,
      );
    },
  );

  test('Drive sync record validation rejects empty task titles', () {
    const record = SyncEntityRecord(
      entityType: 'todayTask',
      entityId: 'task-1',
      clock: 1,
      deviceId: 'device-2',
      data: {
        'id': 'task-1',
        'title': '',
        'description': '',
        'createdAt': '2026-08-24T00:00:00.000',
      },
    );

    expect(
      DriveSyncService.instance.recordValidationErrorForTesting(record),
      contains('damaged or uses invalid data'),
    );
  });

  test('measuring tool sync replacement rejects invalid ranges', () async {
    SharedPreferences.setMockInitialValues({});

    await expectLater(
      MeasuringToolService.instance.replaceFromSyncPayload({
        'updatedAt': '2026-08-24T00:00:00.000',
        'tools': [
          const MeasuringTool(
            id: 'tool-1',
            toolType: 'Micropipette',
            toolName: 'Bad pipette',
            minVolumeUl: 100,
            maxVolumeUl: 10,
            incrementUl: 1,
            accuracyRank: 3,
          ).toJson(),
        ],
      }),
      throwsFormatException,
    );
  });
}
