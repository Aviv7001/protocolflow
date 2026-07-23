class Project {
  final String id;
  final String name;
  final String description;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    this.colorValue = 0xFF156F7A,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Project copyWith({
    String? id,
    String? name,
    String? description,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final id = json['id']?.toString().trim();
    return Project(
      id: id == null || id.isEmpty
          ? 'project_${DateTime.now().microsecondsSinceEpoch}'
          : id,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      colorValue: _parseColor(json['colorValue']),
      createdAt: _parseDate(json['createdAt']) ?? now,
      updatedAt: _parseDate(json['updatedAt']) ?? now,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static int _parseColor(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ??
          int.tryParse(value, radix: 16) ??
          0xFF156F7A;
    }
    return 0xFF156F7A;
  }
}
