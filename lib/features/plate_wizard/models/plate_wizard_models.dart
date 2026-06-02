enum Direction { horizontal, vertical }

class PlateWizardInput {
  final int plateRows;
  final int plateCols;
  final List<SampleSpec> samples;
  final Direction sampleDirection;
  final Direction conditionDirection;
  final Direction dilutionDirection;
  final Direction duplicateDirection;

  PlateWizardInput({
    required this.plateRows,
    required this.plateCols,
    required this.samples,
    required this.sampleDirection,
    required this.conditionDirection,
    required this.dilutionDirection,
    required this.duplicateDirection,
  });
}

class SampleSpec {
  final String name;
  final List<String> conditions;
  final List<String> dilutions;
  final int duplicates;

  SampleSpec({
    required this.name,
    required this.conditions,
    required this.dilutions,
    required this.duplicates,
  });

  int get totalWells => conditions.length * dilutions.length * duplicates;
}

class WellContent {
  final String sampleName;
  final int conditionIndex;
  final String? conditionName;
  final int dilutionIndex;
  final String? dilutionName;
  final int duplicateIndex;

  WellContent({
    required this.sampleName,
    required this.conditionIndex,
    this.conditionName,
    required this.dilutionIndex,
    this.dilutionName,
    required this.duplicateIndex,
  });

  @override
  String toString() {
    String c = conditionName ?? 'C${conditionIndex + 1}';
    String d = dilutionName ?? 'D${dilutionIndex + 1}';
    return '$sampleName\n$c\n$d\nRep ${duplicateIndex + 1}';
  }
}

class PlateLayoutResult {
  final bool success;
  final String? errorMessage;
  final List<List<List<WellContent?>>>? plates;

  PlateLayoutResult({
    required this.success,
    this.errorMessage,
    this.plates,
  });

  factory PlateLayoutResult.failure(String message) {
    return PlateLayoutResult(success: false, errorMessage: message);
  }
}
