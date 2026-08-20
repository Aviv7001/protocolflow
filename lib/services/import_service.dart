import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/protocol.dart';
import '../models/completed_protocol.dart';
import '../data/completed_protocols_data.dart';
import 'storage_service.dart';
import 'drive_sync_service.dart';
import 'local_backup_media_store.dart';
import 'protocol_run_service.dart';

enum BackupRestoreTarget { local, drive }

class BackupRestorePreviewItem {
  const BackupRestorePreviewItem({
    required this.category,
    required this.title,
    this.detail,
  });

  final String category;
  final String title;
  final String? detail;
}

class BackupRestorePreview {
  const BackupRestorePreview({
    required this.target,
    required this.sourceFileName,
    required this.items,
    this.exportedAt,
    this.exportedByInitials,
  });

  final BackupRestoreTarget target;
  final String sourceFileName;
  final DateTime? exportedAt;
  final String? exportedByInitials;
  final List<BackupRestorePreviewItem> items;
}

typedef ConfirmBackupRestore =
    Future<bool> Function(BackupRestorePreview preview);

class ImportService {
  final StorageService _storageService = StorageService();

  Future<ImportResult> importJson({
    ConfirmBackupRestore? confirmRestore,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null) {
        return ImportResult(success: false, message: 'No file selected');
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        return ImportResult(
          success: false,
          message: 'Could not read selected file',
        );
      }

      final String content = utf8.decode(bytes);
      final dynamic jsonData = jsonDecode(content);

      return importDecodedData(
        jsonData,
        confirmRestore: confirmRestore,
        sourceFileName: file.name,
      );
    } catch (e) {
      if (kDebugMode) print('Import error: $e');
      return ImportResult(success: false, message: 'Error: $e');
    }
  }

  Future<ImportResult> importDecodedData(
    dynamic jsonData, {
    ConfirmBackupRestore? confirmRestore,
    String sourceFileName = 'ProtocolFlow backup',
  }) async {
    try {
      if (jsonData is Map<String, dynamic>) {
        if (jsonData['format'] == 'protocolflow-local-backup') {
          return _restoreLocalBackup(jsonData, confirmRestore, sourceFileName);
        }
        if (jsonData['format'] == 'protocolflow-drive-backup') {
          return _restoreDriveBackup(jsonData, confirmRestore, sourceFileName);
        }
        // Check if it's a full backup
        if (jsonData.containsKey('templates') ||
            jsonData.containsKey('history')) {
          return await _importBackup(jsonData);
        }
        // Check if it's a single completed protocol
        if (jsonData.containsKey('completedAt') &&
            jsonData.containsKey('protocol')) {
          return await _importSingleHistory(jsonData);
        }
        // Check if it's a single template
        if (jsonData.containsKey('id') && jsonData.containsKey('steps')) {
          return await _importSingleTemplate(jsonData);
        }
      } else if (jsonData is List) {
        // Could be a list of templates or history
        if (jsonData.isEmpty) {
          return ImportResult(success: false, message: 'Empty JSON list');
        }

        final first = jsonData.first;
        if (first.containsKey('completedAt')) {
          return await _importHistoryList(jsonData);
        } else {
          return await _importTemplateList(jsonData);
        }
      }

      return ImportResult(success: false, message: 'Unrecognized JSON format');
    } catch (e) {
      if (kDebugMode) print('Import error: $e');
      return ImportResult(success: false, message: 'Error: $e');
    }
  }

  Future<ImportResult> _restoreLocalBackup(
    Map<String, dynamic> data,
    ConfirmBackupRestore? confirmRestore,
    String sourceFileName,
  ) async {
    if (data['version'] != 1 || data['preferences'] is! Map) {
      throw const FormatException('Unsupported ProtocolFlow local backup.');
    }
    final rawPreferences = Map<String, dynamic>.from(
      data['preferences'] as Map,
    );
    final decoded = <String, Object>{};
    for (final entry in rawPreferences.entries) {
      if (entry.key == 'signed_in_google_user_json') continue;
      if (entry.value is! Map) {
        throw const FormatException('Local backup contains invalid settings.');
      }
      decoded[entry.key] = _decodePreference(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    final preview = _localBackupPreview(data, decoded, sourceFileName);
    if (confirmRestore == null || !await confirmRestore(preview)) {
      return ImportResult(success: false, message: 'Local restore cancelled.');
    }

    final restoredPaths = await restoreLocalBackupMedia(data['localFiles']);
    final preferences = await SharedPreferences.getInstance();
    final signedInUser = preferences.getString('signed_in_google_user_json');
    await preferences.clear();
    if (signedInUser != null && signedInUser.isNotEmpty) {
      await preferences.setString('signed_in_google_user_json', signedInUser);
    }
    for (final entry in decoded.entries) {
      await _setPreference(
        preferences,
        entry.key,
        _remapLocalPaths(entry.value, restoredPaths),
      );
    }
    await ProtocolRunService.instance.loadRuns();
    return ImportResult(
      success: true,
      message: 'Local backup restored (${decoded.length} data entries).',
      restoredLocalData: true,
    );
  }

  Future<ImportResult> _restoreDriveBackup(
    Map<String, dynamic> data,
    ConfirmBackupRestore? confirmRestore,
    String sourceFileName,
  ) async {
    final backup = DriveAppDataBackup.fromJson(data);
    final preview = BackupRestorePreview(
      target: BackupRestoreTarget.drive,
      sourceFileName: sourceFileName,
      exportedAt: DateTime.tryParse(data['exportDate']?.toString() ?? ''),
      items: backup.files
          .map(
            (file) => BackupRestorePreviewItem(
              category: 'Drive sync files',
              title: file.name,
              detail: '${utf8.encode(file.content).length} bytes',
            ),
          )
          .toList(),
    );
    if (confirmRestore == null || !await confirmRestore(preview)) {
      return ImportResult(success: false, message: 'Drive restore cancelled.');
    }
    final count = await DriveSyncService.instance.restoreAppDataBackup(backup);
    return ImportResult(
      success: true,
      message: 'Drive backup restored ($count private sync files).',
      restoredDriveData: true,
    );
  }

  BackupRestorePreview _localBackupPreview(
    Map<String, dynamic> data,
    Map<String, Object> preferences,
    String sourceFileName,
  ) {
    final items = preferences.entries
        .map(
          (entry) => BackupRestorePreviewItem(
            category: _localPreferenceCategory(entry.key),
            title: _friendlyPreferenceName(entry.key),
            detail: entry.key,
          ),
        )
        .toList();
    final localFiles = data['localFiles'];
    if (localFiles is List) {
      for (final rawFile in localFiles.whereType<Map>()) {
        final file = Map<String, dynamic>.from(rawFile);
        items.add(
          BackupRestorePreviewItem(
            category: 'Attached media',
            title: file['name']?.toString() ?? 'Media file',
          ),
        );
      }
    }
    return BackupRestorePreview(
      target: BackupRestoreTarget.local,
      sourceFileName: sourceFileName,
      exportedAt: DateTime.tryParse(data['exportDate']?.toString() ?? ''),
      exportedByInitials: data['exportedByInitials']?.toString(),
      items: items,
    );
  }

  String _localPreferenceCategory(String key) {
    final value = key.toLowerCase();
    if (value.contains('table')) return 'Saved tables';
    if (value.contains('task')) return 'Tasks';
    if (value.contains('project')) return 'Projects';
    if (value.contains('measuring') || value.contains('calculator')) {
      return 'Measuring tools';
    }
    if (value.contains('protocol') ||
        value.contains('library') ||
        value.contains('completed') ||
        value.contains('running')) {
      return 'Protocols and history';
    }
    if (value.contains('sync') || value.contains('journal')) {
      return 'Synchronization state';
    }
    return 'App settings';
  }

  String _friendlyPreferenceName(String key) {
    return key
        .replaceAll(RegExp('[_-]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Object _decodePreference(Map<String, dynamic> entry) {
    final value = entry['value'];
    return switch (entry['type']) {
      'string' when value is String => value,
      'bool' when value is bool => value,
      'int' when value is int => value,
      'double' when value is num => value.toDouble(),
      'stringList'
          when value is List && value.every((item) => item is String) =>
        List<String>.from(value),
      _ => throw const FormatException(
        'Local backup contains an unsupported setting.',
      ),
    };
  }

  Object _remapLocalPaths(Object value, Map<String, String> restoredPaths) {
    if (restoredPaths.isEmpty) return value;
    if (value is List<String>) {
      return value.map((item) => _remapString(item, restoredPaths)).toList();
    }
    if (value is String) return _remapString(value, restoredPaths);
    return value;
  }

  String _remapString(String value, Map<String, String> restoredPaths) {
    var updated = value;
    for (final entry in restoredPaths.entries) {
      final encodedOld = jsonEncode(entry.key);
      final encodedNew = jsonEncode(entry.value);
      updated = updated.replaceAll(
        encodedOld.substring(1, encodedOld.length - 1),
        encodedNew.substring(1, encodedNew.length - 1),
      );
      updated = updated.replaceAll(entry.key, entry.value);
    }
    return updated;
  }

  Future<void> _setPreference(
    SharedPreferences preferences,
    String key,
    Object value,
  ) async {
    switch (value) {
      case String value:
        await preferences.setString(key, value);
      case bool value:
        await preferences.setBool(key, value);
      case int value:
        await preferences.setInt(key, value);
      case double value:
        await preferences.setDouble(key, value);
      case List<String> value:
        await preferences.setStringList(key, value);
      default:
        throw const FormatException('Unsupported local backup setting.');
    }
  }

  Future<ImportResult> _importBackup(Map<String, dynamic> data) async {
    int templateCount = 0;
    int historyCount = 0;

    if (data.containsKey('templates')) {
      final List<dynamic> templatesJson = data['templates'];
      final List<Protocol> imported = templatesJson
          .map((j) => Protocol.fromJson(j))
          .toList();
      final existing = await _storageService.loadProtocols();

      for (var p in imported) {
        if (!existing.any((e) => e.id == p.id)) {
          existing.add(p);
          templateCount++;
        }
      }
      await _storageService.saveProtocols(existing);
    }

    if (data.containsKey('history')) {
      final List<dynamic> historyJson = data['history'];
      final List<CompletedProtocol> imported = historyJson
          .map((j) => CompletedProtocol.fromJson(j))
          .toList();

      for (var p in imported) {
        if (!completedProtocols.any((e) => e.id == p.id)) {
          completedProtocols.add(p);
          historyCount++;
        }
      }
      await savePersistentProtocols();
    }

    return ImportResult(
      success: true,
      message:
          'Backup imported: $templateCount templates, $historyCount history records added.',
    );
  }

  Future<ImportResult> _importSingleTemplate(Map<String, dynamic> json) async {
    final protocol = Protocol.fromJson(json);
    final existing = await _storageService.loadProtocols();

    if (existing.any((e) => e.id == protocol.id)) {
      return ImportResult(
        success: false,
        message: 'Protocol with this ID already exists in library.',
      );
    }

    existing.add(protocol);
    await _storageService.saveProtocols(existing);
    return ImportResult(
      success: true,
      message: 'Template "${protocol.title}" imported successfully.',
    );
  }

  Future<ImportResult> _importSingleHistory(Map<String, dynamic> json) async {
    final completed = CompletedProtocol.fromJson(json);

    if (completedProtocols.any((e) => e.id == completed.id)) {
      return ImportResult(
        success: false,
        message: 'This history record already exists.',
      );
    }

    completedProtocols.add(completed);
    await savePersistentProtocols();
    return ImportResult(
      success: true,
      message: 'History record for "${completed.protocol.title}" imported.',
    );
  }

  Future<ImportResult> _importTemplateList(List<dynamic> list) async {
    final List<Protocol> imported = list
        .map((j) => Protocol.fromJson(j))
        .toList();
    final existing = await _storageService.loadProtocols();
    int count = 0;

    for (var p in imported) {
      if (!existing.any((e) => e.id == p.id)) {
        existing.add(p);
        count++;
      }
    }
    await _storageService.saveProtocols(existing);
    return ImportResult(
      success: true,
      message: 'Imported $count new templates.',
    );
  }

  Future<ImportResult> _importHistoryList(List<dynamic> list) async {
    final List<CompletedProtocol> imported = list
        .map((j) => CompletedProtocol.fromJson(j))
        .toList();
    int count = 0;

    for (var p in imported) {
      if (!completedProtocols.any((e) => e.id == p.id)) {
        completedProtocols.add(p);
        count++;
      }
    }
    await savePersistentProtocols();
    return ImportResult(
      success: true,
      message: 'Imported $count new history records.',
    );
  }
}

class ImportResult {
  final bool success;
  final String message;
  final bool restoredLocalData;
  final bool restoredDriveData;

  ImportResult({
    required this.success,
    required this.message,
    this.restoredLocalData = false,
    this.restoredDriveData = false,
  });
}
