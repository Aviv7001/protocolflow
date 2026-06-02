import 'material.dart';
import 'protocol_step.dart';
import 'protocol_table.dart';

class Protocol {
  final String id;
  final String title;
  final String objective;
  final String description;
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
    this.materials = const [],
    this.samples = const [],
    this.files = const [],
    required this.steps,
    this.tables = const [],
    this.isTemplate = false,
  });

  List<ProtocolStep> get sortedSteps {
    return List<ProtocolStep>.from(steps)
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  Protocol copyWith({
    String? id,
    String? title,
    String? objective,
    String? description,
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
      materials: materials ?? this.materials,
      samples: samples ?? this.samples,
      files: files ?? this.files,
      steps: steps ?? this.steps,
      tables: tables ?? this.tables,
      isTemplate: isTemplate ?? this.isTemplate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
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
    return Protocol(
      id: json['id'],
      title: json['title'],
      objective: json['objective'],
      description: json['description'],
      materials: (json['materials'] as List)
          .map((m) => MaterialItem.fromJson(m))
          .toList(),
      samples: List<String>.from(json['samples'] ?? []),
      files: List<String>.from(json['files'] ?? []),
      steps: (json['steps'] as List)
          .map((s) => ProtocolStep.fromJson(s))
          .toList(),
      tables: (json['tables'] as List? ?? [])
          .map((t) => ProtocolTable.fromJson(t))
          .toList(),
      isTemplate: json['isTemplate'] ?? false,
    );
  }
}
