import 'dart:convert';
import 'protocol_table.dart';
import '../features/plate_wizard/models/plate_wizard_models.dart';
import '../features/plate_wizard/services/plate_wizard_service.dart';

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
    return PlateLayoutWizard(
      title: json['title'] ?? 'Plate Layout',
      items: (json['items'] as List? ?? [])
          .map<TestItem>((i) => TestItem.fromJson(i))
          .toList(),
      rows: json['rows'] ?? 8,
      columns: json['columns'] ?? 12,
      plateCount: json['plateCount'] ?? 1,
      sampleDirection: Direction.values.firstWhere(
        (e) => e.name == (json['sampleDirection'] ?? 'horizontal'),
        orElse: () => Direction.horizontal,
      ),
      conditionDirection: Direction.values.firstWhere(
        (e) => e.name == (json['conditionDirection'] ?? 'horizontal'),
        orElse: () => Direction.horizontal,
      ),
      dilutionDirection: Direction.values.firstWhere(
        (e) => e.name == (json['dilutionDirection'] ?? 'vertical'),
        orElse: () => Direction.vertical,
      ),
      duplicateDirection: Direction.values.firstWhere(
        (e) => e.name == (json['duplicateDirection'] ?? 'horizontal'),
        orElse: () => Direction.horizontal,
      ),
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

    final List<ProtocolTable> tables = [];
    final service = PlateWizardService();

    // Separate TestItems into global (Standard Curve for all plates) and regular
    final List<SampleSpec> globalSpecs = items
        .where((it) => it.isStandardCurve && it.applyToAllPlates)
        .map(
          (item) => SampleSpec(
            name: item.sampleName,
            conditions: item.conditions,
            dilutions: item.dilutions,
            duplicates: item.duplicates,
          ),
        )
        .toList();

    final List<SampleSpec> regularSpecs = items
        .where((it) => !(it.isStandardCurve && it.applyToAllPlates))
        .map(
          (item) => SampleSpec(
            name: item.sampleName,
            conditions: item.conditions,
            dilutions: item.dilutions,
            duplicates: item.duplicates,
          ),
        )
        .toList();

    int currentRegularIdx = 0;

    final List<String> palette = [
      '#FFEBEE',
      '#E3F2FD',
      '#F1F8E9',
      '#FFF3E0',
      '#F3E5F5',
      '#E0F2F1',
      '#FFFDE7',
      '#FBE9E7',
      '#EFEBE9',
      '#ECEFF1',
    ];

    // Always generate at least plateCount tables to keep UI consistent
    for (int pIdx = 0; pIdx < plateCount; pIdx++) {
      PlateLayoutResult? result;
      int fitCount = 0;

      // Try to fit global items + maximum number of remaining regular samples on the current plate
      for (
        int count = regularSpecs.length - currentRegularIdx;
        count >= 0;
        count--
      ) {
        final currentSamples = [
          ...globalSpecs,
          ...regularSpecs.sublist(currentRegularIdx, currentRegularIdx + count),
        ];

        final input = PlateWizardInput(
          plateRows: rows,
          plateCols: columns,
          samples: currentSamples,
          sampleDirection: sampleDirection,
          conditionDirection: conditionDirection,
          dilutionDirection: dilutionDirection,
          duplicateDirection: duplicateDirection,
        );

        final r = service.generatePlateLayout(input);
        if (r.success) {
          result = r;
          fitCount = count;
          break;
        }
      }

      final localResult = result;

      final List<List<dynamic>> data = List.generate(
        rows,
        (r) => List.generate(columns, (c) {
          if (localResult?.plates != null &&
              localResult!.plates!.isNotEmpty &&
              localResult.plates![0][r][c] != null) {
            return localResult.plates![0][r][c]!.toString();
          }
          return '';
        }),
      );

      final List<List<String>> colors = List.generate(
        rows,
        (r) => List.generate(columns, (c) {
          if (localResult?.plates == null ||
              localResult!.plates!.isEmpty ||
              localResult.plates![0][r][c] == null) {
            return '';
          }
          int globalIdx = items.indexWhere(
            (it) => it.sampleName == localResult.plates![0][r][c]!.sampleName,
          );
          if (globalIdx == -1) return '';
          return palette[globalIdx % palette.length];
        }),
      );

      tables.add(
        ProtocolTable(
          id: 'table_${DateTime.now().millisecondsSinceEpoch}_$pIdx',
          title: plateCount > 1 ? '$title ${pIdx + 1}' : title,
          type: TableType.plateLayout,
          columnHeaders: List.generate(columns, (i) => (i + 1).toString()),
          rowHeaders: List.generate(rows, (i) => String.fromCharCode(65 + i)),
          data: data,
          cellColors: colors,
          metadata: {
            'rows': rows.toString(),
            'columns': columns.toString(),
            'plateIndex': pIdx.toString(),
            'totalPlates': plateCount.toString(),
            'wizard_state': jsonEncode(toJson()),
          },
        ),
      );

      currentRegularIdx += fitCount;
    }

    return tables;
  }

  int calculateTotalRequiredWells() {
    int total = 0;
    for (var item in items) {
      total += item.conditions.length * item.dilutions.length * item.duplicates;
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
  final String sampleName;
  final List<String> conditions;
  final List<String> dilutions;
  final int duplicates;
  final bool isStandardCurve;
  final bool applyToAllPlates;

  TestItem({
    this.sampleName = '',
    this.conditions = const [''],
    this.dilutions = const [''],
    this.duplicates = 1,
    this.isStandardCurve = false,
    this.applyToAllPlates = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'sampleName': sampleName,
      'conditions': conditions,
      'dilutions': dilutions,
      'duplicates': duplicates,
      'isStandardCurve': isStandardCurve,
      'applyToAllPlates': applyToAllPlates,
    };
  }

  factory TestItem.fromJson(Map<String, dynamic> json) {
    return TestItem(
      sampleName: json['sampleName'] ?? '',
      conditions: List<String>.from(json['conditions'] ?? ['']),
      dilutions: List<String>.from(json['dilutions'] ?? ['']),
      duplicates: json['duplicates'] ?? 1,
      isStandardCurve: json['isStandardCurve'] ?? false,
      applyToAllPlates: json['applyToAllPlates'] ?? false,
    );
  }

  TestItem copyWith({
    String? sampleName,
    List<String>? conditions,
    List<String>? dilutions,
    int? duplicates,
    bool? isStandardCurve,
    bool? applyToAllPlates,
  }) {
    return TestItem(
      sampleName: sampleName ?? this.sampleName,
      conditions: conditions ?? this.conditions,
      dilutions: dilutions ?? this.dilutions,
      duplicates: duplicates ?? this.duplicates,
      isStandardCurve: isStandardCurve ?? this.isStandardCurve,
      applyToAllPlates: applyToAllPlates ?? this.applyToAllPlates,
    );
  }
}
