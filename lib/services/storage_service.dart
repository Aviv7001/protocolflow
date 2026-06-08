import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/completed_protocol.dart';
import '../models/active_protocol.dart';
import '../models/deleted_protocol_record.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';

class StorageService {
  static const String _storageKey = 'completed_protocols_json';
  static const String _activeKey = 'active_protocol_json';
  static const String _runningKey = 'running_protocols_json';
  static const String _libraryKey = 'protocols_library_json';
  static const String _deletedProtocolsKey = 'deleted_protocols_json';
  static const String _savedTablesKey = 'saved_tables_json';
  static const String _deletedSavedTablesKey = 'deleted_saved_tables_json';

  Future<void> saveProtocols(List<Protocol> protocols) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      protocols.map((p) => p.toJson()).toList(),
    );
    await prefs.setString(_libraryKey, jsonString);
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

  Future<void> saveCompletedProtocols(List<CompletedProtocol> protocols) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      protocols.map((p) => p.toJson()).toList(),
    );
    await prefs.setString(_storageKey, jsonString);
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

  Future<void> saveSavedTables(List<ProtocolTable> tables) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      tables.map((table) => table.toJson()).toList(),
    );
    await prefs.setString(_savedTablesKey, jsonString);
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
      tables.insert(0, table);
    } else {
      tables[index] = table;
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
