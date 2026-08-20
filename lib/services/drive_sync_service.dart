import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/completed_protocol.dart';
import '../models/active_protocol.dart';
import '../models/deleted_protocol_record.dart';
import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../models/task.dart';
import '../features/measuring_tools/models/measuring_tool.dart';
import '../features/today_tasks/services/task_service.dart';
import '../features/measuring_tools/services/measuring_tool_service.dart';
import '../utils/protocol_id.dart';
import 'auth_service.dart';
import 'storage_service.dart';
import 'protocol_run_service.dart';
import 'sync_journal.dart';
import 'sync_journal_store.dart';

class DriveSyncSummary {
  final int downloaded;
  final int uploaded;
  final int conflicts;
  final int errors;
  final String? details;
  final bool previewExpired;

  const DriveSyncSummary({
    this.downloaded = 0,
    this.uploaded = 0,
    this.conflicts = 0,
    this.errors = 0,
    this.details,
    this.previewExpired = false,
  });

  String get message {
    if (errors > 0) {
      return details == null
          ? 'Sync finished with $errors error(s).'
          : 'Sync error: $details';
    }
    if (conflicts > 0) return 'Sync complete with $conflicts conflict copy.';
    return 'Sync complete: $downloaded downloaded, $uploaded uploaded.';
  }
}

enum DriveSyncActionType { upload, download, delete, conflict, invalid }

enum DriveDeletionDecision { deleteEverywhere, keepEverywhere }

class DriveSyncPreviewItem {
  final String key;
  final String category;
  final String title;
  final DriveSyncActionType action;
  final String? deviceId;
  final bool canKeep;
  final String? note;

  const DriveSyncPreviewItem({
    required this.key,
    required this.category,
    required this.title,
    required this.action,
    this.deviceId,
    this.canKeep = false,
    this.note,
  });
}

class DriveSyncPreview {
  final List<DriveSyncPreviewItem> items;
  final String? error;
  final _PreparedSyncPlan? _plan;
  final bool _allowApplyWithoutPlan;

  const DriveSyncPreview._({
    this.items = const [],
    this.error,
    _PreparedSyncPlan? plan,
    bool allowApplyWithoutPlan = false,
  }) : _plan = plan,
       _allowApplyWithoutPlan = allowApplyWithoutPlan;

  @visibleForTesting
  const DriveSyncPreview.test({this.items = const [], this.error})
    : _plan = null,
      _allowApplyWithoutPlan = true;

  bool get canApply =>
      error == null && (_plan != null || _allowApplyWithoutPlan);
  bool get hasChanges => items.isNotEmpty;

  int count(DriveSyncActionType action) =>
      items.where((item) => item.action == action).length;
}

class DriveFileRecord {
  final String id;
  final String name;
  final DateTime? modifiedTime;
  final String? md5Checksum;
  final int? sizeBytes;

  const DriveFileRecord({
    required this.id,
    required this.name,
    this.modifiedTime,
    this.md5Checksum,
    this.sizeBytes,
  });

  factory DriveFileRecord.fromJson(Map<String, dynamic> json) {
    return DriveFileRecord(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      modifiedTime: DateTime.tryParse(json['modifiedTime']?.toString() ?? ''),
      md5Checksum: json['md5Checksum']?.toString(),
      sizeBytes: int.tryParse(json['size']?.toString() ?? ''),
    );
  }
}

class DriveAppDataFootprint {
  const DriveAppDataFootprint({
    required this.bytesByCategory,
    required this.fileCount,
  });

  final Map<String, int> bytesByCategory;
  final int fileCount;

  int get totalBytes =>
      bytesByCategory.values.fold(0, (sum, size) => sum + size);

  int bytesFor(String category) => bytesByCategory[category] ?? 0;
}

class DriveAppDataBackup {
  const DriveAppDataBackup({required this.files});

  final List<DriveAppDataBackupFile> files;

  Map<String, dynamic> toJson() => {
    'format': 'protocolflow-drive-backup',
    'version': 1,
    'exportDate': DateTime.now().toIso8601String(),
    'files': files.map((file) => file.toJson()).toList(),
  };

  factory DriveAppDataBackup.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'protocolflow-drive-backup' || json['version'] != 1) {
      throw const FormatException('Unsupported ProtocolFlow Drive backup.');
    }
    final rawFiles = json['files'];
    if (rawFiles is! List) {
      throw const FormatException('Drive backup is missing its file list.');
    }
    final files = rawFiles.map((entry) {
      if (entry is! Map) {
        throw const FormatException('Drive backup contains an invalid file.');
      }
      return DriveAppDataBackupFile.fromJson(Map<String, dynamic>.from(entry));
    }).toList();
    return DriveAppDataBackup(files: files);
  }
}

class DriveAppDataBackupFile {
  const DriveAppDataBackupFile({required this.name, required this.content});

  final String name;
  final String content;

  Map<String, dynamic> toJson() => {'name': name, 'content': content};

  factory DriveAppDataBackupFile.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final content = json['content'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.contains('/') ||
        name.contains(r'\') ||
        content is! String) {
      throw const FormatException('Drive backup contains invalid file data.');
    }
    return DriveAppDataBackupFile(name: name, content: content);
  }
}

class RemoteProtocol {
  final DriveFileRecord file;
  final Protocol protocol;

  const RemoteProtocol({required this.file, required this.protocol});
}

class DriveSyncService {
  DriveSyncService._();

  static final DriveSyncService instance = DriveSyncService._();

  static const String _baseUrl = 'https://www.googleapis.com/drive/v3';
  static const String _uploadBaseUrl =
      'https://www.googleapis.com/upload/drive/v3';
  static const String _savedTablesFileName = 'saved_tables.json';
  static const String _tasksFileName = 'today_tasks.json';
  static const String _measuringToolsFileName = 'measuring_tools.json';
  static const String _projectsFileName = 'projects.json';
  static const String _journalPrefix = 'sync_journal_';
  static const String _journalSuffix = '.json';

  final AuthService _authService = AuthService.instance;
  final StorageService _storageService = StorageService();
  final TaskService _taskService = TaskService();
  final MeasuringToolService _measuringToolService =
      MeasuringToolService.instance;
  final SyncJournalStore _journalStore = SyncJournalStore();

  Future<DriveSyncSummary>? _activeSync;

  Future<int> clearAppDataFiles({bool promptIfNecessary = true}) async {
    final headers = await _authHeaders(promptIfNecessary: promptIfNecessary);
    if (headers == null) {
      throw StateError(
        'Drive authorization was not granted. Sign in and approve Drive access.',
      );
    }

    return _clearAppDataFiles(headers);
  }

  Future<DriveAppDataBackup> createAppDataBackup({
    bool promptIfNecessary = true,
  }) async {
    final headers = await _authHeaders(promptIfNecessary: promptIfNecessary);
    if (headers == null) {
      throw StateError(
        'Drive authorization was not granted. Sign in and approve Drive access.',
      );
    }

    final records = await _listAppDataFiles(headers);
    final files = <DriveAppDataBackupFile>[];
    for (final record in records) {
      final response = await http.get(
        Uri.parse('$_baseUrl/files/${record.id}?alt=media'),
        headers: headers,
      );
      _throwIfFailed(response);
      files.add(
        DriveAppDataBackupFile(
          name: record.name,
          content: utf8.decode(response.bodyBytes),
        ),
      );
    }
    return DriveAppDataBackup(files: files);
  }

  Future<DriveAppDataFootprint> loadAppDataFootprint({
    bool promptIfNecessary = false,
  }) async {
    final headers = await _authHeaders(promptIfNecessary: promptIfNecessary);
    if (headers == null) {
      throw StateError(
        'Drive authorization was not granted. Sign in and approve Drive access.',
      );
    }

    final records = await _listAppDataFiles(headers);
    final sizes = <String, int>{};
    for (final record in records) {
      var size = record.sizeBytes;
      if (size == null) {
        final response = await http.get(
          Uri.parse('$_baseUrl/files/${record.id}?alt=media'),
          headers: headers,
        );
        _throwIfFailed(response);
        size = response.bodyBytes.length;
      }
      final category = _footprintCategoryForFile(record.name);
      sizes[category] = (sizes[category] ?? 0) + size;
    }
    return DriveAppDataFootprint(
      bytesByCategory: sizes,
      fileCount: records.length,
    );
  }

  @visibleForTesting
  static String footprintCategoryForFile(String fileName) =>
      _footprintCategoryForFile(fileName);

  static String _footprintCategoryForFile(String fileName) {
    if (fileName == _projectsFileName) return 'Projects';
    if (fileName == _savedTablesFileName) return 'Tables';
    if (fileName == _tasksFileName) return 'Tasks';
    if (fileName == _measuringToolsFileName) return 'Measuring';
    if (fileName.startsWith('completed_protocol_')) return 'Completed';
    if (fileName.startsWith(_journalPrefix)) return 'Sync metadata';
    return 'Protocols';
  }

  Future<int> restoreAppDataBackup(
    DriveAppDataBackup backup, {
    bool promptIfNecessary = true,
  }) async {
    final headers = await _authHeaders(promptIfNecessary: promptIfNecessary);
    if (headers == null) {
      throw StateError(
        'Drive authorization was not granted. Sign in and approve Drive access.',
      );
    }

    await _clearAppDataFiles(headers);
    for (final file in backup.files) {
      await _createDriveFile(
        fileName: file.name,
        content: file.content,
        headers: headers,
      );
    }
    return backup.files.length;
  }

