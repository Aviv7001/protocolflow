import 'dart:convert';

import 'protocol_table.dart';
import '../features/lab_math/lab_calculation.dart';
import '../features/measuring_tools/services/transfer_optimizer_service.dart';
import '../features/reagent_mix/services/reagent_mix_calculator_service.dart';

enum ReagentPreparationType { stockDilution, solidSuspension }

class ReagentMixWizard {
  final String title;
  final List<ReagentItem> reagents;
  final double extraVolumePercent;
  final bool autoExtraVolume;

  ReagentMixWizard({
    this.title = 'C1V1 = C2V2 Dilution',
    this.reagents = const [],
    this.extraVolumePercent = 10,
    this.autoExtraVolume = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'reagents': reagents.map((r) => r.toJson()).toList(),
      'extraVolumePercent': extraVolumePercent,
      'autoExtraVolume': autoExtraVolume,
    };
  }

  factory ReagentMixWizard.fromJson(Map<String, dynamic> json) {
    final legacyOverfillFactor = (json['overfillFactor'] as num?)?.toDouble();
    return ReagentMixWizard(
      title: json['title'] ?? 'C1V1 = C2V2 Dilution',
      reagents: (json['reagents'] as List? ?? [])
          .map<ReagentItem>((r) => ReagentItem.fromJson(r))
          .toList(),
      extraVolumePercent: json['extraVolumePercent'] != null
          ? (json['extraVolumePercent'] as num).toDouble()
          : legacyOverfillFactor == null
          ? 10
          : ((legacyOverfillFactor - 1) * 100),
      autoExtraVolume: json['autoExtraVolume'] ?? false,
    );
  }

  ReagentMixWizard copyWith({
    String? title,
    List<ReagentItem>? reagents,
    double? extraVolumePercent,
    bool? autoExtraVolume,
  }) {
    return ReagentMixWizard(
      title: title ?? this.title,
      reagents: reagents ?? this.reagents,
      extraVolumePercent: extraVolumePercent ?? this.extraVolumePercent,
      autoExtraVolume: autoExtraVolume ?? this.autoExtraVolume,
    );
  }

  ProtocolTable generateTable() {
    final headers = [
      'Preparation',
      'Reagent',
      'Solvent',
      'C1',
      'C2',
      'Vol. / Sample',
      '# Samples',
      'V2 (Total)',
      'V1 (from Stock)',
      'Solvent Vol.',
      'Suggested Transfer',
      'Tool',
      'Status',
    ];

    final service = ReagentMixCalculatorService();

    final data = reagents.map((reagent) {
      final input = ReagentMixInput(
        reagentName: reagent.name,
        stockConcentration: reagent.stockConc,
        stockUnit: reagent.stockUnit,
        workingConcentration: reagent.workingConc,
        workingUnit: reagent.workingUnit,
        volumePerTube: reagent.volPerSample,
        volumePerTubeUnit: reagent.volUnit,
        numberOfTubes: reagent.numSamples,
        extraVolumePercent: extraVolumePercent,
        autoExtraVolume: autoExtraVolume,
        molecularWeight: reagent.molecularWeight,
      );

      final result =
          reagent.preparationType == ReagentPreparationType.solidSuspension
          ? service.calculateSuspension(input)
          : service.calculateMix(input);

      if (!result.success) {
        return <dynamic>[
          reagent.preparationType.label,
          reagent.name,
          reagent.solvent,
          'ERR',
          'ERR',
          'ERR',
          reagent.numSamples,
          'ERROR',
          result.errorMessage ?? 'Calc failed',
          '',
          '',
          '',
          '',
        ];
      }

      String formatConc(double value, ConcentrationUnit unit) {
        if (unit == ConcentrationUnit.ratio) {
          return '1:${value.toStringAsFixed(value == value.toInt() ? 0 : 1)}';
        }
        return '$value ${LabCalculation.unitLabel(unit)}';
      }

      return <dynamic>[
        reagent.preparationType.label,
        reagent.name,
        reagent.solvent,
        reagent.preparationType == ReagentPreparationType.solidSuspension
            ? '-'
            : formatConc(reagent.stockConc, reagent.stockUnit),
        formatConc(reagent.workingConc, reagent.workingUnit),
        '${reagent.volPerSample} ${reagent.volUnit.name}',
        reagent.numSamples.toString(),
        result.formattedTotalVolume,
        result.formattedReagentVolume,
        result.formattedSolventVolume,
        _transferLabel(result.reagentTransferEvaluation),
        _toolLabel(result.reagentTransferEvaluation),
        _statusText(
          result.reagentTransferEvaluation,
          result.warnings.isNotEmpty,
          result.suggestions.isNotEmpty,
        ),
      ];
    }).toList();

    return ProtocolTable(
      id: 'reagent_mix_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: TableType.reagentMix,
      columnHeaders: headers,
      rowHeaders: List.generate(reagents.length, (i) => (i + 1).toString()),
      data: data,
      cellColors: List.generate(
        reagents.length,
        (_) => List.generate(headers.length, (_) => ''),
      ),
      metadata: {'wizard_state': jsonEncode(toJson())},
    );
  }

