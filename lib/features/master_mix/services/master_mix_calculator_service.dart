export '../../lab_math/lab_calculation.dart'
    show ConcentrationFamily, ConcentrationUnit, VolumeUnit;

import '../../lab_math/lab_calculation.dart';

class MasterMixReagentInput {
  final String reagentName;
  final double stockConcentration;
  final ConcentrationUnit stockConcentrationUnit;
  final double finalConcentration;
  final ConcentrationUnit finalConcentrationUnit;
  final double? molecularWeight;

  MasterMixReagentInput({
    required this.reagentName,
    required this.stockConcentration,
    required this.stockConcentrationUnit,
    required this.finalConcentration,
    required this.finalConcentrationUnit,
    this.molecularWeight,
  });
}

class MasterMixInput {
  final String mixName;
  final double finalVolume;
  final VolumeUnit finalVolumeUnit;
  final double extraVolumePercent;
  final String baseSolventName;
  final List<MasterMixReagentInput> reagents;

  MasterMixInput({
    required this.mixName,
    required this.finalVolume,
    required this.finalVolumeUnit,
    this.extraVolumePercent = 10,
    required this.baseSolventName,
    required this.reagents,
  });
}

class MasterMixReagentResult {
  final String reagentName;
  final double reagentVolumeUl;
  final String formattedReagentVolume;
  final String formattedStockConcentration;
  final String formattedFinalConcentration;
  final List<String> warnings;
  final double? reagentMassGrams;

  MasterMixReagentResult({
    required this.reagentName,
    required this.reagentVolumeUl,
    required this.formattedReagentVolume,
    required this.formattedStockConcentration,
    required this.formattedFinalConcentration,
    this.warnings = const [],
    this.reagentMassGrams,
  });
}

class MasterMixResult {
  final bool success;
  final String? errorMessage;
  final String mixName;
  final double requestedFinalVolumeUl;
  final double optimizedFinalVolumeUl;
  final String formattedRequestedFinalVolume;
  final String formattedOptimizedFinalVolume;
  final List<MasterMixReagentResult> reagentResults;
  final double baseSolventVolumeUl;
  final String formattedBaseSolventVolume;
  final List<String> warnings;

  MasterMixResult({
    required this.success,
    this.errorMessage,
    required this.mixName,
    this.requestedFinalVolumeUl = 0,
    this.optimizedFinalVolumeUl = 0,
    this.formattedRequestedFinalVolume = '',
    this.formattedOptimizedFinalVolume = '',
    this.reagentResults = const [],
    this.baseSolventVolumeUl = 0,
    this.formattedBaseSolventVolume = '',
    this.warnings = const [],
  });
}

class MasterMixCalculatorService {
  static const double minPipettableVolumeUl =
      LabCalculation.minPipettableVolumeUl;