  Future<int> _clearAppDataFiles(Map<String, String> headers) async {
    final files = await _listAppDataFiles(headers);
    for (final file in files) {
      final response = await http.delete(
        Uri.parse('$_baseUrl/files/${file.id}'),
        headers: headers,
      );
      _throwIfFailed(response);
    }
    return files.length;
  }

  String _completedFileName(String completedId) {
    return 'completed_protocol_$completedId.json';
  }

  Future<DriveSyncPreview> prepareSyncPreview({
    bool promptIfNecessary = false,
  }) async {
    try {
      final plan = await _prepareSyncPlan(promptIfNecessary: promptIfNecessary);
      return DriveSyncPreview._(items: _buildPreviewItems(plan), plan: plan);
    } catch (error) {
      _logDriveError('prepare preview', error);
      return DriveSyncPreview._(error: _friendlyError(error));
    }
  }

  Future<DriveSyncSummary> applySyncPreview(
    DriveSyncPreview preview, {
    Map<String, DriveDeletionDecision> deletionDecisions = const {},
  }) async {
    final plan = preview._plan;
    if (plan == null) {
      return DriveSyncSummary(
        errors: 1,
        details: preview.error ?? 'The sync preview is not available.',
      );
    }
    final active = _activeSync;
    if (active != null) return active;
    final operation = _applyPreviewWithRevalidation(plan, deletionDecisions);
    _activeSync = operation;
    try {
      return await operation;
    } finally {
      if (identical(_activeSync, operation)) _activeSync = null;
    }
  }

  // Kept temporarily as a readable migration reference while v2 imports the
  // files produced by older app versions.
  // ignore: unused_element
  Future<DriveSyncSummary> _syncLegacyNow({
    bool promptIfNecessary = false,
  }) async {
    var downloaded = 0;
    var uploaded = 0;
    var conflicts = 0;
    var errors = 0;
    final errorDetails = <String>[];

    try {
      final headers = await _authHeaders(promptIfNecessary: promptIfNecessary);
      if (headers == null) {
        return const DriveSyncSummary(
          errors: 1,
          details:
              'Drive authorization was not granted. Sign out/in and approve Drive access.',
        );
      }

      final deletedRecords = await _storageService.loadDeletedProtocolRecords();
      final deletedProtocolIds = deletedRecords
          .map((record) => record.protocolId)
          .toSet();
      final deletionSummary = await _syncDeletedProtocols(
        deletedRecords,
        headers,
      );
      errors += deletionSummary.errors;
      if (deletionSummary.details != null) {
        errorDetails.add(deletionSummary.details!);
      }

      final localProtocols = await _storageService.loadProtocols();
      final remoteProtocols = await _downloadRemoteProtocols(
        headers,
        ignoredProtocolIds: deletedProtocolIds,
      );
      final remoteById = {
        for (final remote in remoteProtocols) remote.protocol.id: remote,
      };
      final merged = <Protocol>[];
      final handledIds = <String>{};
      final now = DateTime.now();

      for (final local in localProtocols) {
        final remote = remoteById[local.id];
        handledIds.add(local.id);

        if (remote == null) {
          try {
            final synced = await uploadProtocol(local, headers: headers);
            merged.add(synced);
            uploaded++;
          } catch (e) {
            _logDriveError('upload ${local.id}', e);
            errorDetails.add(_friendlyError(e));
            merged.add(_withSyncState(local, ProtocolSyncStatus.error));
            errors++;
          }
          continue;
        }

        final resolved = await _resolveLocalAndRemote(
          local: local,
          remote: remote,
          headers: headers,
          syncTime: now,
        );
        merged.addAll(resolved.protocols);
        downloaded += resolved.downloaded;
        uploaded += resolved.uploaded;
        conflicts += resolved.conflicts;
      }

      for (final remote in remoteProtocols) {
        if (handledIds.contains(remote.protocol.id)) continue;
        final protocol = remote.protocol.copyWith(
          driveFileId: remote.file.id,
          lastSyncedAt: now,
          syncStatus: ProtocolSyncStatus.synced,
        );
        merged.add(protocol);
        downloaded++;
      }

      await _storageService.saveProtocols(merged);
      final projectSummary = await _syncProjects(headers);
      downloaded += projectSummary.downloaded;
      uploaded += projectSummary.uploaded;
      errors += projectSummary.errors;
      if (projectSummary.details != null) {
        errorDetails.add(projectSummary.details!);
      }

      final completedSummary = await _syncCompletedProtocols(headers);
      downloaded += completedSummary.downloaded;
      uploaded += completedSummary.uploaded;
      errors += completedSummary.errors;
      if (completedSummary.details != null) {
        errorDetails.add(completedSummary.details!);
      }

      final tableSummary = await _syncSavedTables(headers);
      downloaded += tableSummary.downloaded;
      uploaded += tableSummary.uploaded;
      errors += tableSummary.errors;
      if (tableSummary.details != null) {
        errorDetails.add(tableSummary.details!);
      }

      final taskSummary = await _syncTasks(headers);
      downloaded += taskSummary.downloaded;
      uploaded += taskSummary.uploaded;
      errors += taskSummary.errors;
      if (taskSummary.details != null) {
        errorDetails.add(taskSummary.details!);
      }

      final measuringToolSummary = await _syncMeasuringTools(headers);
      downloaded += measuringToolSummary.downloaded;
      uploaded += measuringToolSummary.uploaded;
      errors += measuringToolSummary.errors;
      if (measuringToolSummary.details != null) {
        errorDetails.add(measuringToolSummary.details!);
      }

      return DriveSyncSummary(
        downloaded: downloaded,
        uploaded: uploaded,
        conflicts: conflicts,
        errors: errors,
        details: errorDetails.isEmpty ? null : errorDetails.first,
      );
    } catch (e) {
      _logDriveError('sync', e);
      await _markUnsyncedProtocols(ProtocolSyncStatus.error);
      await _storageService.markSavedTablesSyncError();
      await _storageService.saveSyncBundleState(
        SyncBundleType.projects,
        SyncBundleState.error,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.completedProtocols,
        SyncBundleState.error,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.tasks,
        SyncBundleState.error,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.measuringTools,
        SyncBundleState.error,
      );
      return DriveSyncSummary(errors: 1, details: _friendlyError(e));
    }
  }

