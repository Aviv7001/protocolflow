import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/completed_protocol.dart';
import '../models/deleted_protocol_record.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../utils/protocol_id.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class DriveSyncSummary {
  final int downloaded;
  final int uploaded;
  final int conflicts;
  final int errors;
  final String? details;

  const DriveSyncSummary({
    this.downloaded = 0,
    this.uploaded = 0,
    this.conflicts = 0,
    this.errors = 0,
    this.details,
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

class DriveFileRecord {
  final String id;
  final String name;

  const DriveFileRecord({required this.id, required this.name});

  factory DriveFileRecord.fromJson(Map<String, dynamic> json) {
    return DriveFileRecord(id: json['id'] ?? '', name: json['name'] ?? '');
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

  final AuthService _authService = AuthService.instance;
  final StorageService _storageService = StorageService();

  String _completedFileName(String completedId) {
    return 'completed_protocol_$completedId.json';
  }

  Future<DriveSyncSummary> syncNow({bool promptIfNecessary = false}) async {
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
      return DriveSyncSummary(errors: 1, details: _friendlyError(e));
    }
  }

  Future<Protocol> syncProtocolAfterLocalSave(Protocol protocol) async {
    final headers = await _authHeaders(promptIfNecessary: false);
    if (headers == null) {
      final unsynced = _withSyncState(protocol, ProtocolSyncStatus.modified);
      await _storageService.upsertProtocol(unsynced);
      return unsynced;
    }

    final summary = await syncNow(promptIfNecessary: false);
    final protocols = await _storageService.loadProtocols();
    for (final item in protocols) {
      if (item.id == protocol.id) return item;
    }

    final fallbackStatus = summary.errors > 0
        ? ProtocolSyncStatus.error
        : ProtocolSyncStatus.modified;
    final fallback = _withSyncState(protocol, fallbackStatus);
    await _storageService.upsertProtocol(fallback);
    return fallback;
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

  Future<DriveSyncSummary> _syncCompletedProtocols(
    Map<String, String> headers,
  ) async {
    var downloaded = 0;
    var uploaded = 0;
    final localCompleted = await _storageService.loadCompletedProtocols();
    final remoteCompleted = await _downloadRemoteCompletedProtocols(headers);
    final remoteById = {
      for (final remote in remoteCompleted) remote.id: remote,
    };
    final merged = <CompletedProtocol>[...localCompleted];
    final localIds = localCompleted.map((completed) => completed.id).toSet();

    for (final remote in remoteCompleted) {
      if (localIds.contains(remote.id)) continue;
      merged.add(remote);
      downloaded++;
    }

    for (final local in localCompleted) {
      if (remoteById.containsKey(local.id)) continue;
      await _uploadJsonFile(
        fileName: _completedFileName(local.id),
        content: const JsonEncoder.withIndent('  ').convert(local.toJson()),
        headers: headers,
      );
      uploaded++;
    }

    if (downloaded > 0) {
      await _storageService.saveCompletedProtocols(merged);
    }
    return DriveSyncSummary(downloaded: downloaded, uploaded: uploaded);
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
      completed.add(CompletedProtocol.fromJson(decoded));
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
    final uri = Uri.parse(
      '$_baseUrl/files?spaces=appDataFolder&q=$query'
      '&fields=files(id,name)&pageSize=1000',
    );
    final response = await http.get(uri, headers: headers);
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body);
    final files = decoded is Map<String, dynamic> ? decoded['files'] : null;
    if (files is! List) return [];
    return files
        .whereType<Map<String, dynamic>>()
        .map(DriveFileRecord.fromJson)
        .where((file) => file.id.isNotEmpty && file.name.isNotEmpty)
        .toList();
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
      '&fields=files(id,name)&pageSize=10',
    );
    final response = await http.get(uri, headers: headers);
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body);
    final files = decoded is Map<String, dynamic> ? decoded['files'] : null;
    if (files is! List || files.isEmpty) return null;
    return DriveFileRecord.fromJson(Map<String, dynamic>.from(files.first));
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
