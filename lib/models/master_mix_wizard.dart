import 'dart:convert';

import 'protocol_table.dart';
import '../features/lab_math/lab_calculation.dart';
import '../features/measuring_tools/services/transfer_optimizer_service.dart';
import '../features/master_mix/services/master_mix_calculator_service.dart';

class MasterMixWizard {
  final String mixName;
  final double finalVolume;
  final VolumeUnit finalVolumeUnit;
  final double extraVolumePercent;
  final bool autoExtraVolume;
  final String baseSolventName;
  final List<MasterMixReagentItem> reagents;

  MasterMixWizard({
    this.mixName = 'New Master Mix',
    this.finalVolume = 500,
    this.finalVolumeUnit = VolumeUnit.uL,
    this.extraVolumePercent = 10,
    this.autoExtraVolume = false,
    this.baseSolventName = 'Water',
    this.reagents = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'mixName': mixName,
      'finalVolume': finalVolume,
      'finalVolumeUnit': finalVolumeUnit.name,
      'extraVolumePercent': extraVolumePercent,
      'autoExtraVolume': autoExtraVolume,
      'baseSolventName': baseSolventName,
      'reagents': reagents.map((r) => r.toJson()).toList(),
    };
  }

  factory MasterMixWizard.fromJson(Map<String, dynamic> json) {
    return MasterMixWizard(
      mixName: json['mixName'] ?? 'New Master Mix',
      finalVolume: (json['finalVolume'] ?? 500).toDouble(),
      finalVolumeUnit: VolumeUnit.values.firstWhere(
        (e) => e.name == json['finalVolumeUnit'],
        orElse: () => VolumeUnit.uL,
      ),
      extraVolumePercent: (json['extraVolumePercent'] ?? 10).toDouble(),
      autoExtraVolume: json['autoExtraVolume'] ?? false,
      baseSolventName: json['baseSolventName'] ?? 'Water',
      reagents: (json['reagents'] as List? ?? [])
          .map<MasterMixReagentItem>((r) => MasterMixReagentItem.fromJson(r))
          .toList(),
    );
  }

  MasterMixWizard copyWith({
    String? mixName,
    double? finalVolume,
    VolumeUnit? finalVolumeUnit,
    double? extraVolumePercent,
    bool? autoExtraVolume,
    String? baseSolventName,
    List<MasterMixReagentItem>? reagents,
  }) {
    return MasterMixWizard(
      mixName: mixName ?? this.mixName,
      finalVolume: finalVolume ?? this.finalVolume,
      finalVolumeUnit: finalVolumeUnit ?? this.finalVolumeUnit,
      extraVolumePercent: extraVolumePercent ?? this.extraVolumePercent,
      autoExtraVolume: autoExtraVolume ?? this.autoExtraVolume,
      baseSolventName: baseSolventName ?? this.baseSolventName,
      reagents: reagents ?? this.reagents,
    );
  }

  ProtocolTable generateTable() {
    final service = MasterMixCalculatorService();
    final input = MasterMixInput(
      mixName: mixName,
      finalVolume: finalVolume,
      finalVolumeUnit: finalVolumeUnit,
      extraVolumePercent: extraVolumePercent,
      autoExtraVolume: autoExtraVolume,
      baseSolventName: baseSolventName,
      reagents: reagents.map((r) => r.toInput()).toList(),
    );

    final result = service.calculateMasterMix(input);

    final headers = [
      'Reagent name',
      'Stock conc',
      'final conc',
      'final volume',
      'Suggested transfer',
      'Tool',
      'Status',
    ];

    final data = <List<dynamic>>[];

    if (result.success) {
      for (final reagent in result.reagentResults) {
        data.add([
          reagent.reagentName,
          reagent.formattedStockConcentration,
          reagent.formattedFinalConcentration,
          reagent.formattedReagentVolume,
          _transferLabel(reagent.transferEvaluation),
          _toolLabel(reagent.transferEvaluation),
          _statusText(
            reagent.transferEvaluation,
            reagent.warnings.isNotEmpty,
            reagent.suggestions.isNotEmpty,
          ),
        ]);
      }
      data.add([
        baseSolventName,
        '-',
        '-',
        result.formattedBaseSolventVolume,
        _transferLabel(result.solventTransferEvaluation),
        _toolLabel(result.solventTransferEvaluation),
        '',
      ]);
      data.add([
        'Total',
        '-',
        '-',
        result.formattedOptimizedFinalVolume,
        '-',
        '-',
        '',
      ]);
    } else {
      data.add([
        'Error',
        result.errorMessage ?? 'Calculation failed',
        '-',
        '-',
        '-',
        '-',
        '',
      ]);
    }

    return ProtocolTable(
      id: 'master_mix_${DateTime.now().millisecondsSinceEpoch}',
      title: mixName,
      type: TableType.masterMix,
      columnHeaders: headers,
      rowHeaders: List.generate(data.length, (i) => (i + 1).toString()),
      data: data,
      cellColors: List.generate(
        data.length,
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

class MasterMixReagentItem {
  final String name;
  final double stockConc;
  final ConcentrationUnit stockUnit;
  final double finalConc;
  final ConcentrationUnit finalUnit;
  final double? mw;

  MasterMixReagentItem({
    this.name = '',
    this.stockConc = 0,
    this.stockUnit = ConcentrationUnit.mM,
    this.finalConc = 0,
    this.finalUnit = ConcentrationUnit.uM,
    this.mw,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'stockConc': stockConc,
      'stockUnit': stockUnit.name,
      'finalConc': finalConc,
      'finalUnit': finalUnit.name,
      'mw': mw,
    };
  }

  factory MasterMixReagentItem.fromJson(Map<String, dynamic> json) {
    return MasterMixReagentItem(
      name: json['name'] ?? '',
      stockConc: (json['stockConc'] ?? 0).toDouble(),
      stockUnit: ConcentrationUnit.values.firstWhere(
        (e) => e.name == json['stockUnit'],
        orElse: () => ConcentrationUnit.mM,
      ),
      finalConc: (json['finalConc'] ?? 0).toDouble(),
      finalUnit: ConcentrationUnit.values.firstWhere(
        (e) => e.name == json['finalUnit'],
        orElse: () => ConcentrationUnit.uM,
      ),
      mw: json['mw'] != null ? (json['mw'] as num).toDouble() : null,
    );
  }

  MasterMixReagentItem copyWith({
    String? name,
    double? stockConc,
    ConcentrationUnit? stockUnit,
    double? finalConc,
    ConcentrationUnit? finalUnit,
    double? mw,
  }) {
    return MasterMixReagentItem(
      name: name ?? this.name,
      stockConc: stockConc ?? this.stockConc,
      stockUnit: stockUnit ?? this.stockUnit,
      finalConc: finalConc ?? this.finalConc,
      finalUnit: finalUnit ?? this.finalUnit,
      mw: mw ?? this.mw,
    );
  }

  MasterMixReagentInput toInput() {
    return MasterMixReagentInput(
      reagentName: name,
      stockConcentration: stockConc,
      stockConcentrationUnit: stockUnit,
      finalConcentration: finalConc,
      finalConcentrationUnit: finalUnit,
      molecularWeight: mw,
    );
  }
}