  Future<_PreparedSyncPlan> _prepareSyncPlan({
    required bool promptIfNecessary,
  }) async {
    final headers = await _authHeaders(promptIfNecessary: promptIfNecessary);
    if (headers == null) {
      throw StateError(
        'Drive authorization was not granted. Sign out/in and approve Drive access.',
      );
    }

    await _storageService.validateLocalSyncData();
    await _taskService.validateLocalSyncData();
    await _measuringToolService.validateLocalSyncData();

    final deviceId = await _journalStore.loadOrCreateDeviceId();
    final localAtStart = await _buildLocalSyncRecords();
    final baseline = await _journalStore.loadBaseline();
    final localJournal = await _journalStore.loadLocalJournal(deviceId);
    final files = await _listAppDataFiles(headers);
    final downloadedJournals = await _downloadSyncJournals(files, headers);
    final legacyJournal = await _buildLegacyJournal(files, headers);
    final remoteJournals = <SyncJournal>[...downloadedJournals, legacyJournal];
    final remoteMerge = mergeSyncJournals(remoteJournals);
    final maxRemoteClock = remoteJournals.fold<int>(
      0,
      (maximum, journal) =>
          journal.maxClock > maximum ? journal.maxClock : maximum,
    );
    final recoveredOwnJournal = SyncJournal(
      deviceId: deviceId,
      entries: mergeSyncJournals([
        ...downloadedJournals.where((journal) => journal.deviceId == deviceId),
        localJournal,
      ]).winners,
    );
    var nextClock = recoveredOwnJournal.maxClock > maxRemoteClock
        ? recoveredOwnJournal.maxClock
        : maxRemoteClock;
    final ownEntries = Map<String, SyncEntityRecord>.from(
      recoveredOwnJournal.entries,
    );
    var localChanges = 0;
    var conflicts = remoteMerge.conflicts.length;
    final changedKeys = <String>{};
    final invalidRemoteKeys = <String>{};
    final invalidRemoteReasons = <String, String>{};

    for (final entry in remoteMerge.winners.entries) {
      final remote = entry.value;
      final validationError = _recordValidationError(remote);
      if (validationError == null) continue;
      invalidRemoteKeys.add(entry.key);
      final local = localAtStart[entry.key];
      if (local == null) {
        invalidRemoteReasons[entry.key] = validationError;
        continue;
      }
      ownEntries[entry.key] = _recordForLocalValue(
        local,
        deviceId,
        ++nextClock,
      );
      changedKeys.add(entry.key);
      localChanges++;
    }

    final keys = <String>{...localAtStart.keys, ...baseline.keys};
    for (final key in keys) {
      if (invalidRemoteKeys.contains(key)) continue;
      final local = localAtStart[key];
      final previous = baseline[key];
      final remote = remoteMerge.winners[key];
      if (previous == null) {
        if (local == null) continue;
        if (remote?.deleted ?? false) continue;
        if (remote == null || !local.hasSameValue(remote)) {
          ownEntries[key] = _recordForLocalValue(local, deviceId, ++nextClock);
          changedKeys.add(key);
          localChanges++;
          if (remote != null && !remote.deleted) {
            final conflict = _createConflictRecord(
              source: remote,
              deviceId: deviceId,
              clock: ++nextClock,
              existingKeys: ownEntries.keys,
            );
            if (conflict != null) {
              ownEntries[conflict.key] = conflict;
              changedKeys.add(conflict.key);
              conflicts++;
            }
          }
        }
        continue;
      }

      if (local == null) {
        if (!previous.deleted) {
          ownEntries[key] = SyncEntityRecord(
            entityType: previous.entityType,
            entityId: previous.entityId,
            clock: ++nextClock,
            deviceId: deviceId,
            deleted: true,
          );
          changedKeys.add(key);
          localChanges++;
        }
        continue;
      }

      if (previous.deleted || !local.hasSameValue(previous)) {
        ownEntries[key] = _recordForLocalValue(local, deviceId, ++nextClock);
        changedKeys.add(key);
        localChanges++;
      }
    }

    final deletedProtocols = await _storageService.loadDeletedProtocolRecords();
    for (final deletion in deletedProtocols) {
      final record = SyncEntityRecord(
        entityType: _protocolType,
        entityId: deletion.protocolId,
        clock: ++nextClock,
        deviceId: deviceId,
        deleted: true,
      );
      ownEntries[record.key] = record;
      changedKeys.add(record.key);
      localChanges++;
    }
    final deletedTableIds = await _storageService.loadDeletedSavedTableIds();
    for (final tableId in deletedTableIds) {
      final record = SyncEntityRecord(
        entityType: _savedTableType,
        entityId: tableId,
        clock: ++nextClock,
        deviceId: deviceId,
        deleted: true,
      );
      ownEntries[record.key] = record;
      changedKeys.add(record.key);
      localChanges++;
    }

    var updatedLocalJournal = SyncJournal(
      deviceId: deviceId,
      entries: ownEntries,
    );
    var combined = mergeSyncJournals([...remoteJournals, updatedLocalJournal]);
    for (final conflict in combined.conflicts) {
      if (conflict.loser.deleted ||
          _recordValidationError(conflict.loser) != null) {
        continue;
      }
      final preserved = _createConflictRecord(
        source: conflict.loser,
        deviceId: deviceId,
        clock: ++nextClock,
        existingKeys: ownEntries.keys,
      );
      if (preserved != null) {
        ownEntries[preserved.key] = preserved;
        changedKeys.add(preserved.key);
        conflicts++;
      }
    }
    updatedLocalJournal = SyncJournal(deviceId: deviceId, entries: ownEntries);
    combined = mergeSyncJournals([...remoteJournals, updatedLocalJournal]);

    final ownRemoteFiles =
        files.where((file) => file.name == _journalFileName(deviceId)).toList()
          ..sort(_newestFileFirst);
    final storedFileId = await _journalStore.loadDriveFileId();
    final existingFileId = files.any((file) => file.id == storedFileId)
        ? storedFileId
        : ownRemoteFiles.firstOrNull?.id;
    final journalChanged = localChanges > 0 || ownRemoteFiles.isEmpty;
    final deletionSources = <String, SyncEntityRecord>{};
    for (final entry in combined.winners.entries) {
      if (!entry.value.deleted) continue;
      final source =
          localAtStart[entry.key] ??
          baseline[entry.key] ??
          remoteMerge.winners[entry.key];
      if (source != null && !source.deleted && source.data != null) {
        deletionSources[entry.key] = source;
      }
    }
    for (final deletion in deletedProtocols) {
      final key = '$_protocolType::${deletion.protocolId}';
      deletionSources.putIfAbsent(
        key,
        () => SyncEntityRecord(
          entityType: _protocolType,
          entityId: deletion.protocolId,
          clock: 0,
          deviceId: 'local-deletion',
          data: _normalizeEntityData(_protocolType, deletion.protocol.toJson()),
        ),
      );
    }
    final fingerprint = _syncPlanFingerprint(
      localAtStart,
      remoteJournals,
      baseline,
    );
    return _PreparedSyncPlan(
      headers: headers,
      deviceId: deviceId,
      localAtStart: localAtStart,
      remoteJournals: remoteJournals,
      ownEntries: ownEntries,
      combined: combined,
      changedKeys: changedKeys,
      deletionSources: deletionSources,
      invalidRemoteReasons: invalidRemoteReasons,
      nextClock: nextClock,
      conflicts: conflicts,
      journalChanged: journalChanged,
      existingFileId: existingFileId,
      fingerprint: fingerprint,
    );
  }

  Future<DriveSyncSummary> _applyPreviewWithRevalidation(
    _PreparedSyncPlan original,
    Map<String, DriveDeletionDecision> deletionDecisions,
  ) async {
    try {
      final refreshed = await _prepareSyncPlan(promptIfNecessary: false);
      if (refreshed.fingerprint != original.fingerprint) {
        return const DriveSyncSummary(
          errors: 1,
          previewExpired: true,
          details:
              'Sync data changed while the preview was open. Review the refreshed preview.',
        );
      }
      return await _applyPreparedPlan(refreshed, deletionDecisions);
    } catch (error) {
      _logDriveError('apply preview', error);
      return DriveSyncSummary(errors: 1, details: _friendlyError(error));
    }
  }

  Future<DriveSyncSummary> _applyPreparedPlan(
    _PreparedSyncPlan plan,
    Map<String, DriveDeletionDecision> deletionDecisions,
  ) async {
    final ownEntries = Map<String, SyncEntityRecord>.from(plan.ownEntries);
    var nextClock = plan.nextClock;
    final restoredKeys = <String>{};
    for (final entry in deletionDecisions.entries) {
      if (entry.value != DriveDeletionDecision.keepEverywhere) continue;
      final source = plan.deletionSources[entry.key];
      if (source == null || source.data == null) continue;
      final restoredRecord = SyncEntityRecord(
        entityType: source.entityType,
        entityId: source.entityId,
        clock: ++nextClock,
        deviceId: plan.deviceId,
        data: source.data,
      );
      ownEntries[restoredRecord.key] = restoredRecord;
      restoredKeys.add(restoredRecord.key);
    }
    final removedInvalidKeys = <String>{};
    for (final entry in plan.invalidRemoteReasons.entries) {
      if (deletionDecisions[entry.key] !=
          DriveDeletionDecision.deleteEverywhere) {
        continue;
      }
      final source = plan.combined.winners[entry.key];
      if (source == null) continue;
      ownEntries[entry.key] = SyncEntityRecord(
        entityType: source.entityType,
        entityId: source.entityId,
        clock: ++nextClock,
        deviceId: plan.deviceId,
        deleted: true,
      );
      removedInvalidKeys.add(entry.key);
    }
    final localJournal = SyncJournal(
      deviceId: plan.deviceId,
      entries: ownEntries,
    );
    final combined = mergeSyncJournals([...plan.remoteJournals, localJournal]);
    final shouldUpload =
        plan.journalChanged ||
        restoredKeys.isNotEmpty ||
        removedInvalidKeys.isNotEmpty;
    var uploaded = 0;
    if (shouldUpload) {
      final fileId = await _uploadJsonFile(
        fileName: _journalFileName(plan.deviceId),
        content: const JsonEncoder.withIndent(
          '  ',
        ).convert(localJournal.toJson()),
        headers: plan.headers,
        existingFileId: plan.existingFileId,
      );
      await _journalStore.saveDriveFileId(fileId);
      await _journalStore.saveLocalJournal(localJournal);
      uploaded = {
        ...plan.changedKeys,
        ...restoredKeys,
        ...removedInvalidKeys,
      }.length;
    }

    final localBeforeApply = await _buildLocalSyncRecords();
    if (!_sameLocalSnapshot(plan.localAtStart, localBeforeApply)) {
      return DriveSyncSummary(
        uploaded: uploaded,
        conflicts: plan.conflicts,
        errors: 1,
        previewExpired: true,
        details:
            'Local data changed while sync was running. Review the refreshed preview.',
      );
    }

    final applicableRecords = Map<String, SyncEntityRecord>.fromEntries(
      combined.winners.entries.where(
        (entry) => _recordValidationError(entry.value) == null,
      ),
    );
    final downloaded = _countAppliedRemoteChanges(
      plan.localAtStart,
      applicableRecords,
    );
    await _applySyncRecords(applicableRecords);
    await _journalStore.saveBaseline(applicableRecords);
    await _storageService.saveDeletedProtocolRecords([]);
    await _storageService.saveDeletedSavedTableIds([]);
    return DriveSyncSummary(
      downloaded: downloaded,
      uploaded: uploaded,
      conflicts: plan.conflicts,
    );
  }

