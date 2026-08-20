import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/completed_protocol.dart';
import '../models/active_protocol.dart';
import '../models/deleted_protocol_record.dart';
import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../models/protocol_run.dart';

enum SavedTablesSyncState { synced, pending, error }

enum SyncBundleState { synced, pending, error }

enum SyncBundleType { projects, completedProtocols, tasks, measuringTools }

class StorageService {
  static const String _storageKey = 'completed_protocols_json';
  static const String _activeKey = 'active_protocol_json';
  static const String _runningKey = 'running_protocols_json';
  static const String _protocolRunsKey = 'protocol_runs_json';
  static const String _libraryKey = 'protocols_library_json';
  static const String _projectsKey = 'projects_json';
  static const String _projectsSyncUpdatedAtKey = 'projects_sync_updated_at';
  static const String _deletedProtocolsKey = 'deleted_protocols_json';
  static const String _savedTablesKey = 'saved_tables_json';
  static const String _deletedSavedTablesKey = 'deleted_saved_tables_json';
  static const String _savedTablesSyncStateKey = 'saved_tables_sync_state';
  static const String _projectsSyncStateKey = 'projects_sync_state';
  static const String _completedProtocolsSyncStateKey =
      'completed_protocols_sync_state';
  static const String _tasksSyncStateKey = 'tasks_sync_state';
  static const String _measuringToolsSyncStateKey =
      'measuring_tools_sync_state';

