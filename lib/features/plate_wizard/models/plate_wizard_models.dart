enum Direction { auto, horizontal, vertical }

class PlateWellPosition {
  const PlateWellPosition({
    required this.plateIndex,
    required this.row,
    required this.column,
  });

  final int plateIndex;
  final int row;
  final int column;

  String get key => '$plateIndex:$row:$column';

  Map<String, dynamic> toJson() => {
    'plateIndex': plateIndex,
    'row': row,
    'column': column,
  };

  factory PlateWellPosition.fromJson(Map<String, dynamic> json) {
    return PlateWellPosition(
      plateIndex: json['plateIndex'] as int? ?? 0,
      row: json['row'] as int? ?? 0,
      column: json['column'] as int? ?? 0,
    );
  }
}

class SampleVariableSpec {
  const SampleVariableSpec({
    required this.name,
    required this.values,
    required this.direction,
  });

  final String name;
  final List<String> values;
  final Direction direction;

  int get valueCount => values.isEmpty ? 1 : values.length;
}

class PlateWizardInput {
  const PlateWizardInput({
    required this.plateRows,
    required this.plateCols,
    this.plateCount = 1,
    required this.samples,
    this.sampleDirection = Direction.horizontal,
    this.conditionDirection = Direction.horizontal,
    this.dilutionDirection = Direction.vertical,
    this.duplicateDirection = Direction.horizontal,
  });

  final int plateRows;
  final int plateCols;
  final int plateCount;
  final List<SampleSpec> samples;
  final Direction sampleDirection;
  final Direction conditionDirection;
  final Direction dilutionDirection;
  final Direction duplicateDirection;
}

class SampleSpec {
  const SampleSpec({
    required this.name,
    this.variables = const [],
    this.conditions = const [''],
    this.dilutions = const [''],
    required this.duplicates,
    this.sampleDirection = Direction.auto,
    this.duplicateDirection = Direction.auto,
    this.manualWells = const [],
    this.applyToAllPlates = false,
  });

  final String name;
  final List<SampleVariableSpec> variables;
  final List<String> conditions;
  final List<String> dilutions;
  final int duplicates;
  final Direction sampleDirection;
  final Direction duplicateDirection;
  final List<PlateWellPosition> manualWells;
  final bool applyToAllPlates;

  int get wellsPerPlacement => variables.fold<int>(
    duplicates,
    (total, variable) => total * variable.valueCount,
  );

  int requiredWells(int plateCount) =>
      wellsPerPlacement * (applyToAllPlates ? plateCount : 1);
}

class WellContent {
  const WellContent({
    required this.sampleName,
    required this.variableValues,
    required this.duplicateIndex,
  });

  final String sampleName;
  final List<String> variableValues;
  final int duplicateIndex;

  @override
  String toString() {
    return <String>[
      sampleName,
      ...variableValues.where((value) => value.trim().isNotEmpty),
      'Rep ${duplicateIndex + 1}',
    ].join('\n');
  }
}

class PlateLayoutResult {
  const PlateLayoutResult({
    required this.success,
    this.errorMessage,
    this.plates,
  });

  final bool success;
  final String? errorMessage;
  final List<List<List<WellContent?>>>? plates;

  factory PlateLayoutResult.failure(
    String message, {
    List<List<List<WellContent?>>>? plates,
  }) {
    return PlateLayoutResult(
      success: false,
      errorMessage: message,
      plates: plates,
    );
  }
}