  List<DriveSyncPreviewItem> _buildPreviewItems(_PreparedSyncPlan plan) {
    final items = <String, DriveSyncPreviewItem>{};
    for (final entry in plan.combined.winners.entries) {
      final key = entry.key;
      final after = entry.value;
      final before = plan.localAtStart[key];
      final invalidReason = plan.invalidRemoteReasons[key];
      if (invalidReason != null) {
        items[key] = DriveSyncPreviewItem(
          key: key,
          category: _categoryLabel(after.entityType),
          title: _entityTitle(after),
          action: DriveSyncActionType.invalid,
          deviceId: after.deviceId,
          canKeep: true,
          note:
              '$invalidReason Keep it in cloud, or explicitly delete it from '
              'all devices.',
        );
        continue;
      }
      if (after.deleted) {
        if (before == null && !plan.changedKeys.contains(key)) continue;
        final source = plan.deletionSources[key];
        items[key] = DriveSyncPreviewItem(
          key: key,
          category: _categoryLabel(after.entityType),
          title: _entityTitle(source ?? after),
          action: DriveSyncActionType.delete,
          deviceId: after.deviceId,
          canKeep: source?.data != null,
        );
        continue;
      }
      if (key.contains('-conflict-') || key.contains('-legacy-conflict-')) {
        items[key] = DriveSyncPreviewItem(
          key: key,
          category: _categoryLabel(after.entityType),
          title: _entityTitle(after),
          action: DriveSyncActionType.conflict,
          deviceId: after.deviceId,
        );
        continue;
      }
      if (plan.changedKeys.contains(key)) {
        items[key] = DriveSyncPreviewItem(
          key: key,
          category: _categoryLabel(after.entityType),
          title: _entityTitle(after),
          action: DriveSyncActionType.upload,
          deviceId: plan.deviceId,
        );
        continue;
      }
      if (before == null || !before.hasSameValue(after)) {
        items[key] = DriveSyncPreviewItem(
          key: key,
          category: _categoryLabel(after.entityType),
          title: _entityTitle(after),
          action: DriveSyncActionType.download,
          deviceId: after.deviceId,
        );
      }
    }
    final result = items.values.toList()
      ..sort((left, right) {
        final byCategory = left.category.compareTo(right.category);
        if (byCategory != 0) return byCategory;
        final byAction = left.action.index.compareTo(right.action.index);
        if (byAction != 0) return byAction;
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    return result;
  }

  String _categoryLabel(String entityType) {
    return switch (entityType) {
      _protocolType => 'Protocols',
      _projectType => 'Projects',
      _completedProtocolType => 'Completed protocols',
      _runningProtocolType => 'Running protocols',
      _savedTableType => 'Saved tables',
      _todayTaskType => "Today's tasks",
      _historyTaskType => 'Task history',
      _measuringToolType => 'Measuring tools',
      _ => 'Other',
    };
  }

  String _entityTitle(SyncEntityRecord record) {
    final data = record.data;
    if (data == null) return record.entityId;
    final direct = data['title'] ?? data['name'] ?? data['toolName'];
    if (direct?.toString().trim().isNotEmpty ?? false) {
      return direct.toString();
    }
    final protocol = data['protocol'];
    if (protocol is Map) {
      final title = protocol['title']?.toString().trim();
      if (title != null && title.isNotEmpty) return title;
    }
    return record.entityId;
  }

  String _syncPlanFingerprint(
    Map<String, SyncEntityRecord> local,
    List<SyncJournal> remoteJournals,
    Map<String, SyncEntityRecord> baseline,
  ) {
    Map<String, dynamic> recordMap(Map<String, SyncEntityRecord> records) => {
      for (final entry in records.entries) entry.key: entry.value.toJson(),
    };
    final journals =
        remoteJournals
            .map((journal) => syncDataHash(recordMap(journal.entries)))
            .toList()
          ..sort();
    return syncDataHash({
      'local': recordMap(local),
      'remote': journals,
      'baseline': recordMap(baseline),
    });
  }

  static const String _protocolType = 'protocol';
  static const String _projectType = 'project';
  static const String _completedProtocolType = 'completedProtocol';
  static const String _runningProtocolType = 'runningProtocol';
  static const String _savedTableType = 'savedTable';
  static const String _todayTaskType = 'todayTask';
  static const String _historyTaskType = 'historyTask';
  static const String _measuringToolType = 'measuringTool';

  SyncEntityRecord _recordForLocalValue(
    SyncEntityRecord local,
    String deviceId,
    int clock,
  ) {
    return SyncEntityRecord(
      entityType: local.entityType,
      entityId: local.entityId,
      clock: clock,
      deviceId: deviceId,
      data: local.data,
    );
  }

  String _journalFileName(String deviceId) =>
      '$_journalPrefix$deviceId$_journalSuffix';

  Future<Map<String, SyncEntityRecord>> _buildLocalSyncRecords() async {
    final records = <String, SyncEntityRecord>{};
    void add(String type, String id, Map<String, dynamic> data) {
      final normalizedId = id.trim();
      if (normalizedId.isEmpty) return;
      final record = SyncEntityRecord(
        entityType: type,
        entityId: normalizedId,
        clock: 0,
        deviceId: 'local',
        data: _normalizeEntityData(type, data),
      );
      records[record.key] = record;
    }

    for (final protocol in await _storageService.loadProtocols()) {
      if (_isValidProtocol(protocol)) {
        add(_protocolType, protocol.id, protocol.toJson());
      }
    }
    for (final project in await _storageService.loadProjects()) {
      if (project.name.trim().isNotEmpty) {
        add(_projectType, project.id, project.toJson());
      }
    }
    for (final completed in await _storageService.loadCompletedProtocols()) {
      if (completed.id.trim().isNotEmpty &&
          _isValidProtocol(completed.protocol)) {
        add(_completedProtocolType, completed.id, completed.toJson());
      }
    }
    final sessions = <String, ActiveProtocol>{};
    for (final session in await _storageService.loadRunningProtocols()) {
      sessions[session.protocol.id] = session;
    }
    final activeSession = await _storageService.loadActiveProtocol();
    if (activeSession != null) {
      sessions[activeSession.protocol.id] = activeSession;
    }
    for (final session in sessions.values) {
      if (_isValidProtocol(session.protocol)) {
        add(_runningProtocolType, session.protocol.id, session.toJson());
      }
    }
    for (final table in await _storageService.loadSavedTables()) {
      if (table.id.trim().isNotEmpty && table.title.trim().isNotEmpty) {
        add(_savedTableType, table.id, table.toJson());
      }
    }
    for (final task in await _taskService.loadTodayTasks()) {
      add(_todayTaskType, task.id, task.toJson());
    }
    for (final task in await _taskService.loadHistoryTasks()) {
      add(_historyTaskType, task.id, task.toJson());
    }
    if (await _measuringToolService.hasStoredToolsForSync()) {
      for (final tool in await _measuringToolService.loadTools()) {
        if (tool.id.trim().isNotEmpty) {
          add(_measuringToolType, tool.id, tool.toJson());
        }
      }
    }
    return records;
  }

  @visibleForTesting
  Future<Map<String, SyncEntityRecord>> buildLocalSyncRecordsForTesting() {
    return _buildLocalSyncRecords();
  }

  Map<String, dynamic> _normalizeEntityData(
    String entityType,
    Map<String, dynamic> data,
  ) {
    final normalized = Map<String, dynamic>.from(data);
    if (entityType == _protocolType) {
      normalized.remove('driveFileId');
      normalized.remove('lastSyncedAt');
      normalized.remove('syncStatus');
    } else if (entityType == _completedProtocolType ||
        entityType == _runningProtocolType) {
      normalized.remove('driveFileId');
      normalized.remove('lastSyncedAt');
      normalized.remove('syncStatus');
      final protocol = normalized['protocol'];
      if (protocol is Map) {
        normalized['protocol'] = _normalizeEntityData(
          _protocolType,
          Map<String, dynamic>.from(protocol),
        );
      }
    }
    return normalized;
  }

  bool _isValidProtocol(Protocol protocol) {
    return protocol.id.trim().isNotEmpty && protocol.title.trim().isNotEmpty;
  }

  String? _recordValidationError(SyncEntityRecord? record) {
    if (record == null || record.deleted) return null;
    final data = record.data;
    if (data == null) return 'The cloud record has no saved data.';
    try {
      switch (record.entityType) {
        case _protocolType:
          final protocol = Protocol.fromJson(data);
          if (!_isValidProtocol(protocol) || protocol.id != record.entityId) {
            return 'The cloud protocol is incomplete or has a mismatched ID.';
          }
        case _projectType:
          final project = Project.fromJson(data);
          if (project.id != record.entityId || project.name.trim().isEmpty) {
            return 'The cloud project is incomplete or has a mismatched ID.';
          }
        case _completedProtocolType:
          final completed = CompletedProtocol.fromJson(data);
          if (completed.id != record.entityId ||
              !_isValidProtocol(completed.protocol)) {
            return 'The completed protocol is incomplete or has a mismatched ID.';
          }
        case _runningProtocolType:
          final running = ActiveProtocol.fromJson(data);
          if (running.protocol.id != record.entityId ||
              !_isValidProtocol(running.protocol)) {
            return 'The running protocol is incomplete or has a mismatched ID.';
          }
        case _savedTableType:
          final table = ProtocolTable.fromJson(data);
          if (table.id != record.entityId || table.title.trim().isEmpty) {
            return 'The saved table is incomplete or has a mismatched ID.';
          }
        case _todayTaskType:
        case _historyTaskType:
          final task = Task.fromJson(data);
          if (task.id != record.entityId) {
            return 'The task has a mismatched ID.';
          }
        case _measuringToolType:
          final tool = MeasuringTool.fromJson(data);
          if (tool.id != record.entityId || tool.id.trim().isEmpty) {
            return 'The measuring tool has a mismatched ID.';
          }
        default:
          return 'This cloud record type is not supported.';
      }
    } catch (_) {
      return 'The cloud record is damaged or uses invalid data.';
    }
    return null;
  }

  @visibleForTesting
  String? recordValidationErrorForTesting(SyncEntityRecord record) {
    return _recordValidationError(record);
  }

  bool _sameLocalSnapshot(
    Map<String, SyncEntityRecord> left,
    Map<String, SyncEntityRecord> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      final other = right[entry.key];
      if (other == null || !entry.value.hasSameValue(other)) return false;
    }
    return true;
  }

  int _countAppliedRemoteChanges(
    Map<String, SyncEntityRecord> local,
    Map<String, SyncEntityRecord> merged,
  ) {
    var changes = 0;
    final keys = <String>{...local.keys, ...merged.keys};
    for (final key in keys) {
      final before = local[key];
      final after = merged[key];
      if (after == null || after.deleted) {
        if (before != null) changes++;
      } else if (before == null || !before.hasSameValue(after)) {
        changes++;
      }
    }
    return changes;
  }

  Future<List<SyncJournal>> _downloadSyncJournals(
    List<DriveFileRecord> files,
    Map<String, String> headers,
  ) async {
    final journals = <SyncJournal>[];
    for (final file in files) {
      if (!file.name.startsWith(_journalPrefix) ||
          !file.name.endsWith(_journalSuffix)) {
        continue;
      }
      final decoded = await _downloadJson(file.id, headers);
      if (decoded is! Map) {
        throw FormatException('Remote sync journal ${file.name} is invalid.');
      }
      journals.add(SyncJournal.fromJson(Map<String, dynamic>.from(decoded)));
    }
    journals.sort((left, right) {
      final byDevice = left.deviceId.compareTo(right.deviceId);
      if (byDevice != 0) return byDevice;
      Map<String, dynamic> values(SyncJournal journal) => {
        for (final entry in journal.entries.entries)
          entry.key: entry.value.toJson(),
      };
      return syncDataHash(values(left)).compareTo(syncDataHash(values(right)));
    });
    return journals;
  }

  int _newestFileFirst(DriveFileRecord left, DriveFileRecord right) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return (right.modifiedTime ?? epoch).compareTo(left.modifiedTime ?? epoch);
  }