  Future<void> validateLocalSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in <String, String>{
      _libraryKey: 'protocol library',
      _projectsKey: 'projects',
      _storageKey: 'completed protocols',
      _savedTablesKey: 'saved tables',
      _deletedProtocolsKey: 'protocol deletions',
      _deletedSavedTablesKey: 'saved-table deletions',
      _runningKey: 'running protocols',
      _protocolRunsKey: 'protocol runs',
    }.entries) {
      final encoded = prefs.getString(entry.key);
      if (encoded == null) continue;
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is! List) throw const FormatException();
      } catch (_) {
        throw FormatException(
          'Local ${entry.value} data is damaged. Sync was stopped to protect Drive data.',
        );
      }
    }

    final encodedActive = prefs.getString(_activeKey);
    if (encodedActive != null) {
      try {
        if (jsonDecode(encodedActive) is! Map) throw const FormatException();
      } catch (_) {
        throw const FormatException(
          'Local active protocol data is damaged. Sync was stopped to protect Drive data.',
        );
      }
    }
  }

  Future<void> saveProtocols(List<Protocol> protocols) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      protocols.map((p) => p.toJson()).toList(),
    );
    await prefs.setString(_libraryKey, jsonString);
  }

  Future<void> saveProjects(
    List<Project> projects, {
    bool markUpdated = true,
    bool markPending = true,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final sorted = List<Project>.from(projects)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await prefs.setString(
      _projectsKey,
      jsonEncode(sorted.map((project) => project.toJson()).toList()),
    );
    if (markUpdated) {
      await prefs.setString(
        _projectsSyncUpdatedAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
    if (markPending) {
      await saveSyncBundleState(
        SyncBundleType.projects,
        SyncBundleState.pending,
      );
    }
  }

  Future<List<Project>> loadProjects() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_projectsKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final projects =
          jsonList
              .whereType<Map<String, dynamic>>()
              .map(Project.fromJson)
              .where((project) => project.name.trim().isNotEmpty)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      return projects;
    } catch (e) {
      return [];
    }
  }

  Future<Project> upsertProject(Project project) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((existing) => existing.id == project.id);
    if (index == -1) {
      projects.add(project);
    } else {
      projects[index] = project;
    }
    await saveProjects(projects);
    return project;
  }

  Future<void> deleteProject(String projectId) async {
    final projects = await loadProjects();
    projects.removeWhere((project) => project.id == projectId);
    await saveProjects(projects);

    final protocols = await loadProtocols();
    await saveProtocols(
      protocols
          .map(
            (protocol) => protocol.projectId == projectId
                ? protocol.copyWith(projectId: '')
                : protocol,
          )
          .toList(),
    );

    final tables = await loadSavedTables();
    await saveSavedTables(
      tables
          .map(
            (table) => table.projectId == projectId
                ? table.copyWith(clearProjectId: true)
                : table,
          )
          .toList(),
    );
  }

  Future<Map<String, dynamic>> buildProjectsSyncPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final projects = await loadProjects();
    var updatedAt = DateTime.tryParse(
      prefs.getString(_projectsSyncUpdatedAtKey) ?? '',
    );
    if (updatedAt == null) {
      updatedAt = DateTime.now().toUtc();
      await prefs.setString(
        _projectsSyncUpdatedAtKey,
        updatedAt.toIso8601String(),
      );
    }
    return {
      'updatedAt': updatedAt.toIso8601String(),
      'projects': projects.map((project) => project.toJson()).toList(),
    };
  }

  Future<void> replaceProjectsFromSyncPayload(
    Map<String, dynamic> payload,
  ) async {
    final projects = (payload['projects'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Project.fromJson)
        .where((project) => project.name.trim().isNotEmpty)
        .toList();
    await saveProjects(projects, markUpdated: false, markPending: false);
    final prefs = await SharedPreferences.getInstance();
    final updatedAt =
        DateTime.tryParse(payload['updatedAt']?.toString() ?? '') ??
        DateTime.now().toUtc();
    await prefs.setString(
      _projectsSyncUpdatedAtKey,
      updatedAt.toIso8601String(),
    );
  }

  Future<List<Protocol>> loadProtocols() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_libraryKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      var migrated = false;
      final protocols = jsonList.map((j) {
        if (j is Map<String, dynamic>) {
          final hasId = (j['id'] as String?)?.trim().isNotEmpty ?? false;
          final hasSchemaVersion = j.containsKey('schemaVersion');
          final hasCreatedAt = j.containsKey('createdAt');
          final hasUpdatedAt = j.containsKey('updatedAt');
          final hasSyncStatus = j.containsKey('syncStatus');
          if (!hasId ||
              !hasSchemaVersion ||
              !hasCreatedAt ||
              !hasUpdatedAt ||
              !hasSyncStatus) {
            migrated = true;
          }
          return Protocol.fromJson(j);
        }
        migrated = true;
        return Protocol.fromJson(Map<String, dynamic>.from(j));
      }).toList();

      if (migrated) {
        await saveProtocols(protocols);
      }
      return protocols;
    } catch (e) {
      return [];
    }
  }

  Future<void> upsertProtocol(Protocol protocol) async {
    final protocols = await loadProtocols();
    final index = protocols.indexWhere(
      (existing) => existing.id == protocol.id,
    );
    if (index == -1) {
      protocols.add(protocol);
    } else {
      protocols[index] = protocol;
    }
    await saveProtocols(protocols);
  }

  Future<void> deleteProtocol(Protocol protocol) async {
    final protocols = await loadProtocols();
    protocols.removeWhere((existing) => existing.id == protocol.id);
    await saveProtocols(protocols);

    final records = await loadDeletedProtocolRecords();
    final record = DeletedProtocolRecord(
      protocol: protocol,
      deletedAt: DateTime.now(),
      driveFileId: protocol.driveFileId,
    );
    final index = records.indexWhere((item) => item.protocolId == protocol.id);
    if (index == -1) {
      records.add(record);
    } else {
      records[index] = record;
    }
    await saveDeletedProtocolRecords(records);
  }

  Future<void> saveDeletedProtocolRecords(
    List<DeletedProtocolRecord> records,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _deletedProtocolsKey,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }

  Future<List<DeletedProtocolRecord>> loadDeletedProtocolRecords() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_deletedProtocolsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .whereType<Map<String, dynamic>>()
          .map(DeletedProtocolRecord.fromJson)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCompletedProtocols(
    List<CompletedProtocol> protocols, {
    bool markPending = true,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      protocols.map((p) => p.toJson()).toList(),
    );
    await prefs.setString(_storageKey, jsonString);
    if (markPending) {
      await saveSyncBundleState(
        SyncBundleType.completedProtocols,
        SyncBundleState.pending,
      );
    }
  }

  Future<List<CompletedProtocol>> loadCompletedProtocols() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => CompletedProtocol.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveActiveProtocol(ActiveProtocol? protocol) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (protocol == null) {
      await prefs.remove(_activeKey);
    } else {
      final String jsonString = jsonEncode(protocol.toJson());
      await prefs.setString(_activeKey, jsonString);
    }
  }

  Future<ActiveProtocol?> loadActiveProtocol() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_activeKey);

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final dynamic jsonMap = jsonDecode(jsonString);
      return ActiveProtocol.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveRunningProtocols(List<ActiveProtocol> protocols) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      protocols.map((p) => p.toJson()).toList(),
    );
    await prefs.setString(_runningKey, jsonString);
  }

  Future<List<ActiveProtocol>> loadRunningProtocols() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_runningKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => ActiveProtocol.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> hasProtocolRunsStorage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_protocolRunsKey);
  }

  Future<void> saveProtocolRuns(List<ProtocolRun> runs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _protocolRunsKey,
      jsonEncode(runs.map((run) => run.toJson()).toList()),
    );
    await saveSyncBundleState(
      SyncBundleType.completedProtocols,
      SyncBundleState.pending,
    );
  }

  Future<List<ProtocolRun>> loadProtocolRuns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_protocolRunsKey);
      if (encoded == null || encoded.isEmpty) return [];
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ProtocolRun.fromJson)
          .where((run) => run.id.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearPublicationReferences(String publicationId) async {
    if (publicationId.trim().isEmpty) return;

    Protocol clearFromProtocol(Protocol protocol) {
      if (protocol.publication?.publicationId != publicationId) {
        return protocol;
      }
      return protocol.copyWith(
        clearPublication: true,
        syncStatus: ProtocolSyncStatus.modified,
      );
    }

    final protocols = await loadProtocols();
    if (protocols.any(
      (protocol) => protocol.publication?.publicationId == publicationId,
    )) {
      await saveProtocols(protocols.map(clearFromProtocol).toList());
    }

    final completed = await loadCompletedProtocols();
    if (completed.any(
      (item) => item.protocol.publication?.publicationId == publicationId,
    )) {
      await saveCompletedProtocols(
        completed
            .map(
              (item) =>
                  item.protocol.publication?.publicationId == publicationId
                  ? item.copyWith(
                      protocol: clearFromProtocol(item.protocol),
                      syncStatus: ProtocolSyncStatus.modified,
                    )
                  : item,
            )
            .toList(),
      );
    }

    final active = await loadActiveProtocol();
    if (active?.protocol.publication?.publicationId == publicationId) {
      await saveActiveProtocol(
        active!.copyWith(protocol: clearFromProtocol(active.protocol)),
      );
    }

    final running = await loadRunningProtocols();
    if (running.any(
      (item) => item.protocol.publication?.publicationId == publicationId,
    )) {
      await saveRunningProtocols(
        running
            .map(
              (item) =>
                  item.protocol.publication?.publicationId == publicationId
                  ? item.copyWith(protocol: clearFromProtocol(item.protocol))
                  : item,
            )
            .toList(),
      );
    }

    final runs = await loadProtocolRuns();
    if (runs.any(
      (run) => run.protocolSnapshot.publication?.publicationId == publicationId,
    )) {
      await saveProtocolRuns(
        runs
            .map(
              (run) =>
                  run.protocolSnapshot.publication?.publicationId ==
                      publicationId
                  ? run.copyWith(
                      protocolSnapshot: clearFromProtocol(run.protocolSnapshot),
                      syncStatus: ProtocolSyncStatus.modified,
                    )
                  : run,
            )
            .toList(),
      );
    }
  }

  Future<void> saveSavedTables(
    List<ProtocolTable> tables, {
    bool markPending = true,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      tables.map((table) => table.toJson()).toList(),
    );
    await prefs.setString(_savedTablesKey, jsonString);
    if (markPending) {
      await prefs.setString(
        _savedTablesSyncStateKey,
        SavedTablesSyncState.pending.name,
      );
    }
  }

  Future<SavedTablesSyncState> loadSavedTablesSyncState() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_savedTablesSyncStateKey);
    return SavedTablesSyncState.values.firstWhere(
      (state) => state.name == stored,
      orElse: () => SavedTablesSyncState.pending,
    );
  }

  Future<void> markSavedTablesSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedTablesSyncStateKey,
      SavedTablesSyncState.synced.name,
    );
  }

  Future<void> markSavedTablesSyncError() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedTablesSyncStateKey,
      SavedTablesSyncState.error.name,
    );
  }

  Future<SyncBundleState> loadSyncBundleState(SyncBundleType type) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_syncBundleStateKey(type));
    return SyncBundleState.values.firstWhere(
      (state) => state.name == stored,
      orElse: () => SyncBundleState.pending,
    );
  }

  Future<void> saveSyncBundleState(
    SyncBundleType type,
    SyncBundleState state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncBundleStateKey(type), state.name);
  }

  String _syncBundleStateKey(SyncBundleType type) {
    return switch (type) {
      SyncBundleType.projects => _projectsSyncStateKey,
      SyncBundleType.completedProtocols => _completedProtocolsSyncStateKey,
      SyncBundleType.tasks => _tasksSyncStateKey,
      SyncBundleType.measuringTools => _measuringToolsSyncStateKey,
    };
  }

  Future<List<ProtocolTable>> loadSavedTables() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_savedTablesKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => ProtocolTable.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> upsertSavedTable(ProtocolTable table) async {
    final tables = await loadSavedTables();
    final index = tables.indexWhere((existing) => existing.id == table.id);
    if (index == -1) {
      tables.insert(
        0,
        table.createdAt == null
            ? table.copyWith(createdAt: DateTime.now())
            : table,
      );
    } else {
      tables[index] = table.createdAt == null && tables[index].createdAt != null
          ? table.copyWith(createdAt: tables[index].createdAt)
          : table;
    }
    await saveSavedTables(tables);
  }

  Future<void> deleteSavedTable(String tableId) async {
    final tables = await loadSavedTables();
    tables.removeWhere((table) => table.id == tableId);
    await saveSavedTables(tables);

    final deletedIds = await loadDeletedSavedTableIds();
    if (!deletedIds.contains(tableId)) {
      deletedIds.add(tableId);
      await saveDeletedSavedTableIds(deletedIds);
    }
  }

  Future<void> saveDeletedSavedTableIds(List<String> tableIds) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deletedSavedTablesKey, jsonEncode(tableIds));
  }

  Future<List<String>> loadDeletedSavedTableIds() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_deletedSavedTablesKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.whereType<String>().toList();
    } catch (e) {
      return [];
    }
  }
}
