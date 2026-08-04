import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'sync_journal.dart';

class SyncJournalStore {
  static const String _deviceIdKey = 'drive_sync_device_id_v2';
  static const String _localJournalKey = 'drive_sync_local_journal_v2';
  static const String _baselineKey = 'drive_sync_baseline_v2';
  static const String _driveFileIdKey = 'drive_sync_journal_file_id_v2';

  Future<String> loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    final created =
        'device_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_$random';
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  Future<SyncJournal> loadLocalJournal(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_localJournalKey);
    if (encoded == null || encoded.isEmpty) {
      return SyncJournal(deviceId: deviceId, entries: const {});
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const FormatException();
      final journal = SyncJournal.fromJson(Map<String, dynamic>.from(decoded));
      if (journal.deviceId != deviceId) throw const FormatException();
      return journal;
    } catch (_) {
      throw const FormatException('The local sync journal is damaged.');
    }
  }

  Future<void> saveLocalJournal(SyncJournal journal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localJournalKey, jsonEncode(journal.toJson()));
  }

  Future<Map<String, SyncEntityRecord>> loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_baselineKey);
    if (encoded == null || encoded.isEmpty) return {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) throw const FormatException();
      final records = <String, SyncEntityRecord>{};
      for (final raw in decoded) {
        if (raw is! Map) throw const FormatException();
        final record = SyncEntityRecord.fromJson(
          Map<String, dynamic>.from(raw),
        );
        records[record.key] = record;
      }
      return records;
    } catch (_) {
      throw const FormatException('The local sync baseline is damaged.');
    }
  }

  Future<void> saveBaseline(Map<String, SyncEntityRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _baselineKey,
      jsonEncode(records.values.map((record) => record.toJson()).toList()),
    );
  }

  Future<String?> loadDriveFileId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_driveFileIdKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveDriveFileId(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driveFileIdKey, fileId);
  }
}
