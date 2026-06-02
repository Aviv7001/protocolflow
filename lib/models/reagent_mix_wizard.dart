import 'dart:convert';
import 'protocol_table.dart';
import '../features/reagent_mix/services/reagent_mix_calculator_service.dart';

class ReagentMixWizard {
  final String title;
  final List<ReagentItem> reagents;
  final double overfillFactor;

  ReagentMixWizard({
    this.title = 'Reagent Mix',
    this.reagents = const [],
    this.overfillFactor = 1.1,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'reagents': reagents.map((r) => r.toJson()).toList(),
      'overfillFactor': overfillFactor,
    };
  }

  factory ReagentMixWizard.fromJson(Map<String, dynamic> json) {
    return ReagentMixWizard(
      title: json['title'] ?? 'Reagent Mix',
      reagents: (json['reagents'] as List? ?? [])
          .map<ReagentItem>((r) => ReagentItem.fromJson(r))
          .toList(),
      overfillFactor: (json['overfillFactor'] ?? 1.1).toDouble(),
    );
  }

  ReagentMixWizard copyWith({
    String? title,
    List<ReagentItem>? reagents,
    double? overfillFactor,
  }) {
    return ReagentMixWizard(
      title: title ?? this.title,
      reagents: reagents ?? this.reagents,
      overfillFactor: overfillFactor ?? this.overfillFactor,
    );
  }

  ProtocolTable generateTable() {
    final List<String> headers = [
      'Reagent',
      'Solvent',
      'C1',
      'C2',
      'Vol. / Sample',
      '# Samples',
      'V2 (Total)',
      'V1 (from Stock)',
      'Solvent Vol.'
    ];

    final service = ReagentMixCalculatorService();

    final List<List<dynamic>> data = reagents.map((r) {
      final input = ReagentMixInput(
        reagentName: r.name,
        stockConcentration: r.stockConc,
        stockUnit: r.stockUnit,
        workingConcentration: r.workingConc,
        workingUnit: r.workingUnit,
        volumePerTube: r.volPerSample,
        volumePerTubeUnit: r.volUnit,
        numberOfTubes: r.numSamples,
        molecularWeight: r.molecularWeight,
      );

      final result = service.calculateMix(input);

      if (!result.success) {
        return [r.name, r.solvent, 'ERR', 'ERR', 'ERR', r.numSamples, 'ERROR', result.errorMessage ?? 'Calc failed', ''];
      }

      String formatConc(double val, ConcentrationUnit unit) {
        if (unit == ConcentrationUnit.ratio) return '1:${val.toStringAsFixed(val == val.toInt() ? 0 : 1)}';
        if (unit == ConcentrationUnit.gMol) return '$val g/mol';
        return '$val ${unit.name}';
      }

      return [
        r.name,
        r.solvent,
        formatConc(r.stockConc, r.stockUnit),
        formatConc(r.workingConc, r.workingUnit),
        '${r.volPerSample} ${r.volUnit.name}',
        r.numSamples.toString(),
        result.formattedTotalVolume,
        result.formattedReagentVolume,
        result.formattedSolventVolume,
      ];
    }).toList();

    return ProtocolTable(
      id: 'reagent_mix_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: TableType.reagentMix,
      columnHeaders: headers,
      rowHeaders: List.generate(reagents.length, (i) => (i + 1).toString()),
      data: data,
      cellColors: List.generate(reagents.length, (_) => List.generate(headers.length, (_) => '')),
      metadata: {
        'wizard_state': jsonEncode(toJson()),
      },
    );
  }
}

class ReagentItem {
  final String name;
  final String solvent;
  final double stockConc;
  final ConcentrationUnit stockUnit;
  final double workingConc;
  final ConcentrationUnit workingUnit;
  final double volPerSample;
  final VolumeUnit volUnit;
  final int numSamples;
  final double? molecularWeight;

  ReagentItem({
    this.name = '',
    this.solvent = '',
    this.stockConc = 0,
    this.stockUnit = ConcentrationUnit.ugML,
    this.workingConc = 0,
    this.workingUnit = ConcentrationUnit.ugML,
    this.volPerSample = 0,
    this.volUnit = VolumeUnit.uL,
    this.numSamples = 1,
    this.molecularWeight,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'solvent': solvent,
      'stockConc': stockConc,
      'stockUnit': stockUnit.name,
      'workingConc': workingConc,
      'workingUnit': workingUnit.name,
      'volPerSample': volPerSample,
      'volUnit': volUnit.name,
      'numSamples': numSamples,
      'molecularWeight': molecularWeight,
    };
  }

  factory ReagentItem.fromJson(Map<String, dynamic> json) {
    return ReagentItem(
      name: json['name'] ?? '',
      solvent: json['solvent'] ?? '',
      stockConc: (json['stockConc'] ?? 0).toDouble(),
      stockUnit: ConcentrationUnit.values.firstWhere((e) => e.name == json['stockUnit'], orElse: () => ConcentrationUnit.ugML),
      workingConc: (json['workingConc'] ?? 0).toDouble(),
      workingUnit: ConcentrationUnit.values.firstWhere((e) => e.name == json['workingUnit'], orElse: () => ConcentrationUnit.ugML),
      volPerSample: (json['volPerSample'] ?? 0).toDouble(),
      volUnit: VolumeUnit.values.firstWhere((e) => e.name == json['volUnit'], orElse: () => VolumeUnit.uL),
      numSamples: json['numSamples'] ?? 1,
      molecularWeight: json['molecularWeight'],
    );
  }

  ReagentItem copyWith({
    String? name,
    String? solvent,
    double? stockConc,
    ConcentrationUnit? stockUnit,
    double? workingConc,
    ConcentrationUnit? workingUnit,
    double? volPerSample,
    VolumeUnit? volUnit,
    int? numSamples,
    double? molecularWeight,
  }) {
    return ReagentItem(
      name: name ?? this.name,
      solvent: solvent ?? this.solvent,
      stockConc: stockConc ?? this.stockConc,
      stockUnit: stockUnit ?? this.stockUnit,
      workingConc: workingConc ?? this.workingConc,
      workingUnit: workingUnit ?? this.workingUnit,
      volPerSample: volPerSample ?? this.volPerSample,
      volUnit: volUnit ?? this.volUnit,
      numSamples: numSamples ?? this.numSamples,
      molecularWeight: molecularWeight ?? this.molecularWeight,
    );
  }
}