  MasterMixResult calculateMasterMix(MasterMixInput input) {
    final globalWarnings = <String>[];

    if (input.finalVolume <= 0 || input.finalVolume.isNaN) {
      return MasterMixResult(
        success: false,
        errorMessage: 'Final volume must be a valid number greater than 0',
        mixName: input.mixName,
      );
    }

    if (input.reagents.isEmpty) {
      return MasterMixResult(
        success: false,
        errorMessage: 'At least one reagent is required',
        mixName: input.mixName,
      );
    }

    final requestedUl = LabCalculation.volumeToUl(
      input.finalVolume,
      input.finalVolumeUnit,
    );
    final extraFactor = 1 + input.extraVolumePercent.clamp(0, 100) / 100;
    final minimumPreparedUl = requestedUl * extraFactor;
    final maxTotalUl = minimumPreparedUl * 1.3;
    final params = <_ReagentCalcParams>[];

    for (final reagent in input.reagents) {
      if (reagent.stockConcentration <= 0 || reagent.stockConcentration.isNaN) {
        return MasterMixResult(
          success: false,
          errorMessage:
              'Stock concentration for ${reagent.reagentName} must be a valid number greater than 0',
          mixName: input.mixName,
        );
      }
      if (reagent.finalConcentration.isNaN) {
        return MasterMixResult(
          success: false,
          errorMessage:
              'Final concentration for ${reagent.reagentName} must be a valid number',
          mixName: input.mixName,
        );
      }

      try {
        final ratio = _calculateConcentrationRatio(reagent);
        if (!ratio.isFinite || ratio.isNaN) {
          return MasterMixResult(
            success: false,
            errorMessage:
                'Invalid concentration ratio for ${reagent.reagentName}',
            mixName: input.mixName,
          );
        }
        if (ratio >= 1.0) {
          return MasterMixResult(
            success: false,
            errorMessage:
                'Final concentration of ${reagent.reagentName} must be less than its stock concentration',
            mixName: input.mixName,
          );
        }
        params.add(_ReagentCalcParams(input: reagent, ratio: ratio));
      } catch (e) {
        return MasterMixResult(
          success: false,
          errorMessage: e.toString(),
          mixName: input.mixName,
        );
      }
    }

    var bestTotalUl = minimumPreparedUl;
    var bestScore = double.infinity;
    var bestReagentVolumes = <double>[];

    final step = requestedUl < 100
        ? 0.1
        : requestedUl < 1000
        ? 1.0
        : requestedUl < 10000
        ? 10.0
        : 100.0;

    for (
      var currentTotalUl = minimumPreparedUl;
      currentTotalUl <= maxTotalUl + (step / 2);
      currentTotalUl += step
    ) {
      final reagentVolumes = params
          .map((param) => param.ratio * currentTotalUl)
          .toList();
      final sumReagents = reagentVolumes.fold<double>(0, (a, b) => a + b);
      final solventUl = currentTotalUl - sumReagents;
      if (solventUl < 0) continue;

      final anyTooSmall = reagentVolumes.asMap().entries.any((entry) {
        final isPowder = params[entry.key].ratio == 0;
        return !isPowder && entry.value < minPipettableVolumeUl;
      });
      if (anyTooSmall) continue;

      final score = LabCalculation.pipettingScore(
        totalUl: currentTotalUl,
        requestedUl: minimumPreparedUl,
        measuredVolumesUl: [...reagentVolumes, solventUl],
      );

      if (score < bestScore) {
        bestScore = score;
        bestTotalUl = currentTotalUl;
        bestReagentVolumes = reagentVolumes;
      }
    }

    if (bestReagentVolumes.isEmpty) {
      return MasterMixResult(
        success: false,
        errorMessage:
            'Could not find a valid mix. Some reagent volumes might be too small.',
        mixName: input.mixName,
      );
    }

    final finalSolventUl =
        bestTotalUl - bestReagentVolumes.fold<double>(0, (a, b) => a + b);
    final reagentResults = <MasterMixReagentResult>[];

    for (var i = 0; i < params.length; i++) {
      final param = params[i];
      final volumeUl = bestReagentVolumes[i];
      final reagentWarnings = <String>[];
      final stockFamily = LabCalculation.familyOf(
        param.input.stockConcentrationUnit,
      );
      final finalFamily = LabCalculation.familyOf(
        param.input.finalConcentrationUnit,
      );
      final isStockMw = stockFamily == ConcentrationFamily.molecularWeight;
      final isFinalMw = finalFamily == ConcentrationFamily.molecularWeight;

      double? massGrams;
      var formattedAmount = LabCalculation.formatVolume(
        volumeUl,
        unicodeMicro: true,
      );

      if (isStockMw || isFinalMw) {
        final mw = isStockMw
            ? param.input.stockConcentration
            : param.input.finalConcentration;
        final targetConc = isStockMw
            ? param.input.finalConcentration
            : param.input.stockConcentration;
        final targetUnit = isStockMw
            ? param.input.finalConcentrationUnit
            : param.input.stockConcentrationUnit;
        massGrams = _calculateMassGrams(
          targetConc,
          targetUnit,
          bestTotalUl,
          mw,
        );
        if (massGrams != null) {
          formattedAmount = LabCalculation.formatMass(
            massGrams,
            unicodeMicro: true,
          );
        }
      }

      if (volumeUl < 1.0 && massGrams == null) {
        reagentWarnings.add(
          'Volume is very low (${volumeUl.toStringAsFixed(2)} µL). Consider a pre-dilution.',
        );
      }

      reagentResults.add(
        MasterMixReagentResult(
          reagentName: param.input.reagentName,
          reagentVolumeUl: massGrams != null ? 0 : volumeUl,
          reagentMassGrams: massGrams,
          formattedReagentVolume: formattedAmount,
          formattedStockConcentration:
              '${param.input.stockConcentration} ${_unitLabel(param.input.stockConcentrationUnit)}',
          formattedFinalConcentration:
              '${param.input.finalConcentration} ${_unitLabel(param.input.finalConcentrationUnit)}',
          warnings: reagentWarnings,
        ),
      );
    }

    if (finalSolventUl < 1.0 && finalSolventUl > 0) {
      globalWarnings.add(
        'Base solvent volume is very low (${finalSolventUl.toStringAsFixed(2)} µL).',
      );
    }

    return MasterMixResult(
      success: true,
      mixName: input.mixName,
      requestedFinalVolumeUl: requestedUl,
      optimizedFinalVolumeUl: bestTotalUl,
      formattedRequestedFinalVolume: LabCalculation.formatVolume(
        requestedUl,
        unicodeMicro: true,
      ),
      formattedOptimizedFinalVolume: LabCalculation.formatVolume(
        bestTotalUl,
        unicodeMicro: true,
      ),
      reagentResults: reagentResults,
      baseSolventVolumeUl: finalSolventUl,
      formattedBaseSolventVolume: LabCalculation.formatVolume(
        finalSolventUl,
        unicodeMicro: true,
      ),
      warnings: globalWarnings,
    );
  }

