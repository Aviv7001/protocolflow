import 'protocol.dart';
import 'step_note.dart';

class CompletedProtocol {
  final String id;
  final Protocol protocol;
  final List<StepNote> notes;
  final DateTime? startedAt;
  final DateTime completedAt;
  final String? completedByName;
  final String? driveFileId;
  final DateTime? lastSyncedAt;
  final ProtocolSyncStatus syncStatus;

  CompletedProtocol({
    required this.id,
    required this.protocol,
    required this.notes,
    this.startedAt,
    required this.completedAt,
    this.completedByName,
    this.driveFileId,
    this.lastSyncedAt,
    this.syncStatus = ProtocolSyncStatus.localOnly,
  });

  CompletedProtocol copyWith({
    String? id,
    Protocol? protocol,
    List<StepNote>? notes,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completedByName,
    String? driveFileId,
    DateTime? lastSyncedAt,
    ProtocolSyncStatus? syncStatus,
  }) {
    return CompletedProtocol(
      id: id ?? this.id,
      protocol: (protocol ?? this.protocol).deepCopy(),
      notes: (notes ?? this.notes).map((note) => note.deepCopy()).toList(),
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completedByName: completedByName ?? this.completedByName,
      driveFileId: driveFileId ?? this.driveFileId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'protocol': protocol.toJson(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'completedByName': completedByName,
      'driveFileId': driveFileId,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
    };
  }

  factory CompletedProtocol.fromJson(Map<String, dynamic> json) {
    return CompletedProtocol(
      id: json['id'] ?? '',
      protocol: Protocol.fromJson(json['protocol']),
      notes: (json['notes'] as List? ?? [])
          .map((n) => StepNote.fromJson(n))
          .toList(),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt']),
      completedAt: DateTime.parse(
        json['completedAt'] ?? DateTime.now().toIso8601String(),
      ),
      completedByName: json['completedByName'],
      driveFileId: json['driveFileId'],
      lastSyncedAt: _parseDate(json['lastSyncedAt']),
      syncStatus: ProtocolSyncStatus.fromJson(json['syncStatus']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
