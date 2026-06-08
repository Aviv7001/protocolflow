import 'material.dart';
import 'protocol_step.dart';
import 'protocol_table.dart';
import '../utils/protocol_id.dart';

enum ProtocolSyncStatus {
  localOnly,
  synced,
  modified,
  conflict,
  error;

  static ProtocolSyncStatus fromJson(dynamic value) {
    if (value is String) {
      for (final status in ProtocolSyncStatus.values) {
        if (status.name == value) return status;
      }
    }
    return ProtocolSyncStatus.localOnly;
  }
}

class Protocol {
  static const int currentSchemaVersion = 1;

  final String id;
  final String title;
  final String objective;
  final String description;
  final String? ownerId;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final String? driveFileId;
  final DateTime? lastSyncedAt;
  final ProtocolSyncStatus syncStatus;
  final List<MaterialItem> materials;
  final List<String> samples;
  final List<String> files;
  final List<ProtocolStep> steps;
  final List<ProtocolTable> tables;
  final bool isTemplate;

  Protocol({
    required this.id,
    required this.title,
    required this.objective,
    required this.description,
    this.ownerId,
    this.createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.schemaVersion = currentSchemaVersion,
    this.driveFileId,
    this.lastSyncedAt,
    this.syncStatus = ProtocolSyncStatus.localOnly,
    this.materials = const [],
    this.samples = const [],
    this.files = const [],
    required this.steps,
    this.tables = const [],
    this.isTemplate = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  List<ProtocolStep> get sortedSteps {
    return List<ProtocolStep>.from(steps)
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  Protocol copyWith({
    String? id,
    String? title,
    String? objective,
    String? description,
    String? ownerId,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
    String? driveFileId,
    DateTime? lastSyncedAt,
    ProtocolSyncStatus? syncStatus,
    List<MaterialItem>? materials,
    List<String>? samples,
    List<String>? files,
    List<ProtocolStep>? steps,
    List<ProtocolTable>? tables,
    bool? isTemplate,
  }) {
    return Protocol(
      id: id ?? this.id,
      title: title ?? this.title,
      objective: objective ?? this.objective,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      driveFileId: driveFileId ?? this.driveFileId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      materials: (materials ?? this.materials)
          .map((m) => m.copyWith())
          .toList(),
      samples: List<String>.from(samples ?? this.samples),
      files: List<String>.from(files ?? this.files),
      steps: (steps ?? this.steps).map((s) => s.deepCopy()).toList(),
      tables: (tables ?? this.tables).map((t) => t.deepCopy()).toList(),
      isTemplate: isTemplate ?? this.isTemplate,
    );
  }

  Protocol deepCopy() {
    return copyWith();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': title,
      'title': title,
      // Drive sync will use ownerId + protocolId to scope remote ownership.
      'ownerId': ownerId,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'schemaVersion': schemaVersion,
      'protocolId': id,
      'driveFileId': driveFileId,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
      'objective': objective,
      'description': description,
      'materials': materials.map((m) => m.toJson()).toList(),
      'samples': samples,
      'files': files,
      'steps': steps.map((s) => s.toJson()).toList(),
      'tables': tables.map((t) => t.toJson()).toList(),
      'isTemplate': isTemplate,
    };
  }

  factory Protocol.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim();
    final now = DateTime.now();
    return Protocol(
      id: id == null || id.isEmpty ? generateProtocolId() : id,
      title: json['title'] ?? json['name'] ?? '',
      objective: json['objective'] ?? '',
      description: json['description'] ?? '',
      ownerId: json['ownerId'],
      createdByName: json['createdByName'],
      createdAt: _parseDate(json['createdAt']) ?? now,
      updatedAt: _parseDate(json['updatedAt']) ?? now,
      schemaVersion: json['schemaVersion'] ?? currentSchemaVersion,
      driveFileId: json['driveFileId'],
      lastSyncedAt: _parseDate(json['lastSyncedAt']),
      syncStatus: ProtocolSyncStatus.fromJson(json['syncStatus']),
      materials: (json['materials'] as List? ?? [])
          .map((m) => MaterialItem.fromJson(m))
          .toList(),
      samples: List<String>.from(json['samples'] ?? []),
      files: List<String>.from(json['files'] ?? []),
      steps: (json['steps'] as List? ?? [])
          .map((s) => ProtocolStep.fromJson(s))
          .toList(),
      tables: (json['tables'] as List? ?? [])
          .map((t) => ProtocolTable.fromJson(t))
          .toList(),
      isTemplate: json['isTemplate'] ?? false,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
