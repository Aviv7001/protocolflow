import 'active_protocol.dart';
import 'completed_protocol.dart';
import 'protocol.dart';
import 'step_note.dart';

enum ProtocolRunStatus {
  running,
  paused,
  completed;

  static ProtocolRunStatus fromJson(Object? value) {
    return ProtocolRunStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ProtocolRunStatus.paused,
    );
  }
}

class ProtocolRun {
  static const currentSchemaVersion = 1;

  const ProtocolRun({
    required this.id,
    required this.protocolId,
    required this.protocolSnapshot,
    required this.status,
    required this.startedAt,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.currentStepIndex = -1,
    this.completedStepIds = const {},
    this.notes = const [],
    this.timerStartTimes = const {},
    this.pausedSeconds = const {},
    this.pausedAt,
    this.completedAt,
    this.completedByName,
    this.driveFileId,
    this.lastSyncedAt,
    this.syncStatus = ProtocolSyncStatus.localOnly,
    this.schemaVersion = currentSchemaVersion,
  });

  final String id;
  final String protocolId;
  final String? projectId;
  final Protocol protocolSnapshot;
  final ProtocolRunStatus status;
  final int currentStepIndex;
  final Set<String> completedStepIds;
  final List<StepNote> notes;
  final Map<String, DateTime> timerStartTimes;
  final Map<String, int> pausedSeconds;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? completedByName;
  final String? driveFileId;
  final DateTime? lastSyncedAt;
  final ProtocolSyncStatus syncStatus;
  final int schemaVersion;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'protocolId': protocolId,
    'projectId': projectId,
    'protocolSnapshot': protocolSnapshot.toJson(),
    'status': status.name,
    'currentStepIndex': currentStepIndex,
    'completedStepIds': completedStepIds.toList(),
    'notes': notes.map((note) => note.toJson()).toList(),
    'timerStartTimes': timerStartTimes.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
    'pausedSeconds': pausedSeconds,
    'startedAt': startedAt.toIso8601String(),
    'pausedAt': pausedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedByName': completedByName,
    'driveFileId': driveFileId,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'syncStatus': syncStatus.name,
  };

  factory ProtocolRun.fromJson(Map<String, dynamic> json) {
    final snapshotJson = json['protocolSnapshot'] ?? json['protocol'];
    final snapshot = Protocol.fromJson(
      Map<String, dynamic>.from(snapshotJson as Map),
    );
    final startedAt = _date(json['startedAt']) ?? DateTime.now();
    return ProtocolRun(
      id: json['id']?.toString() ?? '',
      protocolId: json['protocolId']?.toString() ?? snapshot.id,
      projectId: json['projectId'] as String? ?? snapshot.projectId,
      protocolSnapshot: snapshot,
      status: ProtocolRunStatus.fromJson(json['status']),
      currentStepIndex: json['currentStepIndex'] as int? ?? -1,
      completedStepIds: Set<String>.from(json['completedStepIds'] ?? const []),
      notes: (json['notes'] as List? ?? const [])
          .map((item) => StepNote.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      timerStartTimes: (json['timerStartTimes'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), DateTime.parse(value)),
      ),
      pausedSeconds: (json['pausedSeconds'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value as int),
      ),
      startedAt: startedAt,
      pausedAt: _date(json['pausedAt']),
      completedAt: _date(json['completedAt']),
      createdAt: _date(json['createdAt']) ?? startedAt,
      updatedAt:
          _date(json['updatedAt']) ?? _date(json['completedAt']) ?? startedAt,
      completedByName: json['completedByName'] as String?,
      driveFileId: json['driveFileId'] as String?,
      lastSyncedAt: _date(json['lastSyncedAt']),
      syncStatus: ProtocolSyncStatus.fromJson(json['syncStatus']),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }

  ProtocolRun copyWith({
    Protocol? protocolSnapshot,
    ProtocolRunStatus? status,
    int? currentStepIndex,
    Set<String>? completedStepIds,
    List<StepNote>? notes,
    Map<String, DateTime>? timerStartTimes,
    Map<String, int>? pausedSeconds,
    DateTime? pausedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? completedByName,
    String? driveFileId,
    DateTime? lastSyncedAt,
    ProtocolSyncStatus? syncStatus,
    bool clearPausedAt = false,
    bool clearCompletedAt = false,
  }) {
    return ProtocolRun(
      id: id,
      protocolId: protocolId,
      projectId: projectId,
      protocolSnapshot: (protocolSnapshot ?? this.protocolSnapshot).deepCopy(),
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      completedStepIds: Set.of(completedStepIds ?? this.completedStepIds),
      notes: (notes ?? this.notes).map((note) => note.deepCopy()).toList(),
      timerStartTimes: Map.of(timerStartTimes ?? this.timerStartTimes),
      pausedSeconds: Map.of(pausedSeconds ?? this.pausedSeconds),
      startedAt: startedAt,
      pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedByName: completedByName ?? this.completedByName,
      driveFileId: driveFileId ?? this.driveFileId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      schemaVersion: schemaVersion,
    );
  }

  ActiveProtocol toActiveProtocol() => ActiveProtocol(
    runId: id,
    protocol: protocolSnapshot,
    currentStepIndex: currentStepIndex,
    notes: notes,
    startedAt: startedAt,
    timerStartTimes: timerStartTimes,
    pausedSeconds: pausedSeconds,
    completedStepIds: completedStepIds,
  );

  CompletedProtocol toCompletedProtocol() => CompletedProtocol(
    id: id,
    protocol: protocolSnapshot,
    notes: notes,
    startedAt: startedAt,
    completedAt: completedAt ?? updatedAt,
    completedByName: completedByName,
    driveFileId: driveFileId,
    lastSyncedAt: lastSyncedAt,
    syncStatus: syncStatus,
  );

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