  String _transferLabel(dynamic evaluation) {
    if (evaluation?.transferVolumePerRepeatUl == null) {
      return '-';
    }
    final perRepeat = LabCalculation.formatVolume(
      evaluation.transferVolumePerRepeatUl as double,
      unicodeMicro: true,
    );
    final repeats = evaluation.repeats as int? ?? 1;
    return repeats > 1 ? '$perRepeat x $repeats' : perRepeat;
  }

  String _toolLabel(dynamic evaluation) {
    return evaluation?.recommendedToolName as String? ?? '-';
  }

  String _statusText(
    dynamic evaluation,
    bool hasWarnings,
    bool hasSuggestions,
  ) {
    final status = evaluation?.status;
    final statusName = status is TransferStatus ? status.label : null;
    if (statusName != null && statusName.isNotEmpty) {
      return statusName;
    }
    return [
      if (hasWarnings) 'Warning',
      if (hasSuggestions) 'Suggestion',
    ].join(' ');
  }
}

class ReagentItem {
  final ReagentPreparationType preparationType;
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
    this.preparationType = ReagentPreparationType.stockDilution,
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
      'preparationType': preparationType.name,
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
      preparationType: ReagentPreparationType.values.firstWhere(
        (e) => e.name == json['preparationType'],
        orElse: () => ReagentPreparationType.stockDilution,
      ),
      name: json['name'] ?? '',
      solvent: json['solvent'] ?? '',
      stockConc: (json['stockConc'] ?? 0).toDouble(),
      stockUnit: ConcentrationUnit.values.firstWhere(
        (e) => e.name == json['stockUnit'],
        orElse: () => ConcentrationUnit.ugML,
      ),
      workingConc: (json['workingConc'] ?? 0).toDouble(),
      workingUnit: ConcentrationUnit.values.firstWhere(
        (e) => e.name == json['workingUnit'],
        orElse: () => ConcentrationUnit.ugML,
      ),
      volPerSample: (json['volPerSample'] ?? 0).toDouble(),
      volUnit: VolumeUnit.values.firstWhere(
        (e) => e.name == json['volUnit'],
        orElse: () => VolumeUnit.uL,
      ),
      numSamples: json['numSamples'] ?? 1,
      molecularWeight: json['molecularWeight'],
    );
  }

  ReagentItem copyWith({
    ReagentPreparationType? preparationType,
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
      preparationType: preparationType ?? this.preparationType,
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

extension ReagentPreparationTypeLabel on ReagentPreparationType {
  String get label {
    switch (this) {
      case ReagentPreparationType.stockDilution:
        return 'Stock dilution';
      case ReagentPreparationType.solidSuspension:
        return 'Solid in solvent';
    }
  }
}
