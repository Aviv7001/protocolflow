import 'dart:convert';

class SyncEntityRecord {
  final String entityType;
  final String entityId;
  final int clock;
  final String deviceId;
  final bool deleted;
  final Map<String, dynamic>? data;

  const SyncEntityRecord({
    required this.entityType,
    required this.entityId,
    required this.clock,
    required this.deviceId,
    this.deleted = false,
    this.data,
  });

  String get key => '$entityType::$entityId';

  Map<String, dynamic> toJson() => {
    'entityType': entityType,
    'entityId': entityId,
    'clock': clock,
    'deviceId': deviceId,
    'deleted': deleted,
    if (!deleted) 'data': data,
  };

  factory SyncEntityRecord.fromJson(Map<String, dynamic> json) {
    final entityType = json['entityType']?.toString().trim() ?? '';
    final entityId = json['entityId']?.toString().trim() ?? '';
    final deviceId = json['deviceId']?.toString().trim() ?? '';
    final clock = (json['clock'] as num?)?.toInt() ?? -1;
    if (entityType.isEmpty ||
        entityId.isEmpty ||
        deviceId.isEmpty ||
        clock < 0) {
      throw const FormatException('Invalid sync journal record.');
    }
    final deleted = json['deleted'] == true;
    final rawData = json['data'];
    if (!deleted && rawData is! Map) {
      throw const FormatException('Live sync record is missing data.');
    }
    return SyncEntityRecord(
      entityType: entityType,
      entityId: entityId,
      clock: clock,
      deviceId: deviceId,
      deleted: deleted,
      data: deleted ? null : Map<String, dynamic>.from(rawData as Map),
    );
  }

  bool hasSameValue(SyncEntityRecord other) {
    return deleted == other.deleted &&
        _canonicalJson(data) == _canonicalJson(other.data);
  }
}

class SyncJournal {
  static const int currentSchemaVersion = 2;
  static const String kind = 'protocolflowSyncJournal';

  final String deviceId;
  final Map<String, SyncEntityRecord> entries;

  const SyncJournal({required this.deviceId, required this.entries});

  int get maxClock => entries.values.fold<int>(
    0,
    (maximum, record) => record.clock > maximum ? record.clock : maximum,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'schemaVersion': currentSchemaVersion,
    'deviceId': deviceId,
    'entries': entries.values.map((entry) => entry.toJson()).toList(),
  };

  factory SyncJournal.fromJson(Map<String, dynamic> json) {
    if (json['kind'] != kind || json['schemaVersion'] != currentSchemaVersion) {
      throw const FormatException('Unsupported sync journal.');
    }
    final deviceId = json['deviceId']?.toString().trim() ?? '';
    if (deviceId.isEmpty) {
      throw const FormatException('Sync journal has no device ID.');
    }
    final rawEntries = json['entries'];
    if (rawEntries is! List) {
      throw const FormatException('Sync journal entries are invalid.');
    }
    final entries = <String, SyncEntityRecord>{};
    for (final raw in rawEntries) {
      if (raw is! Map) {
        throw const FormatException('Sync journal contains an invalid entry.');
      }
      final record = SyncEntityRecord.fromJson(Map<String, dynamic>.from(raw));
      final existing = entries[record.key];
      if (existing == null || compareSyncVersions(record, existing) > 0) {
        entries[record.key] = record;
      }
    }
    return SyncJournal(deviceId: deviceId, entries: entries);
  }
}

class SyncMergeResult {
  final Map<String, SyncEntityRecord> winners;
  final List<SyncRecordConflict> conflicts;

  const SyncMergeResult({required this.winners, required this.conflicts});
}

class SyncRecordConflict {
  final SyncEntityRecord winner;
  final SyncEntityRecord loser;

  const SyncRecordConflict({required this.winner, required this.loser});
}

SyncMergeResult mergeSyncJournals(Iterable<SyncJournal> journals) {
  final winners = <String, SyncEntityRecord>{};
  final conflicts = <SyncRecordConflict>[];
  for (final journal in journals) {
    for (final candidate in journal.entries.values) {
      final current = winners[candidate.key];
      if (current == null) {
        winners[candidate.key] = candidate;
        continue;
      }
      final comparison = compareSyncVersions(candidate, current);
      final winner = comparison > 0 ? candidate : current;
      final loser = comparison > 0 ? current : candidate;
      winners[candidate.key] = winner;
      if (candidate.clock == current.clock &&
          !candidate.hasSameValue(current)) {
        conflicts.add(SyncRecordConflict(winner: winner, loser: loser));
      }
    }
  }
  return SyncMergeResult(winners: winners, conflicts: conflicts);
}

int compareSyncVersions(SyncEntityRecord left, SyncEntityRecord right) {
  final byClock = left.clock.compareTo(right.clock);
  if (byClock != 0) return byClock;
  return left.deviceId.compareTo(right.deviceId);
}

String syncDataHash(Map<String, dynamic>? data) => _canonicalJson(data);

String _canonicalJson(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
