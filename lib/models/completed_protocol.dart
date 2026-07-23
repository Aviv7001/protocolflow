import 'protocol.dart';
import 'step_note.dart';

class CompletedProtocol {
  final String id;
  final Protocol protocol;
  final List<StepNote> notes;
  final DateTime? startedAt;
  final DateTime completedAt;
  final String? completedByName;

  CompletedProtocol({
    required this.id,
    required this.protocol,
    required this.notes,
    this.startedAt,
    required this.completedAt,
    this.completedByName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'protocol': protocol.toJson(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'completedByName': completedByName,
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
    );
  }
}