  double _calculateConcentrationRatio(MasterMixReagentInput reagent) {
    final stockFamily = LabCalculation.familyOf(reagent.stockConcentrationUnit);
    final finalFamily = LabCalculation.familyOf(reagent.finalConcentrationUnit);

    if (stockFamily == ConcentrationFamily.molecularWeight ||
        finalFamily == ConcentrationFamily.molecularWeight) {
      return 0;
    }

    if (stockFamily == finalFamily) {
      final stockBase = LabCalculation.concentrationToBase(
        reagent.stockConcentration,
        reagent.stockConcentrationUnit,
      );
      final finalBase = LabCalculation.concentrationToBase(
        reagent.finalConcentration,
        reagent.finalConcentrationUnit,
      );
      return finalBase / stockBase;
    }

    final isMolarMassPair =
        (stockFamily == ConcentrationFamily.molar &&
            finalFamily == ConcentrationFamily.massVolume) ||
        (stockFamily == ConcentrationFamily.massVolume &&
            finalFamily == ConcentrationFamily.molar);
    if (!isMolarMassPair) {
      throw 'Incompatible concentration units: ${reagent.stockConcentrationUnit.name} and ${reagent.finalConcentrationUnit.name}';
    }

    final mw = reagent.molecularWeight;
    if (mw == null || mw <= 0) {
      throw 'Molecular weight is required to convert between ${reagent.stockConcentrationUnit.name} and ${reagent.finalConcentrationUnit.name}';
    }

    final stockMolar = stockFamily == ConcentrationFamily.molar
        ? LabCalculation.concentrationToBase(
            reagent.stockConcentration,
            reagent.stockConcentrationUnit,
          )
        : LabCalculation.concentrationToBase(
                reagent.stockConcentration,
                reagent.stockConcentrationUnit,
              ) /
              mw;
    final finalMolar = finalFamily == ConcentrationFamily.molar
        ? LabCalculation.concentrationToBase(
            reagent.finalConcentration,
            reagent.finalConcentrationUnit,
          )
        : LabCalculation.concentrationToBase(
                reagent.finalConcentration,
                reagent.finalConcentrationUnit,
              ) /
              mw;

    return finalMolar / stockMolar;
  }

  double? _calculateMassGrams(
    double targetConc,
    ConcentrationUnit targetUnit,
    double totalVolumeUl,
    double molecularWeight,
  ) {
    final volumeL = totalVolumeUl / 1e6;
    final family = LabCalculation.familyOf(targetUnit);

    if (family == ConcentrationFamily.molar) {
      return LabCalculation.concentrationToBase(targetConc, targetUnit) *
          volumeL *
          molecularWeight;
    }
    if (family == ConcentrationFamily.massVolume) {
      return LabCalculation.concentrationToBase(targetConc, targetUnit) *
          volumeL;
    }
    if (family == ConcentrationFamily.percentage) {
      return (targetConc / 100.0) * (volumeL * 1000);
    }
    return null;
  }

  String _unitLabel(ConcentrationUnit unit) {
    return LabCalculation.unitLabel(unit, unicodeMicro: true);
  }
}

class _ReagentCalcParams {
  final MasterMixReagentInput input;
  final double ratio;

  _ReagentCalcParams({required this.input, required this.ratio});
}
