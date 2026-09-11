import 'dart:convert';
import 'protocol_table.dart';
import '../features/plate_wizard/models/plate_wizard_models.dart';
import '../features/plate_wizard/services/sample_layout_service.dart';

class SampleVariable {
  const SampleVariable({
    required this.name,
    this.values = const [''],
    this.direction = Direction.auto,
  });

  final String name;
  final List<String> values;
  final Direction direction;

  Map<String, dynamic> toJson() => {
    'name': name,
    'values': values,
    'direction': direction.name,
  };

  factory SampleVariable.fromJson(Map<String, dynamic> json) {
    return SampleVariable(
      name: json['name']?.toString() ?? 'Variable',
      values: List<String>.from(json['values'] as List? ?? const ['']),
      direction: Direction.values.firstWhere(
        (direction) => direction.name == json['direction'],
        orElse: () => Direction.horizontal,
      ),
    );
  }

  SampleVariable copyWith({
    String? name,
    List<String>? values,
    Direction? direction,
  }) {
    return SampleVariable(
      name: name ?? this.name,
      values: List<String>.from(values ?? this.values),
      direction: direction ?? this.direction,
    );
  }
}

class PlateLayoutWizard {
  final String title;
  final List<TestItem> items;
  final int rows;
  final int columns;
  final int plateCount;
  final Direction sampleDirection;
  final Direction conditionDirection;
  final Direction dilutionDirection;
  final Direction duplicateDirection;
  final List<ProtocolTable> importedTables;

  PlateLayoutWizard({
    this.title = 'Plate Layout',
    this.items = const [],
    this.rows = 8,
    this.columns = 12,
    this.plateCount = 1,
    this.sampleDirection = Direction.horizontal,
    this.conditionDirection = Direction.horizontal,
    this.dilutionDirection = Direction.vertical,
    this.duplicateDirection = Direction.horizontal,
    this.importedTables = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'items': items.map((i) => i.toJson()).toList(),
      'rows': rows,
      'columns': columns,
      'plateCount': plateCount,
      'sampleDirection': sampleDirection.name,
      'conditionDirection': conditionDirection.name,
      'dilutionDirection': dilutionDirection.name,
      'duplicateDirection': duplicateDirection.name,
      'importedTables': importedTables.map((table) => table.toJson()).toList(),
    };
  }

  factory PlateLayoutWizard.fromJson(Map<String, dynamic> json) {
    Direction legacyDirection(String key, Direction fallback) {
      return Direction.values.firstWhere(
        (direction) => direction.name == json[key],
        orElse: () => fallback,
      );
    }

    final legacySampleDirection = legacyDirection(
      'sampleDirection',
      Direction.horizontal,
    );
    final legacyConditionDirection = legacyDirection(
      'conditionDirection',
      Direction.horizontal,
    );
    final legacyDilutionDirection = legacyDirection(
      'dilutionDirection',
      Direction.vertical,
    );
    final legacyDuplicateDirection = legacyDirection(
      'duplicateDirection',
      Direction.horizontal,
    );
    final items = (json['items'] as List? ?? []).map<TestItem>((value) {
      final itemJson = Map<String, dynamic>.from(value as Map);
      var item = TestItem.fromJson(itemJson);
      if (!itemJson.containsKey('sampleDirection')) {
        item = item.copyWith(sampleDirection: legacySampleDirection);
      }
      if (!itemJson.containsKey('duplicateDirection')) {
        item = item.copyWith(duplicateDirection: legacyDuplicateDirection);
      }
      if (!itemJson.containsKey('variables')) {
        item = item.copyWith(
          variables: item.variables.map((variable) {
            final name = variable.name.toLowerCase();
            if (name == 'conditions') {
              return variable.copyWith(direction: legacyConditionDirection);
            }
            if (name == 'dilutions') {
              return variable.copyWith(direction: legacyDilutionDirection);
            }
            return variable;
          }).toList(),
        );
      }
      return item;
    }).toList();
    return PlateLayoutWizard(
      title: json['title'] ?? 'Plate Layout',
      items: items,
      rows: json['rows'] ?? 8,
      columns: json['columns'] ?? 12,
      plateCount: json['plateCount'] ?? 1,
      sampleDirection: legacySampleDirection,
      conditionDirection: legacyConditionDirection,
      dilutionDirection: legacyDilutionDirection,
      duplicateDirection: legacyDuplicateDirection,
      importedTables: (json['importedTables'] as List? ?? [])
          .map<ProtocolTable>((table) => ProtocolTable.fromJson(table))
          .toList(),
    );
  }

