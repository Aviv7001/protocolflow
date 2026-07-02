class MeasuringTool {
  final String id;
  final String toolType;
  final String toolName;
  final double minVolumeUl;
  final double maxVolumeUl;
  final double incrementUl;
  final int accuracyRank;
  final bool active;

  const MeasuringTool({
    required this.id,
    required this.toolType,
    required this.toolName,
    required this.minVolumeUl,
    required this.maxVolumeUl,
    required this.incrementUl,
    required this.accuracyRank,
    this.active = true,
  });

  MeasuringTool copyWith({
    String? id,
    String? toolType,
    String? toolName,
    double? minVolumeUl,
    double? maxVolumeUl,
    double? incrementUl,
    int? accuracyRank,
    bool? active,
  }) {
    return MeasuringTool(
      id: id ?? this.id,
      toolType: toolType ?? this.toolType,
      toolName: toolName ?? this.toolName,
      minVolumeUl: minVolumeUl ?? this.minVolumeUl,
      maxVolumeUl: maxVolumeUl ?? this.maxVolumeUl,
      incrementUl: incrementUl ?? this.incrementUl,
      accuracyRank: accuracyRank ?? this.accuracyRank,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'toolType': toolType,
      'toolName': toolName,
      'minVolumeUl': minVolumeUl,
      'maxVolumeUl': maxVolumeUl,
      'incrementUl': incrementUl,
      'accuracyRank': accuracyRank,
      'active': active,
    };
  }

  factory MeasuringTool.fromJson(Map<String, dynamic> json) {
    return MeasuringTool(
      id: json['id'] as String? ?? '',
      toolType: json['toolType'] as String? ?? 'Custom',
      toolName: json['toolName'] as String? ?? 'Tool',
      minVolumeUl: (json['minVolumeUl'] as num?)?.toDouble() ?? 0,
      maxVolumeUl: (json['maxVolumeUl'] as num?)?.toDouble() ?? 0,
      incrementUl: (json['incrementUl'] as num?)?.toDouble() ?? 0,
      accuracyRank: (json['accuracyRank'] as num?)?.toInt() ?? 1,
      active: json['active'] as bool? ?? true,
    );
  }
}
