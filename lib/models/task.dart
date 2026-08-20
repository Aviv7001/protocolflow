enum TaskStatus { notStarted, inProgress, completed }

class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? projectId;
  final String? protocolId;
  final String? runId;

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.status = TaskStatus.notStarted,
    required this.createdAt,
    this.completedAt,
    this.projectId,
    this.protocolId,
    this.runId,
  });

  bool get isDone => status == TaskStatus.completed;

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? completedAt,
    String? projectId,
    bool clearProjectId = false,
    String? protocolId,
    String? runId,
    bool clearProtocolId = false,
    bool clearRunId = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      projectId: clearProjectId ? null : projectId ?? this.projectId,
      protocolId: clearProtocolId ? null : protocolId ?? this.protocolId,
      runId: clearRunId ? null : runId ?? this.runId,
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
    'projectId': projectId,
    'protocolId': protocolId,
    'runId': runId,
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
      projectId: json['projectId'] as String?,
      protocolId: json['protocolId'] as String?,
      runId: json['runId'] as String?,
    );
  }
}