  PlateLayoutWizard copyWith({
    String? title,
    List<TestItem>? items,
    int? rows,
    int? columns,
    int? plateCount,
    Direction? sampleDirection,
    Direction? conditionDirection,
    Direction? dilutionDirection,
    Direction? duplicateDirection,
    List<ProtocolTable>? importedTables,
  }) {
    return PlateLayoutWizard(
      title: title ?? this.title,
      items: items ?? this.items,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      plateCount: plateCount ?? this.plateCount,
      sampleDirection: sampleDirection ?? this.sampleDirection,
      conditionDirection: conditionDirection ?? this.conditionDirection,
      dilutionDirection: dilutionDirection ?? this.dilutionDirection,
      duplicateDirection: duplicateDirection ?? this.duplicateDirection,
      importedTables: importedTables ?? this.importedTables,
    );
  }

  List<ProtocolTable> generateTables() {
    if (importedTables.isNotEmpty) {
      return importedTables
          .map(
            (table) => table.copyWith(
              metadata: {
                ...table.metadata,
                'wizard_state': jsonEncode(toJson()),
              },
            ),
          )
          .toList();
    }

    final result = const SampleLayoutService().generate(
      PlateWizardInput(
        plateRows: rows,
        plateCols: columns,
        plateCount: plateCount,
        samples: items.map(_sampleSpec).toList(),
      ),
    );
    final plates =
        result.plates ??
        List.generate(
          plateCount,
          (_) => List.generate(
            rows,
            (_) => List<WellContent?>.filled(columns, null),
          ),
        );

    return List.generate(plateCount, (plateIndex) {
      final plate = plateIndex < plates.length
          ? plates[plateIndex]
          : List.generate(
              rows,
              (_) => List<WellContent?>.filled(columns, null),
            );
      return ProtocolTable(
        id: 'table_${DateTime.now().millisecondsSinceEpoch}_$plateIndex',
        title: plateCount > 1 ? '$title ${plateIndex + 1}' : title,
        type: TableType.plateLayout,
        columnHeaders: List.generate(columns, (index) => '${index + 1}'),
        rowHeaders: List.generate(
          rows,
          (index) => String.fromCharCode(65 + index),
        ),
        data: List.generate(
          rows,
          (row) => List.generate(
            columns,
            (column) => plate[row][column]?.toString() ?? '',
          ),
        ),
        cellColors: List.generate(
          rows,
          (row) => List.generate(columns, (column) {
            final content = plate[row][column];
            if (content == null) return '';
            for (final item in items) {
              if (item.sampleName == content.sampleName) return item.colorHex;
            }
            return '';
          }),
        ),
        metadata: {
          'rows': rows.toString(),
          'columns': columns.toString(),
          'plateIndex': plateIndex.toString(),
          'totalPlates': plateCount.toString(),
          if (!result.success)
            'layoutError': result.errorMessage ?? 'Layout failed.',
          'wizard_state': jsonEncode(toJson()),
        },
      );
    });
  }

  SampleSpec _sampleSpec(TestItem item) {
    return SampleSpec(
      name: item.sampleName,
      variables: item.variables
          .map(
            (variable) => SampleVariableSpec(
              name: variable.name,
              values: variable.values,
              direction: variable.direction,
            ),
          )
          .toList(),
      duplicates: item.duplicates,
      sampleDirection: item.sampleDirection,
      duplicateDirection: item.duplicateDirection,
      manualWells: item.manualWells,
      applyToAllPlates: item.isStandardCurve && item.applyToAllPlates,
    );
  }

  int calculateTotalRequiredWells() {
    int total = 0;
    for (var item in items) {
      total += item.requiredWells(plateCount);
    }
    return total;
  }

  ProtocolTable toProtocolTable() {
    final tables = generateTables();
    if (tables.isEmpty) {
      return ProtocolTable(
        id: 'table_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        type: TableType.plateLayout,
        metadata: {'wizard_state': jsonEncode(toJson())},
      );
    }

    // Use the first plate as the representative data/colors
    // but the wizard_state in metadata ensures the full config is preserved.
    return tables.first.copyWith(
      title: title,
      metadata: {
        ...tables.first.metadata,
        'wizard_state': jsonEncode(toJson()),
        'is_multi_plate': (tables.length > 1).toString(),
        'plate_count': tables.length.toString(),
      },
    );
  }
}

