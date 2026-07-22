enum TaskStatus { notStarted, inProgress, completed }

class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.status = TaskStatus.notStarted,
    required this.createdAt,
    this.completedAt,
  });

  bool get isDone => status == TaskStatus.completed;

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status.name,
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    final status = TaskStatus.values.where((value) {
      return value.name == statusName;
    }).firstOrNull;

    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status:
          status ??
          ((json['isDone'] ?? false)
              ? TaskStatus.completed
              : TaskStatus.notStarted),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}
