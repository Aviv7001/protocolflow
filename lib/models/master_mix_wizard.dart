import 'dart:convert';

import 'protocol_table.dart';
import '../features/lab_math/lab_calculation.dart';
import '../features/measuring_tools/services/transfer_optimizer_service.dart';
import '../features/master_mix/services/master_mix_calculator_service.dart';

class MasterMixWizard {
  final String tableName;
  final List<MasterMixItem> mixes;

  MasterMixWizard({
    String? tableName,
    String mixName = 'New Mix',
    double finalVolume = 500,
    VolumeUnit finalVolumeUnit = VolumeUnit.uL,
    double extraVolumePercent = 10,
    bool autoExtraVolume = false,
    String baseSolventName = 'Water',
    List<MasterMixReagentItem> reagents = const [],
    List<MasterMixItem>? mixes,
  }) : tableName = tableName ?? 'Master Mix Table',
       mixes =
           mixes ??
           [
             MasterMixItem(
               mixName: mixName,
               finalVolume: finalVolume,
               finalVolumeUnit: finalVolumeUnit,
               extraVolumePercent: extraVolumePercent,
               autoExtraVolume: autoExtraVolume,
               baseSolventName: baseSolventName,
               reagents: reagents,
             ),
           ];

  String get mixName => tableName;
  double get finalVolume => mixes.first.finalVolume;
  VolumeUnit get finalVolumeUnit => mixes.first.finalVolumeUnit;
  double get extraVolumePercent => mixes.first.extraVolumePercent;
  bool get autoExtraVolume => mixes.first.autoExtraVolume;
  String get baseSolventName => mixes.first.baseSolventName;
  List<MasterMixReagentItem> get reagents => mixes.first.reagents;

  Map<String, dynamic> toJson() {
    return {
      'tableName': tableName,
      'mixes': mixes.map((m) => m.toJson()).toList(),
    };
  }

  factory MasterMixWizard.fromJson(Map<String, dynamic> json) {
    if (json['mixes'] is List) {
      return MasterMixWizard(
        tableName: json['tableName'] ?? json['mixName'] ?? 'Master Mix Table',
        mixes: (json['mixes'] as List)
            .map<MasterMixItem>((m) => MasterMixItem.fromJson(m))
            .toList(),
      );
    }

    return MasterMixWizard(
      tableName: json['mixName'] ?? 'Master Mix Table',
      mixName: json['mixName'] ?? 'New Mix',
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
    String? tableName,
    String? mixName,
    double? finalVolume,
    VolumeUnit? finalVolumeUnit,
    double? extraVolumePercent,
    bool? autoExtraVolume,
    String? baseSolventName,
    List<MasterMixReagentItem>? reagents,
    List<MasterMixItem>? mixes,
  }) {
    final currentMixes = List<MasterMixItem>.from(this.mixes);
    if (mixes != null) {
      return MasterMixWizard(
        tableName: tableName ?? this.tableName,
        mixes: mixes,
      );
    }

    if (currentMixes.isEmpty) {
      currentMixes.add(MasterMixItem());
    }
    currentMixes[0] = currentMixes[0].copyWith(
      mixName: mixName,
      finalVolume: finalVolume,
      finalVolumeUnit: finalVolumeUnit,
      extraVolumePercent: extraVolumePercent,
      autoExtraVolume: autoExtraVolume,
      baseSolventName: baseSolventName,
      reagents: reagents,
    );

    return MasterMixWizard(
      tableName: tableName ?? this.tableName,
      mixes: currentMixes,
    );
  }

  ProtocolTable generateTable() {
    final service = MasterMixCalculatorService();
    final headers = [
      'Mix name',
      'Reagent name',
      'Stock conc',
      'final conc',
      'final volume',
      'Suggested transfer',
      'Tool',
      'Status',
    ];

    final data = <List<dynamic>>[];

    for (final mix in mixes) {
      final result = service.calculateMasterMix(mix.toInput());

      if (!result.success) {
        data.add([
          mix.mixName,
          'Error',
          result.errorMessage ?? 'Calculation failed',
          '-',
          '-',
          '-',
          '-',
          '',
        ]);
        continue;
      }

      for (final reagent in result.reagentResults) {
        data.add([
          mix.mixName,
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
        mix.mixName,
        mix.baseSolventName,
        '-',
        '-',
        result.formattedBaseSolventVolume,
        _transferLabel(result.solventTransferEvaluation),
        _toolLabel(result.solventTransferEvaluation),
        '',
      ]);
      data.add([
        mix.mixName,
        'Total',
        '-',
        '-',
        result.formattedOptimizedFinalVolume,
        '-',
        '-',
        '',
      ]);
    }

    return ProtocolTable(
      id: 'master_mix_${DateTime.now().millisecondsSinceEpoch}',
      title: tableName,
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

class MasterMixItem {
  final String mixName;
  final double finalVolume;
  final VolumeUnit finalVolumeUnit;
  final double extraVolumePercent;
  final bool autoExtraVolume;
  final String baseSolventName;
  final List<MasterMixReagentItem> reagents;

  MasterMixItem({
    this.mixName = 'New Mix',
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

  factory MasterMixItem.fromJson(Map<String, dynamic> json) {
    return MasterMixItem(
      mixName: json['mixName'] ?? 'New Mix',
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

  MasterMixItem copyWith({
    String? mixName,
    double? finalVolume,
    VolumeUnit? finalVolumeUnit,
    double? extraVolumePercent,
    bool? autoExtraVolume,
    String? baseSolventName,
    List<MasterMixReagentItem>? reagents,
  }) {
    return MasterMixItem(
      mixName: mixName ?? this.mixName,
      finalVolume: finalVolume ?? this.finalVolume,
      finalVolumeUnit: finalVolumeUnit ?? this.finalVolumeUnit,
      extraVolumePercent: extraVolumePercent ?? this.extraVolumePercent,
      autoExtraVolume: autoExtraVolume ?? this.autoExtraVolume,
      baseSolventName: baseSolventName ?? this.baseSolventName,
      reagents: reagents ?? this.reagents,
    );
  }

  MasterMixInput toInput() {
    return MasterMixInput(
      mixName: mixName,
      finalVolume: finalVolume,
      finalVolumeUnit: finalVolumeUnit,
      extraVolumePercent: extraVolumePercent,
      autoExtraVolume: autoExtraVolume,
      baseSolventName: baseSolventName,
      reagents: reagents.map((r) => r.toInput()).toList(),
    );
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
