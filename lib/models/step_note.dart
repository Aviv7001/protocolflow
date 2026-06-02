class StepNote {
  final String id;
  final String stepId;
  final String note;
  final List<String> photoPaths;
  final DateTime createdAt;

  StepNote({
    required this.id,
    required this.stepId,
    required this.note,
    this.photoPaths = const [],
    required this.createdAt,
  });

  StepNote copyWith({
    String? id,
    String? stepId,
    String? note,
    List<String>? photoPaths,
    DateTime? createdAt,
  }) {
    return StepNote(
      id: id ?? this.id,
      stepId: stepId ?? this.stepId,
      note: note ?? this.note,
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stepId': stepId,
      'note': note,
      'photoPaths': photoPaths,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StepNote.fromJson(Map<String, dynamic> json) {
    return StepNote(
      id: json['id'],
      stepId: json['stepId'],
      note: json['note'],
      photoPaths: List<String>.from(json['photoPaths'] ?? (json['photoPath'] != null ? [json['photoPath']] : [])),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
