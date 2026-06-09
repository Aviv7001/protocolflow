class StainingSample {
  final String sampleName;
  final List<String> selectedChainIds;
  final bool includeUnstained;
  final bool includeSingleStain;
  final bool includeSecondaryOnly;
  final bool includeFullStain;

  StainingSample({
    required this.sampleName,
    this.selectedChainIds = const [],
    this.includeUnstained = true,
    this.includeSingleStain = true,
    this.includeSecondaryOnly = true,
    this.includeFullStain = true,
  });

  Map<String, dynamic> toJson() => {
    'sampleName': sampleName,
    'selectedChainIds': selectedChainIds,
    'includeUnstained': includeUnstained,
    'includeSingleStain': includeSingleStain,
    'includeSecondaryOnly': includeSecondaryOnly,
    'includeFullStain': includeFullStain,
  };

  factory StainingSample.fromJson(
    Map<String, dynamic> json, {
    bool defaultIncludeUnstained = true,
    bool defaultIncludeSingleStain = false,
    bool defaultIncludeSecondaryOnly = true,
    bool defaultIncludeFullStain = true,
  }) => StainingSample(
    sampleName: json['sampleName'] ?? '',
    selectedChainIds: List<String>.from(json['selectedChainIds'] ?? []),
    includeUnstained: json['includeUnstained'] ?? defaultIncludeUnstained,
    includeSingleStain: json['includeSingleStain'] ?? defaultIncludeSingleStain,
    includeSecondaryOnly:
        json['includeSecondaryOnly'] ?? defaultIncludeSecondaryOnly,
    includeFullStain: json['includeFullStain'] ?? defaultIncludeFullStain,
  );

  StainingSample copyWith({
    String? sampleName,
    List<String>? selectedChainIds,
    bool? includeUnstained,
    bool? includeSingleStain,
    bool? includeSecondaryOnly,
    bool? includeFullStain,
  }) {
    return StainingSample(
      sampleName: sampleName ?? this.sampleName,
      selectedChainIds: selectedChainIds ?? this.selectedChainIds,
      includeUnstained: includeUnstained ?? this.includeUnstained,
      includeSingleStain: includeSingleStain ?? this.includeSingleStain,
      includeSecondaryOnly: includeSecondaryOnly ?? this.includeSecondaryOnly,
      includeFullStain: includeFullStain ?? this.includeFullStain,
    );
  }
}
