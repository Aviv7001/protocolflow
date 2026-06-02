class StainingSample {
  final String sampleName;
  final List<String> selectedChainIds;

  StainingSample({
    required this.sampleName,
    this.selectedChainIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'sampleName': sampleName,
    'selectedChainIds': selectedChainIds,
  };

  factory StainingSample.fromJson(Map<String, dynamic> json) => StainingSample(
    sampleName: json['sampleName'] ?? '',
    selectedChainIds: List<String>.from(json['selectedChainIds'] ?? []),
  );

  StainingSample copyWith({
    String? sampleName,
    List<String>? selectedChainIds,
  }) {
    return StainingSample(
      sampleName: sampleName ?? this.sampleName,
      selectedChainIds: selectedChainIds ?? this.selectedChainIds,
    );
  }
}
