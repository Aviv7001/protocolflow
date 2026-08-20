import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/services/app_data_reset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'protocolflow-reset-test-',
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

  test('local reset clears app data and preserves signed-in account', () async {
    SharedPreferences.setMockInitialValues({
      'signed_in_google_user_json': '{"email":"user@example.com"}',
      'protocols_library_json': '[{"id":"protocol-1"}]',
      'today_tasks_json': '[{"id":"task-1"}]',
      'drive_sync_local_journal_v2': '{"entries":[]}',
    });

    await AppDataResetService().reset(AppDataResetTarget.local);
    final prefs = await SharedPreferences.getInstance();

    expect(
      prefs.getString('signed_in_google_user_json'),
      '{"email":"user@example.com"}',
    );
    expect(prefs.getString('protocols_library_json'), isNull);
    expect(prefs.getString('today_tasks_json'), isNull);
    expect(prefs.getString('drive_sync_local_journal_v2'), isNull);
  });
}
