import 'dart:convert';
import 'protocol_table.dart';
import '../features/master_mix/services/master_mix_calculator_service.dart';

class MasterMixWizard {
  final String mixName;
  final double finalVolume;
  final VolumeUnit finalVolumeUnit;
  final String baseSolventName;
  final List<MasterMixReagentItem> reagents;

  MasterMixWizard({
    this.mixName = 'New Master Mix',
    this.finalVolume = 500,
    this.finalVolumeUnit = VolumeUnit.uL,
    this.baseSolventName = 'Water',
    this.reagents = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'mixName': mixName,
      'finalVolume': finalVolume,
      'finalVolumeUnit': finalVolumeUnit.name,
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
    String? baseSolventName,
    List<MasterMixReagentItem>? reagents,
  }) {
    return MasterMixWizard(
      mixName: mixName ?? this.mixName,
      finalVolume: finalVolume ?? this.finalVolume,
      finalVolumeUnit: finalVolumeUnit ?? this.finalVolumeUnit,
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
      baseSolventName: baseSolventName,
      reagents: reagents.map((r) => r.toInput()).toList(),
    );

    final result = service.calculateMasterMix(input);

    final List<String> headers = [
      'Reagent name',
      'Stock conc',
      'final conc',
      'final volume'
    ];

    final List<List<dynamic>> data = [];

    if (result.success) {
      for (var r in result.reagentResults) {
        data.add([
          r.reagentName,
          r.formattedStockConcentration,
          r.formattedFinalConcentration,
          r.formattedReagentVolume,
        ]);
      }
      // Add solvent row
      data.add([
        baseSolventName,
        '-',
        '-',
        result.formattedBaseSolventVolume,
      ]);
      // Add total row
      data.add([
        'Total',
        '-',
        '-',
        result.formattedOptimizedFinalVolume,
      ]);
    } else {
      data.add(['Error', result.errorMessage ?? 'Calculation failed', '-', '-']);
    }

    return ProtocolTable(
      id: 'master_mix_${DateTime.now().millisecondsSinceEpoch}',
      title: mixName,
      type: TableType.masterMix,
      columnHeaders: headers,
      rowHeaders: List.generate(data.length, (i) => (i + 1).toString()),
      data: data,
      cellColors: List.generate(data.length, (_) => List.generate(headers.length, (_) => '')),
      metadata: {
        'wizard_state': jsonEncode(toJson()),
      },
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