  Future<SyncJournal> _buildLegacyJournal(
    List<DriveFileRecord> files,
    Map<String, String> headers,
  ) async {
    final entries = <String, SyncEntityRecord>{};
    void add(
      String type,
      String id,
      Map<String, dynamic> data,
      String sourceId,
    ) {
      final normalizedId = id.trim();
      if (normalizedId.isEmpty) return;
      final record = SyncEntityRecord(
        entityType: type,
        entityId: normalizedId,
        clock: 0,
        deviceId: 'legacy_$sourceId',
        data: _normalizeEntityData(type, data),
      );
      final existing = entries[record.key];
      if (existing == null) {
        entries[record.key] = record;
      } else if (!record.hasSameValue(existing)) {
        final winner = compareSyncVersions(record, existing) > 0
            ? record
            : existing;
        final loser = identical(winner, record) ? existing : record;
        entries[record.key] = winner;
        final conflict = _createLegacyConflictRecord(loser, entries.keys);
        if (conflict != null) entries[conflict.key] = conflict;
      }
    }

    for (final file in files) {
      if (file.name.startsWith(_journalPrefix)) continue;
      dynamic decoded;
      try {
        decoded = await _downloadJson(file.id, headers);
      } catch (_) {
        continue;
      }
      if (file.name == _projectsFileName && decoded is Map) {
        for (final raw in decoded['projects'] as List? ?? const []) {
          if (raw is Map) {
            final data = Map<String, dynamic>.from(raw);
            add(_projectType, data['id']?.toString() ?? '', data, file.id);
          }
        }
        continue;
      }
      if (file.name == _tasksFileName && decoded is Map) {
        for (final raw in decoded['today'] as List? ?? const []) {
          if (raw is Map) {
            final data = Map<String, dynamic>.from(raw);
            add(_todayTaskType, data['id']?.toString() ?? '', data, file.id);
          }
        }
        for (final raw in decoded['history'] as List? ?? const []) {
          if (raw is Map) {
            final data = Map<String, dynamic>.from(raw);
            add(_historyTaskType, data['id']?.toString() ?? '', data, file.id);
          }
        }
        continue;
      }
      if (file.name == _measuringToolsFileName && decoded is Map) {
        for (final raw in decoded['tools'] as List? ?? const []) {
          if (raw is Map) {
            final data = Map<String, dynamic>.from(raw);
            add(
              _measuringToolType,
              data['id']?.toString() ?? '',
              data,
              file.id,
            );
          }
        }
        continue;
      }
      if (file.name == _savedTablesFileName && decoded is List) {
        for (final raw in decoded) {
          if (raw is Map) {
            final data = Map<String, dynamic>.from(raw);
            add(_savedTableType, data['id']?.toString() ?? '', data, file.id);
          }
        }
        continue;
      }
      if (file.name.startsWith('completed_protocol_') && decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        final id = data['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          try {
            final completed = CompletedProtocol.fromJson(data);
            if (_isValidProtocol(completed.protocol)) {
              add(_completedProtocolType, id, data, file.id);
            }
          } catch (_) {
            // A damaged legacy file is ignored, never converted to empty data.
          }
        }
        continue;
      }
      if (_isLegacyProtocolFile(file.name, decoded)) {
        final data = Map<String, dynamic>.from(decoded as Map);
        add(_protocolType, data['id'].toString(), data, file.id);
      }
    }
    return SyncJournal(deviceId: 'legacy', entries: entries);
  }

  SyncEntityRecord? _createLegacyConflictRecord(
    SyncEntityRecord source,
    Iterable<String> existingKeys,
  ) {
    if (source.data == null) return null;
    final token = _stableToken('${source.key}:${source.deviceId}');
    final conflictId = '${source.entityId}-legacy-conflict-$token';
    final key = '${source.entityType}::$conflictId';
    if (existingKeys.contains(key)) return null;
    final data = Map<String, dynamic>.from(source.data!);
    data['id'] = conflictId;
    if (data.containsKey('protocolId')) data['protocolId'] = conflictId;
    if (source.entityType == _runningProtocolType && data['protocol'] is Map) {
      final protocol = Map<String, dynamic>.from(data['protocol'] as Map);
      protocol['id'] = conflictId;
      final title = protocol['title'] ?? protocol['name'];
      if (title is String) {
        protocol['title'] = '$title (conflict copy)';
        protocol['name'] = '$title (conflict copy)';
      }
      data['protocol'] = protocol;
    }
    if (data['title'] is String) {
      data['title'] = '${data['title']} (legacy conflict copy)';
    } else if (data['name'] is String) {
      data['name'] = '${data['name']} (legacy conflict copy)';
    }
    return SyncEntityRecord(
      entityType: source.entityType,
      entityId: conflictId,
      clock: 0,
      deviceId: source.deviceId,
      data: data,
    );
  }

  bool _isLegacyProtocolFile(String fileName, dynamic decoded) {
    if (!fileName.endsWith('.json') || decoded is! Map) return false;
    if (fileName == _projectsFileName ||
        fileName == _tasksFileName ||
        fileName == _measuringToolsFileName ||
        fileName == _savedTablesFileName ||
        fileName.startsWith('completed_protocol_') ||
        fileName.startsWith(_journalPrefix)) {
      return false;
    }
    final data = Map<String, dynamic>.from(decoded);
    final id = data['id']?.toString().trim() ?? '';
    final title = data['title']?.toString().trim() ?? '';
    return id.isNotEmpty && title.isNotEmpty && fileName == '$id.json';
  }

  SyncEntityRecord? _createConflictRecord({
    required SyncEntityRecord source,
    required String deviceId,
    required int clock,
    required Iterable<String> existingKeys,
  }) {
    if (source.deleted || source.data == null) return null;
    final token = _stableToken(
      '${source.key}:${source.clock}:${source.deviceId}',
    );
    final conflictId = '${source.entityId}-conflict-$token';
    final key = '${source.entityType}::$conflictId';
    if (existingKeys.contains(key)) return null;
    final data = Map<String, dynamic>.from(source.data!);
    data['id'] = conflictId;
    if (data.containsKey('protocolId')) data['protocolId'] = conflictId;
    if (source.entityType == _runningProtocolType && data['protocol'] is Map) {
      final protocol = Map<String, dynamic>.from(data['protocol'] as Map);
      protocol['id'] = conflictId;
      final title = protocol['title'] ?? protocol['name'];
      if (title is String) {
        protocol['title'] = '$title (conflict copy)';
        protocol['name'] = '$title (conflict copy)';
      }
      data['protocol'] = protocol;
    }
    if (data['title'] is String) {
      data['title'] = '${data['title']} (conflict copy)';
    } else if (data['name'] is String) {
      data['name'] = '${data['name']} (conflict copy)';
    }
    return SyncEntityRecord(
      entityType: source.entityType,
      entityId: conflictId,
      clock: clock,
      deviceId: deviceId,
      data: data,
    );
  }

  String _stableToken(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(36);
  }

  Future<void> _applySyncRecords(Map<String, SyncEntityRecord> records) async {
    final activeBeforeSync = await _storageService.loadActiveProtocol();
    final live = records.values.where((record) => !record.deleted).toList();
    final now = DateTime.now();
    final protocols = <Protocol>[];
    final projects = <Project>[];
    final completed = <CompletedProtocol>[];
    final running = <ActiveProtocol>[];
    final tables = <ProtocolTable>[];
    final todayTasks = <Task>[];
    final historyTasks = <Task>[];
    final measuringTools = <MeasuringTool>[];

    for (final record in live) {
      final data = record.data!;
      switch (record.entityType) {
        case _protocolType:
          final protocol = Protocol.fromJson(data);
          if (_isValidProtocol(protocol)) {
            protocols.add(
              protocol.copyWith(
                lastSyncedAt: now,
                syncStatus: ProtocolSyncStatus.synced,
              ),
            );
          }
        case _projectType:
          final project = Project.fromJson(data);
          if (project.name.trim().isNotEmpty) projects.add(project);
        case _completedProtocolType:
          final item = CompletedProtocol.fromJson(
            data,
          ).copyWith(lastSyncedAt: now, syncStatus: ProtocolSyncStatus.synced);
          if (_isValidProtocol(item.protocol)) completed.add(item);
        case _runningProtocolType:
          final session = ActiveProtocol.fromJson(data);
          if (_isValidProtocol(session.protocol)) {
            running.add(
              session.copyWith(
                protocol: session.protocol.copyWith(
                  lastSyncedAt: now,
                  syncStatus: ProtocolSyncStatus.synced,
                ),
              ),
            );
          }
        case _savedTableType:
          final table = ProtocolTable.fromJson(data);
          if (table.id.isNotEmpty && table.title.trim().isNotEmpty) {
            tables.add(table);
          }
        case _todayTaskType:
          todayTasks.add(Task.fromJson(data));
        case _historyTaskType:
          historyTasks.add(Task.fromJson(data));
        case _measuringToolType:
          final tool = MeasuringTool.fromJson(data);
          if (tool.id.isNotEmpty) measuringTools.add(tool);
      }
    }

    await _storageService.saveProtocols(protocols);
    await _storageService.saveProjects(
      projects,
      markUpdated: false,
      markPending: false,
    );
    await _storageService.saveCompletedProtocols(completed, markPending: false);
    ActiveProtocol? activeAfterSync;
    if (activeBeforeSync != null) {
      final activeIndex = running.indexWhere(
        (session) => activeBeforeSync.runId != null
            ? session.runId == activeBeforeSync.runId
            : session.protocol.id == activeBeforeSync.protocol.id,
      );
      if (activeIndex >= 0) {
        activeAfterSync = running.removeAt(activeIndex);
      }
    }
    await _storageService.saveActiveProtocol(activeAfterSync);
    await _storageService.saveRunningProtocols(running);
    await ProtocolRunService.instance.replaceFromLegacySync(
      active: activeAfterSync,
      running: running,
      completed: completed,
    );
    await _storageService.saveSavedTables(tables, markPending: false);
    await _taskService.replaceFromSyncPayload({
      'updatedAt': now.toUtc().toIso8601String(),
      'today': todayTasks.map((task) => task.toJson()).toList(),
      'history': historyTasks.map((task) => task.toJson()).toList(),
    });
    final hasMeasuringToolHistory = records.values.any(
      (record) => record.entityType == _measuringToolType,
    );
    if (hasMeasuringToolHistory) {
      await _measuringToolService.replaceFromSyncPayload({
        'updatedAt': now.toUtc().toIso8601String(),
        'tools': measuringTools.map((tool) => tool.toJson()).toList(),
        'allowEmpty': true,
      });
    }
    await _storageService.markSavedTablesSynced();
    for (final type in SyncBundleType.values) {
      await _storageService.saveSyncBundleState(type, SyncBundleState.synced);
    }
  }

  Future<Protocol> syncProtocolAfterLocalSave(Protocol protocol) async {
    final pending = _withSyncState(protocol, ProtocolSyncStatus.modified);
    await _storageService.upsertProtocol(pending);
    return pending;
  }

  Future<Protocol> uploadProtocol(
    Protocol protocol, {
    Map<String, String>? headers,
  }) async {
    final authHeaders = headers ?? await _authHeaders(promptIfNecessary: false);
    if (authHeaders == null) {
      throw StateError('Google Drive authorization is not available.');
    }

    final existingFile = await _findDriveFile(
      '${protocol.id}.json',
      authHeaders,
    );
    final fileId = existingFile?.id;
    final syncTime = DateTime.now();
    final jsonBody = const JsonEncoder.withIndent('  ').convert(
      protocol
          .copyWith(
            driveFileId: fileId,
            lastSyncedAt: syncTime,
            syncStatus: ProtocolSyncStatus.synced,
          )
          .toJson(),
    );

    if (fileId == null || fileId.isEmpty) {
      final createdId = await _createDriveFile(
        fileName: '${protocol.id}.json',
        content: jsonBody,
        headers: authHeaders,
      );
      return protocol.copyWith(
        driveFileId: createdId,
        lastSyncedAt: syncTime,
        syncStatus: ProtocolSyncStatus.synced,
      );
    }

    await _updateDriveFile(
      fileId: fileId,
      content: jsonBody,
      headers: authHeaders,
    );
    return protocol.copyWith(
      driveFileId: fileId,
      lastSyncedAt: syncTime,
      syncStatus: ProtocolSyncStatus.synced,
    );
  }

  Future<Map<String, String>?> _authHeaders({
    required bool promptIfNecessary,
  }) async {
    final headers = await _authService.authorizationHeadersForDrive(
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) return null;
    return {...headers, 'Accept': 'application/json'};
  }

  Future<List<RemoteProtocol>> _downloadRemoteProtocols(
    Map<String, String> headers, {
    Set<String> ignoredProtocolIds = const {},
  }) async {
    final files = await _listAppDataFiles(headers);
    final remotes = <RemoteProtocol>[];
    for (final file in files) {
      if (!file.name.endsWith('.json')) continue;
      if (file.name.startsWith('completed_protocol_')) continue;
      if (file.name == _savedTablesFileName) continue;
      if (file.name == _projectsFileName) continue;
      final response = await http.get(
        Uri.parse('$_baseUrl/files/${file.id}?alt=media'),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) continue;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) continue;
      final protocol = Protocol.fromJson(
        decoded,
      ).copyWith(driveFileId: file.id, syncStatus: ProtocolSyncStatus.synced);
      if (ignoredProtocolIds.contains(protocol.id)) continue;
      remotes.add(RemoteProtocol(file: file, protocol: protocol));
    }
    return remotes;
  }

  Future<DriveSyncSummary> _syncProjects(Map<String, String> headers) async {
    final localPayload = await _storageService.buildProjectsSyncPayload();
    final remoteFile = await _findDriveFile(_projectsFileName, headers);
    if (remoteFile == null) {
      await _uploadJsonFile(
        fileName: _projectsFileName,
        content: const JsonEncoder.withIndent('  ').convert(localPayload),
        headers: headers,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.projects,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(uploaded: 1);
    }

    final decoded = await _downloadJson(remoteFile.id, headers);
    final remotePayload = decoded is Map<String, dynamic>
        ? decoded
        : {
            'updatedAt': DateTime.fromMillisecondsSinceEpoch(
              0,
              isUtc: true,
            ).toIso8601String(),
            'projects': decoded is List ? decoded : <dynamic>[],
          };

    final remoteUpdatedAt = _payloadUpdatedAt(remotePayload);
    final localUpdatedAt = _payloadUpdatedAt(localPayload);
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      await _storageService.replaceProjectsFromSyncPayload(remotePayload);
      await _storageService.saveSyncBundleState(
        SyncBundleType.projects,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(downloaded: 1);
    }
    if (jsonEncode(remotePayload) != jsonEncode(localPayload)) {
      await _uploadJsonFile(
        fileName: _projectsFileName,
        content: const JsonEncoder.withIndent('  ').convert(localPayload),
        headers: headers,
        existingFileId: remoteFile.id,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.projects,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(uploaded: 1);
    }
    await _storageService.saveSyncBundleState(
      SyncBundleType.projects,
      SyncBundleState.synced,
    );
    return const DriveSyncSummary();
  }

  Future<DriveSyncSummary> _syncCompletedProtocols(
    Map<String, String> headers,
  ) async {
    var downloaded = 0;
    var uploaded = 0;
    final syncTime = DateTime.now();
    final localCompleted = await _storageService.loadCompletedProtocols();
    final remoteCompleted = await _downloadRemoteCompletedProtocols(headers);
    final remoteById = {
      for (final remote in remoteCompleted) remote.id: remote,
    };
    final merged = <CompletedProtocol>[...localCompleted];
    final localIds = localCompleted.map((completed) => completed.id).toSet();

    for (final remote in remoteCompleted) {
      if (localIds.contains(remote.id)) continue;
      merged.add(
        remote.copyWith(
          lastSyncedAt: syncTime,
          syncStatus: ProtocolSyncStatus.synced,
        ),
      );
      downloaded++;
    }

    for (final local in localCompleted) {
      final remote = remoteById[local.id];
      if (remote != null) {
        final resolved = _enrichCompletedProtocol(local, remote).copyWith(
          driveFileId: remote.driveFileId,
          lastSyncedAt: syncTime,
          syncStatus: ProtocolSyncStatus.synced,
        );
        final localIndex = merged.indexWhere((item) => item.id == local.id);
        if ((_completedMetadataDiffers(local, resolved) ||
                local.syncStatus != ProtocolSyncStatus.synced) &&
            localIndex >= 0) {
          merged[localIndex] = resolved;
          downloaded++;
        }
        if (_completedMetadataDiffers(remote, resolved)) {
          final fileId = await _uploadJsonFile(
            fileName: _completedFileName(resolved.id),
            content: const JsonEncoder.withIndent(
              '  ',
            ).convert(resolved.toJson()),
            headers: headers,
            existingFileId: remote.driveFileId,
          );
          if (localIndex >= 0) {
            merged[localIndex] = resolved.copyWith(driveFileId: fileId);
          }
          uploaded++;
        }
        continue;
      }
      final fileId = await _uploadJsonFile(
        fileName: _completedFileName(local.id),
        content: const JsonEncoder.withIndent('  ').convert(local.toJson()),
        headers: headers,
      );
      final localIndex = merged.indexWhere((item) => item.id == local.id);
      if (localIndex >= 0) {
        merged[localIndex] = local.copyWith(
          driveFileId: fileId,
          lastSyncedAt: syncTime,
          syncStatus: ProtocolSyncStatus.synced,
        );
      }
      uploaded++;
    }

    await _storageService.saveCompletedProtocols(merged, markPending: false);
    final active = await _storageService.loadActiveProtocol();
    final running = await _storageService.loadRunningProtocols();
    await ProtocolRunService.instance.replaceFromLegacySync(
      active: active,
      running: running,
      completed: merged,
    );
    await _storageService.saveSyncBundleState(
      SyncBundleType.completedProtocols,
      SyncBundleState.synced,
    );
    return DriveSyncSummary(downloaded: downloaded, uploaded: uploaded);
  }

  CompletedProtocol _enrichCompletedProtocol(
    CompletedProtocol local,
    CompletedProtocol remote,
  ) {
    final localCreator = local.protocol.createdByName?.trim();
    final remoteCreator = remote.protocol.createdByName?.trim();
    return CompletedProtocol(
      id: local.id,
      protocol:
          (localCreator == null || localCreator.isEmpty) &&
              remoteCreator != null &&
              remoteCreator.isNotEmpty
          ? remote.protocol
          : local.protocol,
      notes: local.notes.isEmpty && remote.notes.isNotEmpty
          ? remote.notes
          : local.notes,
      startedAt: local.startedAt ?? remote.startedAt,
      completedAt: local.completedAt,
      completedByName: local.completedByName ?? remote.completedByName,
      driveFileId: local.driveFileId ?? remote.driveFileId,
      lastSyncedAt: local.lastSyncedAt ?? remote.lastSyncedAt,
      syncStatus: local.syncStatus,
    );
  }

  bool _completedMetadataDiffers(
    CompletedProtocol current,
    CompletedProtocol enriched,
  ) {
    return current.startedAt != enriched.startedAt ||
        current.completedByName != enriched.completedByName ||
        current.protocol.createdByName != enriched.protocol.createdByName ||
        (current.notes.isEmpty && enriched.notes.isNotEmpty);
  }

  Future<List<CompletedProtocol>> _downloadRemoteCompletedProtocols(
    Map<String, String> headers,
  ) async {
    final files = await _listAppDataFiles(headers);
    final completed = <CompletedProtocol>[];
    for (final file in files) {
      if (!file.name.startsWith('completed_protocol_') ||
          !file.name.endsWith('.json')) {
        continue;
      }
      final decoded = await _downloadJson(file.id, headers);
      if (decoded is! Map<String, dynamic>) continue;
      completed.add(
        CompletedProtocol.fromJson(
          decoded,
        ).copyWith(driveFileId: file.id, syncStatus: ProtocolSyncStatus.synced),
      );
    }
    return completed;
  }

  Future<DriveSyncSummary> _syncSavedTables(Map<String, String> headers) async {
    var downloaded = 0;
    var uploaded = 0;
    final localTables = await _storageService.loadSavedTables();
    final deletedTableIds = (await _storageService.loadDeletedSavedTableIds())
        .toSet();
    final remoteFile = await _findDriveFile(_savedTablesFileName, headers);
    final remoteTables = remoteFile == null
        ? <ProtocolTable>[]
        : await _downloadSavedTables(remoteFile.id, headers);
    final merged = <ProtocolTable>[...localTables];
    final localIds = localTables.map((table) => table.id).toSet();

    for (final remote in remoteTables) {
      if (deletedTableIds.contains(remote.id)) continue;
      if (localIds.contains(remote.id)) continue;
      merged.add(remote);
      downloaded++;
    }

    final remoteComparable = remoteTables
        .where((table) => !deletedTableIds.contains(table.id))
        .map((table) => table.toJson())
        .toList();
    final mergedComparable = merged.map((table) => table.toJson()).toList();
    final shouldUpload =
        remoteFile == null ||
        deletedTableIds.isNotEmpty ||
        downloaded > 0 ||
        jsonEncode(remoteComparable) != jsonEncode(mergedComparable);
    if (downloaded > 0) {
      await _storageService.saveSavedTables(merged);
    }
    if (shouldUpload) {
      await _uploadJsonFile(
        fileName: _savedTablesFileName,
        content: const JsonEncoder.withIndent(
          '  ',
        ).convert(merged.map((table) => table.toJson()).toList()),
        headers: headers,
        existingFileId: remoteFile?.id,
      );
      if (deletedTableIds.isNotEmpty) {
        await _storageService.saveDeletedSavedTableIds([]);
      }
      uploaded++;
    }

    await _storageService.markSavedTablesSynced();

    return DriveSyncSummary(downloaded: downloaded, uploaded: uploaded);
  }

  Future<List<ProtocolTable>> _downloadSavedTables(
    String fileId,
    Map<String, String> headers,
  ) async {
    final decoded = await _downloadJson(fileId, headers);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ProtocolTable.fromJson)
        .toList();
  }

  Future<DriveSyncSummary> _syncTasks(Map<String, String> headers) async {
    final local = await _taskService.buildSyncPayload();
    final remoteFile = await _findDriveFile(_tasksFileName, headers);
    if (remoteFile == null) {
      await _uploadJsonFile(
        fileName: _tasksFileName,
        content: const JsonEncoder.withIndent('  ').convert(local),
        headers: headers,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.tasks,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(uploaded: 1);
    }

    final decoded = await _downloadJson(remoteFile.id, headers);
    if (decoded is! Map<String, dynamic>) {
      await _uploadJsonFile(
        fileName: _tasksFileName,
        content: const JsonEncoder.withIndent('  ').convert(local),
        headers: headers,
        existingFileId: remoteFile.id,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.tasks,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(uploaded: 1);
    }

    final remoteUpdatedAt = _payloadUpdatedAt(decoded);
    final localUpdatedAt = _payloadUpdatedAt(local);
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      await _taskService.replaceFromSyncPayload(decoded);
      await _storageService.saveSyncBundleState(
        SyncBundleType.tasks,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(downloaded: 1);
    }
    if (jsonEncode(decoded) != jsonEncode(local)) {
      await _uploadJsonFile(
        fileName: _tasksFileName,
        content: const JsonEncoder.withIndent('  ').convert(local),
        headers: headers,
        existingFileId: remoteFile.id,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.tasks,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(uploaded: 1);
    }
    await _storageService.saveSyncBundleState(
      SyncBundleType.tasks,
      SyncBundleState.synced,
    );
    return const DriveSyncSummary();
  }

  Future<DriveSyncSummary> _syncMeasuringTools(
    Map<String, String> headers,
  ) async {
    final local = await _measuringToolService.buildSyncPayload();
    final remoteFile = await _findDriveFile(_measuringToolsFileName, headers);
    if (remoteFile == null) {
      await _uploadJsonFile(
        fileName: _measuringToolsFileName,
        content: const JsonEncoder.withIndent('  ').convert(local),
        headers: headers,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.measuringTools,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(uploaded: 1);
    }

    final decoded = await _downloadJson(remoteFile.id, headers);
    if (decoded is! Map<String, dynamic>) {
      await _uploadJsonFile(
        fileName: _measuringToolsFileName,
        content: const JsonEncoder.withIndent('  ').convert(local),
        headers: headers,
        existingFileId: remoteFile.id,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.measuringTools,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(uploaded: 1);
    }

    final remoteUpdatedAt = _payloadUpdatedAt(decoded);
    final localUpdatedAt = _payloadUpdatedAt(local);
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      await _measuringToolService.replaceFromSyncPayload(decoded);
      await _storageService.saveSyncBundleState(
        SyncBundleType.measuringTools,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(downloaded: 1);
    }
    if (jsonEncode(decoded) != jsonEncode(local)) {
      await _uploadJsonFile(
        fileName: _measuringToolsFileName,
        content: const JsonEncoder.withIndent('  ').convert(local),
        headers: headers,
        existingFileId: remoteFile.id,
      );
      await _storageService.saveSyncBundleState(
        SyncBundleType.measuringTools,
        SyncBundleState.synced,
      );
      return const DriveSyncSummary(uploaded: 1);
    }
    await _storageService.saveSyncBundleState(
      SyncBundleType.measuringTools,
      SyncBundleState.synced,
    );
    return const DriveSyncSummary();
  }

  DateTime _payloadUpdatedAt(Map<String, dynamic> payload) {
    return DateTime.tryParse(payload['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<dynamic> _downloadJson(
    String fileId,
    Map<String, String> headers,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/files/$fileId?alt=media'),
      headers: headers,
    );
    _throwIfFailed(response);
    return jsonDecode(response.body);
  }

  Future<DriveSyncSummary> _syncDeletedProtocols(
    List<DeletedProtocolRecord> records,
    Map<String, String> headers,
  ) async {
    if (records.isEmpty) return const DriveSyncSummary();

    var errors = 0;
    final remaining = <DeletedProtocolRecord>[];
    String? firstError;

    for (final record in records) {
      try {
        await _trashDeletedProtocol(record, headers);
      } catch (e) {
        _logDriveError('trash ${record.protocolId}', e);
        firstError ??= _friendlyError(e);
        remaining.add(record);
        errors++;
      }
    }

    await _storageService.saveDeletedProtocolRecords(remaining);
    return DriveSyncSummary(errors: errors, details: firstError);
  }

  Future<void> _trashDeletedProtocol(
    DeletedProtocolRecord record,
    Map<String, String> headers,
  ) async {
    final fileId = (record.driveFileId?.isNotEmpty ?? false)
        ? record.driveFileId
        : (await _findDriveFile('${record.protocolId}.json', headers))?.id;
    if (fileId == null || fileId.isEmpty) {
      return;
    }

    final response = await http.patch(
      Uri.parse('$_baseUrl/files/$fileId'),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'trashed': true}),
    );
    _throwIfFailed(response);
  }

  Future<List<DriveFileRecord>> _listAppDataFiles(
    Map<String, String> headers,
  ) async {
    final query = Uri.encodeQueryComponent("trashed = false");
    final records = <DriveFileRecord>[];
    String? pageToken;
    do {
      final tokenQuery = pageToken == null
          ? ''
          : '&pageToken=${Uri.encodeQueryComponent(pageToken)}';
      final uri = Uri.parse(
        '$_baseUrl/files?spaces=appDataFolder&q=$query'
        '&fields=nextPageToken,files(id,name,modifiedTime,md5Checksum,size)'
        '&pageSize=1000$tokenQuery',
      );
      final response = await http.get(uri, headers: headers);
      _throwIfFailed(response);

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Drive returned an invalid file list.');
      }
      final files = decoded['files'];
      if (files is! List) {
        throw const FormatException('Drive file list is missing files.');
      }
      records.addAll(
        files
            .whereType<Map<String, dynamic>>()
            .map(DriveFileRecord.fromJson)
            .where((file) => file.id.isNotEmpty && file.name.isNotEmpty),
      );
      pageToken = decoded['nextPageToken']?.toString();
      if (pageToken?.isEmpty ?? false) pageToken = null;
    } while (pageToken != null);
    return records;
  }

  Future<DriveFileRecord?> _findDriveFile(
    String fileName,
    Map<String, String> headers,
  ) async {
    final escapedName = fileName.replaceAll("'", r"\'");
    final query = Uri.encodeQueryComponent(
      "name = '$escapedName' and trashed = false",
    );
    final uri = Uri.parse(
      '$_baseUrl/files?spaces=appDataFolder&q=$query'
      '&fields=files(id,name,modifiedTime,md5Checksum)&pageSize=100',
    );
    final response = await http.get(uri, headers: headers);
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body);
    final files = decoded is Map<String, dynamic> ? decoded['files'] : null;
    if (files is! List || files.isEmpty) return null;
    final matches =
        files
            .whereType<Map<String, dynamic>>()
            .map(DriveFileRecord.fromJson)
            .toList()
          ..sort(_newestFileFirst);
    return matches.firstOrNull;
  }

  Future<String> _uploadJsonFile({
    required String fileName,
    required String content,
    required Map<String, String> headers,
    String? existingFileId,
  }) async {
    final fileId =
        existingFileId ?? (await _findDriveFile(fileName, headers))?.id;
    if (fileId == null || fileId.isEmpty) {
      return _createDriveFile(
        fileName: fileName,
        content: content,
        headers: headers,
      );
    }

    await _updateDriveFile(fileId: fileId, content: content, headers: headers);
    return fileId;
  }

  Future<String> _createDriveFile({
    required String fileName,
    required String content,
    required Map<String, String> headers,
  }) async {
    final boundary = 'protocolflow_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': fileName,
      // appDataFolder keeps protocol JSON private to ProtocolFlow.
      'parents': ['appDataFolder'],
      'mimeType': 'application/json',
    });
    final body =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$content\r\n'
        '--$boundary--';

    final response = await http.post(
      Uri.parse('$_uploadBaseUrl/files?uploadType=multipart&fields=id'),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body);
    return decoded['id'] ?? '';
  }

  Future<void> _updateDriveFile({
    required String fileId,
    required String content,
    required Map<String, String> headers,
  }) async {
    final response = await http.patch(
      Uri.parse('$_uploadBaseUrl/files/$fileId?uploadType=media'),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: content,
    );
    _throwIfFailed(response);
  }

  Future<_ConflictResolution> _resolveLocalAndRemote({
    required Protocol local,
    required RemoteProtocol remote,
    required Map<String, String> headers,
    required DateTime syncTime,
  }) async {
    final remoteProtocol = remote.protocol.copyWith(
      driveFileId: remote.file.id,
    );
    final lastSyncedAt = local.lastSyncedAt;
    final localChanged =
        lastSyncedAt != null && local.updatedAt.isAfter(lastSyncedAt);
    final remoteChanged =
        lastSyncedAt != null && remoteProtocol.updatedAt.isAfter(lastSyncedAt);

    if (localChanged &&
        remoteChanged &&
        local.updatedAt != remoteProtocol.updatedAt) {
      final conflictCopy = _conflictCopy(remoteProtocol);
      final syncedLocal = await uploadProtocol(
        local.copyWith(driveFileId: remote.file.id),
        headers: headers,
      );
      return _ConflictResolution(
        protocols: [syncedLocal, conflictCopy],
        uploaded: 1,
        conflicts: 1,
      );
    }

    if (local.updatedAt.isAfter(remoteProtocol.updatedAt)) {
      final synced = await uploadProtocol(
        local.copyWith(driveFileId: remote.file.id),
        headers: headers,
      );
      return _ConflictResolution(protocols: [synced], uploaded: 1);
    }

    if (remoteProtocol.updatedAt.isAfter(local.updatedAt)) {
      return _ConflictResolution(
        protocols: [
          remoteProtocol.copyWith(
            lastSyncedAt: syncTime,
            syncStatus: ProtocolSyncStatus.synced,
          ),
        ],
        downloaded: 1,
      );
    }

    return _ConflictResolution(
      protocols: [
        local.copyWith(
          driveFileId: remote.file.id,
          lastSyncedAt: syncTime,
          syncStatus: ProtocolSyncStatus.synced,
        ),
      ],
    );
  }

  Protocol _conflictCopy(Protocol protocol) {
    final userInitials = _authService.currentUser?.initials;
    return Protocol(
      id: generateProtocolId(initials: userInitials),
      title: '${protocol.title} (conflict copy)',
      objective: protocol.objective,
      description: protocol.description,
      ownerId: protocol.ownerId,
      projectId: protocol.projectId,
      createdByName: protocol.createdByName,
      createdAt: protocol.createdAt,
      updatedAt: DateTime.now(),
      schemaVersion: protocol.schemaVersion,
      syncStatus: ProtocolSyncStatus.conflict,
      materials: protocol.materials.map((m) => m.copyWith()).toList(),
      samples: List<String>.from(protocol.samples),
      files: List<String>.from(protocol.files),
      steps: protocol.steps.map((s) => s.deepCopy()).toList(),
      tables: protocol.tables.map((t) => t.deepCopy()).toList(),
      additionalData: protocol.additionalData.map((d) => d.deepCopy()).toList(),
      isTemplate: protocol.isTemplate,
    );
  }

  Protocol _withSyncState(Protocol protocol, ProtocolSyncStatus status) {
    return protocol.copyWith(syncStatus: status);
  }

  Future<void> _markUnsyncedProtocols(ProtocolSyncStatus status) async {
    final protocols = await _storageService.loadProtocols();
    await _storageService.saveProtocols(
      protocols
          .map(
            (protocol) => protocol.syncStatus == ProtocolSyncStatus.synced
                ? protocol
                : protocol.copyWith(syncStatus: status),
          )
          .toList(),
    );
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw http.ClientException(
      'Drive request failed (${response.statusCode}): ${response.body}',
      response.request?.url,
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('403') && raw.contains('accessNotConfigured')) {
      return 'Google Drive API is not enabled for this Google Cloud project.';
    }
    if (raw.contains('403') && raw.contains('insufficient')) {
      return 'Drive app data permission was not granted. Sign out/in and approve Drive access.';
    }
    if (raw.contains('401')) {
      return 'Google authorization expired. Sign out/in and try again.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'No internet connection. Local changes were kept.';
    }
    if (raw.length > 180) return '${raw.substring(0, 180)}...';
    return raw;
  }

  void _logDriveError(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('Drive sync $operation failed: $error');
    }
  }
}

class _ConflictResolution {
  final List<Protocol> protocols;
  final int downloaded;
  final int uploaded;
  final int conflicts;

  const _ConflictResolution({
    required this.protocols,
    this.downloaded = 0,
    this.uploaded = 0,
    this.conflicts = 0,
  });
}

class _PreparedSyncPlan {
  final Map<String, String> headers;
  final String deviceId;
  final Map<String, SyncEntityRecord> localAtStart;
  final List<SyncJournal> remoteJournals;
  final Map<String, SyncEntityRecord> ownEntries;
  final SyncMergeResult combined;
  final Set<String> changedKeys;
  final Map<String, SyncEntityRecord> deletionSources;
  final Map<String, String> invalidRemoteReasons;
  final int nextClock;
  final int conflicts;
  final bool journalChanged;
  final String? existingFileId;
  final String fingerprint;

  const _PreparedSyncPlan({
    required this.headers,
    required this.deviceId,
    required this.localAtStart,
    required this.remoteJournals,
    required this.ownEntries,
    required this.combined,
    required this.changedKeys,
    required this.deletionSources,
    required this.invalidRemoteReasons,
    required this.nextClock,
    required this.conflicts,
    required this.journalChanged,
    required this.existingFileId,
    required this.fingerprint,
  });
}
