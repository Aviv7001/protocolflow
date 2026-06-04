import 'protocol.dart';
import 'step_note.dart';

class CompletedProtocol {
  final String id;
  final Protocol protocol;
  final List<StepNote> notes;
  final DateTime completedAt;

  CompletedProtocol({
    required this.id,
    required this.protocol,
    required this.notes,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'protocol': protocol.toJson(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory CompletedProtocol.fromJson(Map<String, dynamic> json) {
    return CompletedProtocol(
      id: json['id'] ?? '',
      protocol: Protocol.fromJson(json['protocol']),
      notes: (json['notes'] as List? ?? [])
          .map((n) => StepNote.fromJson(n))
          .toList(),
      completedAt: DateTime.parse(
        json['completedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
