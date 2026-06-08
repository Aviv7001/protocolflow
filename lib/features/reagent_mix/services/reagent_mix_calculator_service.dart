export '../../lab_math/lab_calculation.dart'
    show ConcentrationFamily, ConcentrationUnit, VolumeUnit;

import '../../lab_math/lab_calculation.dart';

class ReagentMixInput {
  final String reagentName;
  final double stockConcentration;
  final ConcentrationUnit stockUnit;
  final double workingConcentration;
  final ConcentrationUnit workingUnit;
  final double volumePerTube;
  final VolumeUnit volumePerTubeUnit;
  final int numberOfTubes;
  final double extraVolumePercent;
  final double? molecularWeight;

  ReagentMixInput({
    required this.reagentName,
    required this.stockConcentration,
    required this.stockUnit,
    required this.workingConcentration,
    required this.workingUnit,
    required this.volumePerTube,
    required this.volumePerTubeUnit,
    required this.numberOfTubes,
    this.extraVolumePercent = 10,
    this.molecularWeight,
  });
}

class ReagentMixResult {
  final bool success;
  final String? errorMessage;
  final double reagentVolumeUl;
  final double solventVolumeUl;
  final double totalVolumeUl;
  final String formattedReagentVolume;
  final String formattedSolventVolume;
  final String formattedTotalVolume;
  final bool optimized;
  final List<String> warnings;
  final double? reagentMassGrams;

  ReagentMixResult({
    required this.success,
    this.errorMessage,
    this.reagentVolumeUl = 0,
    this.solventVolumeUl = 0,
    this.totalVolumeUl = 0,
    this.formattedReagentVolume = '',
    this.formattedSolventVolume = '',
    this.formattedTotalVolume = '',
    this.optimized = false,
    this.warnings = const [],
    this.reagentMassGrams,
  });
}

class ReagentMixCalculatorService {
  static const double minPipettableVolumeUl =
      LabCalculation.minPipettableVolumeUl;

