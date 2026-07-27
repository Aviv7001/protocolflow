class MeasuringTool {
  final String id;
  final String category;
  final String toolType;
  final String toolName;
  final String unit;
  final double minVolumeUl;
  final double maxVolumeUl;
  final double incrementUl;
  final double? minMassMg;
  final double? preferredMinMassMg;
  final double? maxMassMg;
  final double? incrementMassMg;
  final int accuracyRank;
  final bool active;

  const MeasuringTool({
    required this.id,
    this.category = 'Liquid',
    required this.toolType,
    required this.toolName,
    this.unit = 'uL',
    required this.minVolumeUl,
    required this.maxVolumeUl,
    required this.incrementUl,
    this.minMassMg,
    this.preferredMinMassMg,
    this.maxMassMg,
    this.incrementMassMg,
    required this.accuracyRank,
    this.active = true,
  });

  bool get isMassTool => category.toLowerCase() == 'solid' || unit == 'mg';

  MeasuringTool copyWith({
    String? id,
    String? category,
    String? toolType,
    String? toolName,
    String? unit,
    double? minVolumeUl,
    double? maxVolumeUl,
    double? incrementUl,
    double? minMassMg,
    double? preferredMinMassMg,
    double? maxMassMg,
    double? incrementMassMg,
    int? accuracyRank,
    bool? active,
  }) {
    return MeasuringTool(
      id: id ?? this.id,
      category: category ?? this.category,
      toolType: toolType ?? this.toolType,
      toolName: toolName ?? this.toolName,
      unit: unit ?? this.unit,
      minVolumeUl: minVolumeUl ?? this.minVolumeUl,
      maxVolumeUl: maxVolumeUl ?? this.maxVolumeUl,
      incrementUl: incrementUl ?? this.incrementUl,
      minMassMg: minMassMg ?? this.minMassMg,
      preferredMinMassMg: preferredMinMassMg ?? this.preferredMinMassMg,
      maxMassMg: maxMassMg ?? this.maxMassMg,
      incrementMassMg: incrementMassMg ?? this.incrementMassMg,
      accuracyRank: accuracyRank ?? this.accuracyRank,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'toolType': toolType,
      'toolName': toolName,
      'unit': unit,
      'minVolumeUl': minVolumeUl,
      'maxVolumeUl': maxVolumeUl,
      'incrementUl': incrementUl,
      'minMassMg': minMassMg,
      'preferredMinMassMg': preferredMinMassMg,
      'maxMassMg': maxMassMg,
      'incrementMassMg': incrementMassMg,
      'accuracyRank': accuracyRank,
      'active': active,
    };
  }

  factory MeasuringTool.fromJson(Map<String, dynamic> json) {
    return MeasuringTool(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'Liquid',
      toolType: json['toolType'] as String? ?? 'Custom',
      toolName: json['toolName'] as String? ?? 'Tool',
      unit: json['unit'] as String? ?? 'uL',
      minVolumeUl: (json['minVolumeUl'] as num?)?.toDouble() ?? 0,
      maxVolumeUl: (json['maxVolumeUl'] as num?)?.toDouble() ?? 0,
      incrementUl: (json['incrementUl'] as num?)?.toDouble() ?? 0,
      minMassMg: (json['minMassMg'] as num?)?.toDouble(),
      preferredMinMassMg: (json['preferredMinMassMg'] as num?)?.toDouble(),
      maxMassMg: (json['maxMassMg'] as num?)?.toDouble(),
      incrementMassMg: (json['incrementMassMg'] as num?)?.toDouble(),
      accuracyRank: (json['accuracyRank'] as num?)?.toInt() ?? 1,
      active: json['active'] as bool? ?? true,
    );
  }
}
