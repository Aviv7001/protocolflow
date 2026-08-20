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
          'text': {'type': 'string', 'value': 'value'},
          'enabled': {'type': 'bool', 'value': true},
          'count': {'type': 'int', 'value': 3},
          'ratio': {'type': 'double', 'value': 1.5},
          'labels': {
            'type': 'stringList',
            'value': ['a', 'b'],
          },
        },
      },
      confirmRestore: (preview) async {
        expect(preview.target, BackupRestoreTarget.local);
        expect(preview.items, hasLength(5));
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
    expect(preferences.getString('text'), 'value');
    expect(preferences.getBool('enabled'), isTrue);
    expect(preferences.getInt('count'), 3);
    expect(preferences.getDouble('ratio'), 1.5);
    expect(preferences.getStringList('labels'), ['a', 'b']);
  });

  test('cancelled local restore leaves current data untouched', () async {
    SharedPreferences.setMockInitialValues({'current': 'keep me'});

    final result = await ImportService().importDecodedData({
      'format': 'protocolflow-local-backup',
      'version': 1,
      'preferences': {
        'replacement': {'type': 'string', 'value': 'new'},
      },
    }, confirmRestore: (_) async => false);

    final preferences = await SharedPreferences.getInstance();
    expect(result.success, isFalse);
    expect(preferences.getString('current'), 'keep me');
    expect(preferences.getString('replacement'), isNull);
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