  ReagentMixResult calculateMix(ReagentMixInput input) {
    final warnings = <String>[];

    if (input.stockConcentration <= 0) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Stock concentration must be greater than 0',
      );
    }
    if (input.numberOfTubes <= 0) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Number of tubes must be greater than 0',
      );
    }

    final stockFamily = LabCalculation.familyOf(input.stockUnit);
    final workingFamily = LabCalculation.familyOf(input.workingUnit);

    if (stockFamily == ConcentrationFamily.molecularWeight ||
        workingFamily == ConcentrationFamily.molecularWeight) {
      return _calculateMassFromConc(input);
    }

    var isCompatible = stockFamily == workingFamily;
    if (workingFamily == ConcentrationFamily.ratio) isCompatible = true;

    if (!isCompatible && input.molecularWeight == null) {
      return ReagentMixResult(
        success: false,
        errorMessage:
            'Incompatible concentration units (${input.stockUnit.name} and ${input.workingUnit.name}). Molecular weight is required for conversion.',
      );
    }

    final stockInBase = LabCalculation.concentrationToBase(
      input.stockConcentration,
      input.stockUnit,
      molecularWeight: input.molecularWeight,
    );
    final workingInBase = _workingConcentrationInBase(
      input,
      stockInBase,
      workingFamily,
    );

    if (workingInBase >= stockInBase) {
      return ReagentMixResult(
        success: false,
        errorMessage:
            'Working concentration must be less than stock concentration',
      );
    }

    final volumePerTubeUl = LabCalculation.volumeToUl(
      input.volumePerTube,
      input.volumePerTubeUnit,
    );
    final baseTotalVolumeUl = volumePerTubeUl * input.numberOfTubes;
    final extraFactor = 1 + input.extraVolumePercent.clamp(0, 100) / 100;
    final minTotalVolumeUl = baseTotalVolumeUl * extraFactor;
    final maxTotalVolumeUl = minTotalVolumeUl * 1.3;

    var bestTotalVolumeUl = minTotalVolumeUl;
    var bestReagentVolumeUl = 0.0;
    var bestScore = double.infinity;

    for (
      var currentTotalUl = minTotalVolumeUl;
      currentTotalUl <= maxTotalVolumeUl + 0.05;
      currentTotalUl += 0.1
    ) {
      final currentReagentUl = (workingInBase * currentTotalUl) / stockInBase;
      final currentSolventUl = currentTotalUl - currentReagentUl;

      if (currentReagentUl < minPipettableVolumeUl) continue;

      final score = LabCalculation.pipettingScore(
        totalUl: currentTotalUl,
        requestedUl: minTotalVolumeUl,
        measuredVolumesUl: [currentReagentUl, currentSolventUl],
      );

      if (score < bestScore) {
        bestScore = score;
        bestTotalVolumeUl = currentTotalUl;
        bestReagentVolumeUl = currentReagentUl;
      }
    }

    if (bestReagentVolumeUl < minPipettableVolumeUl) {
      return ReagentMixResult(
        success: false,
        errorMessage:
            'Required reagent volume is below the minimum pipettable limit ($minPipettableVolumeUl uL)',
      );
    }

    if (bestReagentVolumeUl < 1.0) {
      warnings.add(
        'Reagent volume is very low (${bestReagentVolumeUl.toStringAsFixed(2)} uL). Use a serial dilution if higher precision is needed.',
      );
    }

    final solventVolumeUl = bestTotalVolumeUl - bestReagentVolumeUl;

    return ReagentMixResult(
      success: true,
      reagentVolumeUl: bestReagentVolumeUl,
      solventVolumeUl: solventVolumeUl,
      totalVolumeUl: bestTotalVolumeUl,
      formattedReagentVolume: LabCalculation.formatVolume(
        bestReagentVolumeUl,
        unicodeMicro: true,
      ),
      formattedSolventVolume: LabCalculation.formatVolume(
        solventVolumeUl,
        unicodeMicro: true,
      ),
      formattedTotalVolume: LabCalculation.formatVolume(
        bestTotalVolumeUl,
        unicodeMicro: true,
      ),
      optimized: bestScore < double.infinity,
      warnings: warnings,
    );
  }

  double _workingConcentrationInBase(
    ReagentMixInput input,
    double stockInBase,
    ConcentrationFamily workingFamily,
  ) {
    if (workingFamily == ConcentrationFamily.ratio) {
      if (input.workingConcentration > 0 && input.workingConcentration < 1) {
        return stockInBase * input.workingConcentration;
      }
      if (input.workingConcentration >= 1) {
        return stockInBase / input.workingConcentration;
      }
      return 0;
    }

    return LabCalculation.concentrationToBase(
      input.workingConcentration,
      input.workingUnit,
      molecularWeight: input.molecularWeight,
    );
  }

  ReagentMixResult _calculateMassFromConc(ReagentMixInput input) {
    final isStockMw =
        LabCalculation.familyOf(input.stockUnit) ==
        ConcentrationFamily.molecularWeight;
    final mw = isStockMw
        ? input.stockConcentration
        : input.workingConcentration;
    final conc = isStockMw
        ? input.workingConcentration
        : input.stockConcentration;
    final concUnit = isStockMw ? input.workingUnit : input.stockUnit;

    if (mw <= 0) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'M.W. must be greater than 0',
      );
    }
    if (conc <= 0) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Concentration must be greater than 0',
      );
    }

    final totalVolumeUl =
        LabCalculation.volumeToUl(
          input.volumePerTube,
          input.volumePerTubeUnit,
        ) *
        input.numberOfTubes *
        (1 + input.extraVolumePercent.clamp(0, 100) / 100);
    final totalVolumeL = totalVolumeUl / 1e6;
    final massGrams = _massForConcentration(conc, concUnit, totalVolumeL, mw);

    if (massGrams == null) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Cannot calculate mass from unit ${concUnit.name}',
      );
    }

    return ReagentMixResult(
      success: true,
      reagentVolumeUl: 0,
      reagentMassGrams: massGrams,
      solventVolumeUl: totalVolumeUl,
      totalVolumeUl: totalVolumeUl,
      formattedReagentVolume: LabCalculation.formatMass(
        massGrams,
        unicodeMicro: true,
      ),
      formattedSolventVolume: LabCalculation.formatVolume(
        totalVolumeUl,
        unicodeMicro: true,
      ),
      formattedTotalVolume: LabCalculation.formatVolume(
        totalVolumeUl,
        unicodeMicro: true,
      ),
    );
  }

  double? _massForConcentration(
    double concentration,
    ConcentrationUnit unit,
    double volumeL,
    double molecularWeight,
  ) {
    final family = LabCalculation.familyOf(unit);
    if (family == ConcentrationFamily.molar) {
      return LabCalculation.concentrationToBase(concentration, unit) *
          volumeL *
          molecularWeight;
    }
    if (family == ConcentrationFamily.massVolume) {
      return LabCalculation.concentrationToBase(concentration, unit) * volumeL;
    }
    if (family == ConcentrationFamily.percentage) {
      return (concentration / 100.0) * (volumeL * 1000);
    }
    return null;
  }
}