class TestItem {
  final String id;
  final String sampleName;
  final List<SampleVariable> variables;
  final int duplicates;
  final Direction sampleDirection;
  final Direction duplicateDirection;
  final String colorHex;
  final List<PlateWellPosition> manualWells;
  final bool isStandardCurve;
  final bool applyToAllPlates;

  TestItem({
    String? id,
    this.sampleName = '',
    List<SampleVariable>? variables,
    List<String>? conditions,
    List<String>? dilutions,
    this.duplicates = 1,
    this.sampleDirection = Direction.auto,
    this.duplicateDirection = Direction.auto,
    this.colorHex = '#E3F2FD',
    this.manualWells = const [],
    this.isStandardCurve = false,
    this.applyToAllPlates = false,
  }) : id = id ?? 'sample_${DateTime.now().microsecondsSinceEpoch}',
       variables =
           variables ??
           [
             if (conditions != null)
               SampleVariable(name: 'Conditions', values: conditions),
             if (dilutions != null)
               SampleVariable(
                 name: 'Dilutions',
                 values: dilutions,
                 direction: Direction.vertical,
               ),
           ];

  List<String> get conditions => _legacyValues('Conditions');
  List<String> get dilutions => _legacyValues('Dilutions');

  List<String> _legacyValues(String name) {
    for (final variable in variables) {
      if (variable.name.toLowerCase() == name.toLowerCase()) {
        return variable.values.isEmpty ? const [''] : variable.values;
      }
    }
    return const [''];
  }

  int requiredWells(int plateCount) {
    final perPlate = variables.fold<int>(
      duplicates,
      (total, variable) =>
          total * (variable.values.isEmpty ? 1 : variable.values.length),
    );
    return perPlate * (applyToAllPlates ? plateCount : 1);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sampleName': sampleName,
      'conditions': conditions,
      'dilutions': dilutions,
      'variables': variables.map((variable) => variable.toJson()).toList(),
      'duplicates': duplicates,
      'sampleDirection': sampleDirection.name,
      'duplicateDirection': duplicateDirection.name,
      'colorHex': colorHex,
      'manualWells': manualWells.map((well) => well.toJson()).toList(),
      'isStandardCurve': isStandardCurve,
      'applyToAllPlates': applyToAllPlates,
    };
  }

  factory TestItem.fromJson(Map<String, dynamic> json) {
    final variableJson = json['variables'] as List?;
    return TestItem(
      id: json['id'] as String?,
      sampleName: json['sampleName'] ?? '',
      variables: variableJson
          ?.map(
            (variable) => SampleVariable.fromJson(
              Map<String, dynamic>.from(variable as Map),
            ),
          )
          .toList(),
      conditions: variableJson == null
          ? List<String>.from(json['conditions'] ?? [''])
          : null,
      dilutions: variableJson == null
          ? List<String>.from(json['dilutions'] ?? [''])
          : null,
      duplicates: json['duplicates'] ?? 1,
      sampleDirection: Direction.values.firstWhere(
        (direction) => direction.name == json['sampleDirection'],
        orElse: () => Direction.horizontal,
      ),
      duplicateDirection: Direction.values.firstWhere(
        (direction) => direction.name == json['duplicateDirection'],
        orElse: () => Direction.horizontal,
      ),
      colorHex: json['colorHex'] as String? ?? '#E3F2FD',
      manualWells: (json['manualWells'] as List? ?? const [])
          .map(
            (well) => PlateWellPosition.fromJson(
              Map<String, dynamic>.from(well as Map),
            ),
          )
          .toList(),
      isStandardCurve: json['isStandardCurve'] ?? false,
      applyToAllPlates: json['applyToAllPlates'] ?? false,
    );
  }

  TestItem copyWith({
    String? id,
    String? sampleName,
    List<SampleVariable>? variables,
    int? duplicates,
    Direction? sampleDirection,
    Direction? duplicateDirection,
    String? colorHex,
    List<PlateWellPosition>? manualWells,
    bool? isStandardCurve,
    bool? applyToAllPlates,
  }) {
    return TestItem(
      id: id ?? this.id,
      sampleName: sampleName ?? this.sampleName,
      variables: variables ?? this.variables,
      duplicates: duplicates ?? this.duplicates,
      sampleDirection: sampleDirection ?? this.sampleDirection,
      duplicateDirection: duplicateDirection ?? this.duplicateDirection,
      colorHex: colorHex ?? this.colorHex,
      manualWells: manualWells ?? this.manualWells,
      isStandardCurve: isStandardCurve ?? this.isStandardCurve,
      applyToAllPlates: applyToAllPlates ?? this.applyToAllPlates,
    );
  }
}
