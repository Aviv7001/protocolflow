import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/services/drive_sync_service.dart';
import 'package:protocolflow/services/export_service.dart';
import 'package:protocolflow/services/import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'protocolflow-backup-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => documentsDirectory.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (documentsDirectory.existsSync()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  test('local backup restore replaces data and preserves sign-in', () async {
    SharedPreferences.setMockInitialValues({
      'signed_in_google_user_json': '{"email":"user@example.com"}',
      'stale_value': 'remove me',
    });
    final result = await ImportService().importDecodedData(
      {
        'format': 'protocolflow-local-backup',
        'version': 1,
        'preferences': {
          'projects_json': {
            'type': 'string',
            'value':
                '[{"id":"project-1","name":"Validation","description":"","colorValue":4279598970}]',
          },
          'home_explore_locally_v1': {'type': 'bool', 'value': true},
          'tasks_sync_updated_at': {
            'type': 'string',
            'value': '2026-08-24T00:00:00.000Z',
          },
        },
      },
      confirmRestore: (preview) async {
        expect(preview.target, BackupRestoreTarget.local);
        expect(preview.items, hasLength(3));
        expect(preview.sourceFileName, 'ProtocolFlow backup');
        return true;
      },
    );

    final preferences = await SharedPreferences.getInstance();
    expect(result.success, isTrue);
    expect(result.restoredLocalData, isTrue);
    expect(preferences.getString('stale_value'), isNull);
    expect(
      preferences.getString('signed_in_google_user_json'),
      '{"email":"user@example.com"}',
    );
    expect(preferences.getString('projects_json'), contains('Validation'));
    expect(preferences.getBool('home_explore_locally_v1'), isTrue);
    expect(preferences.getString('tasks_sync_updated_at'), isNotNull);
  });

  test('cancelled local restore leaves current data untouched', () async {
    SharedPreferences.setMockInitialValues({'current': 'keep me'});

    final result = await ImportService().importDecodedData({
      'format': 'protocolflow-local-backup',
      'version': 1,
      'preferences': {
        'home_explore_locally_v1': {'type': 'bool', 'value': true},
      },
    }, confirmRestore: (_) async => false);

    final preferences = await SharedPreferences.getInstance();
    expect(result.success, isFalse);
    expect(preferences.getString('current'), 'keep me');
    expect(preferences.getBool('home_explore_locally_v1'), isNull);
  });

  test('Drive backup envelope round-trips file names and content', () {
    const backup = DriveAppDataBackup(
      files: [
        DriveAppDataBackupFile(name: 'projects.json', content: '{"items":[]}'),
        DriveAppDataBackupFile(name: 'today_tasks.json', content: '[]'),
      ],
    );

    final restored = DriveAppDataBackup.fromJson(backup.toJson());

    expect(restored.files, hasLength(2));
    expect(restored.files.first.name, 'projects.json');
    expect(restored.files.first.content, '{"items":[]}');
  });

  test('local backup filename includes date and sanitized user initials', () {
    expect(
      ExportService.localBackupFileName(
        exportedAt: DateTime(2026, 8, 12),
        userInitials: 'a.v',
      ),
      'protocolflow_local_backup_2026-08-12_exported_AV.json',
    );
    expect(
      ExportService.localBackupFileName(exportedAt: DateTime(2026, 1, 2)),
      'protocolflow_local_backup_2026-01-02_exported_USER.json',
    );
  });
}
