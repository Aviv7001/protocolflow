import 'dart:convert';
import '../models/protocol.dart';
import '../models/completed_protocol.dart';
import 'storage_service.dart';
import 'json_file_saver.dart';
import 'protocol_export_filename.dart';
import 'dashboard_activity_service.dart';
import 'drive_sync_service.dart';
import 'local_backup_media_store.dart';
import 'protocol_run_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExportService {
  static const _localBackupFormat = 'protocolflow-local-backup';
  static const _signedInUserKey = 'signed_in_google_user_json';

  final StorageService _storageService = StorageService();
  final DashboardActivityService _activityService = DashboardActivityService();

  Future<void> exportTemplates() async {
    final protocols = await _storageService.loadProtocols();
    final templates = protocols.where((p) => p.isTemplate).toList();
    final jsonString = jsonEncode(templates.map((p) => p.toJson()).toList());
    await _saveFile(jsonString, 'protocol_templates.json');
    await _activityService.recordExport(
      'Protocol templates',
      'ProtocolFlow file',
    );
  }

  Future<void> exportHistory() async {
    final completed = (await ProtocolRunService.instance.getCompletedRuns())
        .map((run) => run.toCompletedProtocol())
        .toList();
    final jsonString = jsonEncode(completed.map((p) => p.toJson()).toList());
    await _saveFile(jsonString, 'completed_protocols.json');
    await _activityService.recordExport(
      'Completed protocols',
      'ProtocolFlow file',
    );
  }

  Future<void> exportSingleCompletedProtocol(
    CompletedProtocol completed,
  ) async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(completed.toJson());
    await _saveFile(
      jsonString,
      ProtocolExportFilename.completed(
        completed.protocol,
        completed.completedAt,
        'json',
      ),
    );
    await _activityService.recordExport(
      completed.protocol.title,
      'ProtocolFlow file',
    );
  }

  Future<void> exportSingleTemplate(Protocol protocol) async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(protocol.toJson());
    await _saveFile(
      jsonString,
      ProtocolExportFilename.protocol(protocol, 'json'),
    );
    await _activityService.recordExport(protocol.title, 'ProtocolFlow file');
  }

  Future<void> exportAllData({String? userInitials}) async {
    await exportLocalData(userInitials: userInitials);
  }

  Future<void> exportLocalData({String? userInitials}) async {
    final exportedAt = DateTime.now();
    final initials = _safeInitials(userInitials);
    final preferences = await SharedPreferences.getInstance();
    final entries = <String, dynamic>{};
    for (final key in preferences.getKeys()) {
      if (key == _signedInUserKey) continue;
      entries[key] = _encodePreference(preferences.get(key));
    }
    final localFiles = await captureLocalBackupMedia(
      preferences
          .getKeys()
          .where((key) => key != _signedInUserKey)
          .map(preferences.get),
    );
    final allData = {
      'format': _localBackupFormat,
      'version': 1,
      'exportDate': exportedAt.toIso8601String(),
      'exportedByInitials': initials,
      'preferences': entries,
      'localFiles': localFiles,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(allData);
    final fileName = localBackupFileName(
      exportedAt: exportedAt,
      userInitials: initials,
    );
    await _saveFile(jsonString, fileName);
    await _activityService.recordExport(
      'ProtocolFlow local backup',
      'ProtocolFlow file',
    );
  }

  Future<void> exportDriveData() async {
    final backup = await DriveSyncService.instance.createAppDataBackup();
    final jsonString = const JsonEncoder.withIndent(
      ' ',
    ).convert(backup.toJson());
    await _saveFile(jsonString, 'protocolflow_drive_backup.json');
    await _activityService.recordExport(
      'ProtocolFlow Drive backup',
      'ProtocolFlow file',
    );
  }

  Map<String, dynamic> _encodePreference(Object? value) {
    return switch (value) {
      String value => {'type': 'string', 'value': value},
      bool value => {'type': 'bool', 'value': value},
      int value => {'type': 'int', 'value': value},
      double value => {'type': 'double', 'value': value},
      List<String> value => {'type': 'stringList', 'value': value},
      _ => throw StateError('Unsupported local preference value.'),
    };
  }

  String _safeInitials(String? value) {
    final safe = (value ?? '').toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    return safe.isEmpty ? 'USER' : safe;
  }

  static String localBackupFileName({
    required DateTime exportedAt,
    String? userInitials,
  }) {
    final initials = (userInitials ?? '').toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    final date =
        '${exportedAt.year}-${twoDigits(exportedAt.month)}-${twoDigits(exportedAt.day)}';
    return 'protocolflow_local_backup_${date}_exported_${initials.isEmpty ? 'USER' : initials}.json';
  }

  Future<void> _saveFile(String content, String fileName) async {
    await saveJsonFile(content, fileName);
  }
}
