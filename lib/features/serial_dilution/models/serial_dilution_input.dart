import 'dart:convert';

import '../../../models/protocol_table.dart';
import '../../master_mix/services/master_mix_calculator_service.dart'
    show ConcentrationUnit, VolumeUnit;
import '../services/serial_dilution_calculator_service.dart';

enum DilutionMode { forward, independent }

enum SeriesLengthMode { numberOfDilutions, targetLowestConcentration }

class SerialDilutionInput {
  final String title;
  final String stockSolutionName;
  final double stockConcentration;
  final ConcentrationUnit stockConcentrationUnit;
  final double? startingDilutionConcentration;
  final ConcentrationUnit? startingDilutionConcentrationUnit;
  final String solventName;
  final double dilutionFactor;
  final double finalVolume;
  final VolumeUnit finalVolumeUnit;
  final double extraVolumePercent;
  final DilutionMode dilutionMode;
  final SeriesLengthMode seriesLengthMode;
  final int? numberOfDilutions;
  final double? targetLowestConcentration;
  final ConcentrationUnit? targetLowestConcentrationUnit;
  final bool includeZeroConcentrationRow;

  SerialDilutionInput({
    this.title = 'Serial Dilution Table',
    this.stockSolutionName = 'Stock',
    this.stockConcentration = 1000,
    this.stockConcentrationUnit = ConcentrationUnit.ngML,
    this.startingDilutionConcentration,
    this.startingDilutionConcentrationUnit,
    this.solventName = 'PBS',
    this.dilutionFactor = 2,
    this.finalVolume = 500,
    this.finalVolumeUnit = VolumeUnit.uL,
    this.extraVolumePercent = 10,
    this.dilutionMode = DilutionMode.forward,
    this.seriesLengthMode = SeriesLengthMode.numberOfDilutions,
    this.numberOfDilutions = 8,
    this.targetLowestConcentration,
    this.targetLowestConcentrationUnit,
    this.includeZeroConcentrationRow = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'stockSolutionName': stockSolutionName,
      'stockConcentration': stockConcentration,
      'stockConcentrationUnit': stockConcentrationUnit.name,
      'startingDilutionConcentration': startingDilutionConcentration,
      'startingDilutionConcentrationUnit':
          startingDilutionConcentrationUnit?.name,
      'solventName': solventName,
      'dilutionFactor': dilutionFactor,
      'finalVolume': finalVolume,
      'finalVolumeUnit': finalVolumeUnit.name,
      'extraVolumePercent': extraVolumePercent,
      'dilutionMode': dilutionMode.name,
      'seriesLengthMode': seriesLengthMode.name,
      'numberOfDilutions': numberOfDilutions,
      'targetLowestConcentration': targetLowestConcentration,
      'targetLowestConcentrationUnit': targetLowestConcentrationUnit?.name,
      'includeZeroConcentrationRow': includeZeroConcentrationRow,
    };
  }

  factory SerialDilutionInput.fromJson(Map<String, dynamic> json) {
    return SerialDilutionInput(
      title: json['title'] ?? 'Serial Dilution Table',
      stockSolutionName: json['stockSolutionName'] ?? 'Stock',
      stockConcentration: (json['stockConcentration'] ?? 1000).toDouble(),
      stockConcentrationUnit: ConcentrationUnit.values.firstWhere(
        (e) => e.name == json['stockConcentrationUnit'],
        orElse: () => ConcentrationUnit.ngML,
      ),
      startingDilutionConcentration:
          (json['startingDilutionConcentration'] as num?)?.toDouble(),
      startingDilutionConcentrationUnit:
          json['startingDilutionConcentrationUnit'] == null
          ? null
          : ConcentrationUnit.values.firstWhere(
              (e) => e.name == json['startingDilutionConcentrationUnit'],
              orElse: () => ConcentrationUnit.ngML,
            ),
      solventName: json['solventName'] ?? 'PBS',
      dilutionFactor: (json['dilutionFactor'] ?? 2).toDouble(),
      finalVolume: (json['finalVolume'] ?? 500).toDouble(),
      finalVolumeUnit: VolumeUnit.values.firstWhere(
        (e) => e.name == json['finalVolumeUnit'],
        orElse: () => VolumeUnit.uL,
      ),
      extraVolumePercent: (json['extraVolumePercent'] ?? 10).toDouble(),
      dilutionMode: DilutionMode.values.firstWhere(
        (e) => e.name == json['dilutionMode'],
        orElse: () => DilutionMode.forward,
      ),
      seriesLengthMode: SeriesLengthMode.values.firstWhere(
        (e) => e.name == json['seriesLengthMode'],
        orElse: () => SeriesLengthMode.numberOfDilutions,
      ),
      numberOfDilutions: json['numberOfDilutions'],
      targetLowestConcentration: (json['targetLowestConcentration'] as num?)
          ?.toDouble(),
      targetLowestConcentrationUnit:
          json['targetLowestConcentrationUnit'] == null
          ? null
          : ConcentrationUnit.values.firstWhere(
              (e) => e.name == json['targetLowestConcentrationUnit'],
              orElse: () => ConcentrationUnit.ngML,
            ),
      includeZeroConcentrationRow: json['includeZeroConcentrationRow'] ?? false,
    );
  }

