enum StainLevel { primary, secondary, tertiary }

class StainComponent {
  final String name;
  final StainLevel level;

  StainComponent({
    required this.name,
    required this.level,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'level': level.name,
  };

  factory StainComponent.fromJson(Map<String, dynamic> json) => StainComponent(
    name: json['name'] ?? '',
    level: StainLevel.values.firstWhere((e) => e.name == json['level'], orElse: () => StainLevel.primary),
  );

  StainComponent copyWith({String? name, StainLevel? level}) {
    return StainComponent(
      name: name ?? this.name,
      level: level ?? this.level,
    );
  }
}

class StainChain {
  final String id;
  final String chainName; // Added chainName
  final StainComponent primary;
  final StainComponent? secondary;
  final StainComponent? tertiary;
  
  // Metadata at the end of the chain
  final double? excitation;
  final double? emission;
  final String? channel;

  StainChain({
    required this.id,
    this.chainName = '',
    required this.primary,
    this.secondary,
    this.tertiary,
    this.excitation,
    this.emission,
    this.channel,
  });

  List<StainComponent> get components {
    final list = [primary];
    if (secondary != null) list.add(secondary!);
    if (tertiary != null) list.add(tertiary!);
    return list;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chainName': chainName,
    'primary': primary.toJson(),
    'secondary': secondary?.toJson(),
    'tertiary': tertiary?.toJson(),
    'excitation': excitation,
    'emission': emission,
    'channel': channel,
  };

  factory StainChain.fromJson(Map<String, dynamic> json) => StainChain(
    id: json['id'] ?? '',
    chainName: json['chainName'] ?? '',
    primary: StainComponent.fromJson(json['primary']),
    secondary: json['secondary'] != null ? StainComponent.fromJson(json['secondary']) : null,
    tertiary: json['tertiary'] != null ? StainComponent.fromJson(json['tertiary']) : null,
    excitation: (json['excitation'] as num?)?.toDouble(),
    emission: (json['emission'] as num?)?.toDouble(),
    channel: json['channel'],
  );

  StainChain copyWith({
    String? chainName,
    StainComponent? primary,
    StainComponent? secondary,
    bool removeSecondary = false,
    StainComponent? tertiary,
    bool removeTertiary = false,
    double? excitation,
    double? emission,
    String? channel,
  }) {
    return StainChain(
      id: id,
      chainName: chainName ?? this.chainName,
      primary: primary ?? this.primary,
      secondary: removeSecondary ? null : (secondary ?? this.secondary),
      tertiary: removeTertiary ? null : (tertiary ?? this.tertiary),
      excitation: excitation ?? this.excitation,
      emission: emission ?? this.emission,
      channel: channel ?? this.channel,
    );
  }
}
