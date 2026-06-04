import 'material.dart';

class ProtocolStep {
  final String id;
  final String title;
  final String instructions;
  final List<String> actionItems;
  final List<MaterialItem> materials;
  final int? timerInSeconds;
  final int day;
  final String? phaseName;
  final Map<int, int> actionTimers;
  final List<String> attachedFiles;
  final List<String> tableIds;

  ProtocolStep({
    required this.id,
    required this.title,
    required this.instructions,
    required this.actionItems,
    required this.materials,
    this.timerInSeconds,
    this.day = 1,
    this.phaseName,
    this.actionTimers = const {},
    this.attachedFiles = const [],
    this.tableIds = const [],
  });

  ProtocolStep copyWith({
    String? id,
    String? title,
    String? instructions,
    List<String>? actionItems,
    List<MaterialItem>? materials,
    int? timerInSeconds,
    int? day,
    String? phaseName,
    Map<int, int>? actionTimers,
    List<String>? attachedFiles,
    List<String>? tableIds,
  }) {
    return ProtocolStep(
      id: id ?? this.id,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      actionItems: List<String>.from(actionItems ?? this.actionItems),
      materials: (materials ?? this.materials)
          .map((m) => m.copyWith())
          .toList(),
      timerInSeconds: timerInSeconds ?? this.timerInSeconds,
      day: day ?? this.day,
      phaseName: phaseName ?? this.phaseName,
      actionTimers: Map<int, int>.from(actionTimers ?? this.actionTimers),
      attachedFiles: List<String>.from(attachedFiles ?? this.attachedFiles),
      tableIds: List<String>.from(tableIds ?? this.tableIds),
    );
  }

  ProtocolStep deepCopy() {
    return copyWith();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'instructions': instructions,
      'actionItems': actionItems,
      'materials': materials.map((m) => m.toJson()).toList(),
      'timerInSeconds': timerInSeconds,
      'day': day,
      'phaseName': phaseName,
      'actionTimers': actionTimers.map((k, v) => MapEntry(k.toString(), v)),
      'attachedFiles': attachedFiles,
      'tableIds': tableIds,
    };
  }

  factory ProtocolStep.fromJson(Map<String, dynamic> json) {
    final actionItemsJson = json['actionItems'] ?? json['actions'] ?? [];

    return ProtocolStep(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      instructions: json['instructions'] ?? '',
      actionItems: List<String>.from(actionItemsJson),
      materials: (json['materials'] as List? ?? [])
          .map((m) => MaterialItem.fromJson(m))
          .toList(),
      timerInSeconds: json['timerInSeconds'],
      day: json['day'] ?? 1,
      phaseName: json['phaseName'],
      actionTimers: (json['actionTimers'] as Map? ?? {}).map(
        (k, v) => MapEntry(int.parse(k.toString()), v as int),
      ),
      attachedFiles: List<String>.from(json['attachedFiles'] ?? []),
      tableIds: List<String>.from(json['tableIds'] ?? []),
    );
  }
}