  SerialDilutionInput copyWith({
    String? title,
    String? stockSolutionName,
    double? stockConcentration,
    ConcentrationUnit? stockConcentrationUnit,
    double? startingDilutionConcentration,
    ConcentrationUnit? startingDilutionConcentrationUnit,
    String? solventName,
    double? dilutionFactor,
    double? finalVolume,
    VolumeUnit? finalVolumeUnit,
    double? extraVolumePercent,
    DilutionMode? dilutionMode,
    SeriesLengthMode? seriesLengthMode,
    int? numberOfDilutions,
    double? targetLowestConcentration,
    ConcentrationUnit? targetLowestConcentrationUnit,
    bool? includeZeroConcentrationRow,
  }) {
    return SerialDilutionInput(
      title: title ?? this.title,
      stockSolutionName: stockSolutionName ?? this.stockSolutionName,
      stockConcentration: stockConcentration ?? this.stockConcentration,
      stockConcentrationUnit:
          stockConcentrationUnit ?? this.stockConcentrationUnit,
      startingDilutionConcentration:
          startingDilutionConcentration ?? this.startingDilutionConcentration,
      startingDilutionConcentrationUnit:
          startingDilutionConcentrationUnit ??
          this.startingDilutionConcentrationUnit,
      solventName: solventName ?? this.solventName,
      dilutionFactor: dilutionFactor ?? this.dilutionFactor,
      finalVolume: finalVolume ?? this.finalVolume,
      finalVolumeUnit: finalVolumeUnit ?? this.finalVolumeUnit,
      extraVolumePercent: extraVolumePercent ?? this.extraVolumePercent,
      dilutionMode: dilutionMode ?? this.dilutionMode,
      seriesLengthMode: seriesLengthMode ?? this.seriesLengthMode,
      numberOfDilutions: numberOfDilutions ?? this.numberOfDilutions,
      targetLowestConcentration:
          targetLowestConcentration ?? this.targetLowestConcentration,
      targetLowestConcentrationUnit:
          targetLowestConcentrationUnit ?? this.targetLowestConcentrationUnit,
      includeZeroConcentrationRow:
          includeZeroConcentrationRow ?? this.includeZeroConcentrationRow,
    );
  }

  ProtocolTable generateTable() {
    final result = SerialDilutionCalculatorService().generateDilutionTable(
      this,
    );
    final headers = [
      'Dilution',
      'Concentration',
      'Transfer From',
      'Transfer Volume',
      'Solvent Volume',
      'Final Volume',
    ];

    final data = result.success
        ? result.rows
              .map<List<dynamic>>(
                (row) => [
                  row.dilutionName,
                  row.formattedConcentration,
                  row.transferFrom,
                  row.formattedTransferVolume,
                  row.formattedSolventVolume,
                  row.formattedFinalVolume,
                ],
              )
              .toList()
        : <List<dynamic>>[
            [
              'Error',
              result.errorMessage ?? 'Calculation failed',
              '',
              '',
              '',
              '',
            ],
          ];

    return ProtocolTable(
      id: 'serial_dilution_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: TableType.serialDilution,
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
}
