/// Units for volume measurements
enum VolumeUnit { uL, mL, L }

/// Units for concentration measurements
enum ConcentrationUnit {
  // Molar family
  M,
  mM,
  uM,
  nM,
  // Mass/Volume family
  gL,
  mgML,
  ugML,
  // Others
  percent,
  ratio,
  // Molecular Weight (Special unit for conversion)
  gMol
}

/// Categories of concentrations that can be converted between each other
enum ConcentrationFamily { molar, massVolume, percentage, ratio, molecularWeight, unknown }

/// Input data for the Reagent Mix calculation
class ReagentMixInput {
  final String reagentName;
  final double stockConcentration;
  final ConcentrationUnit stockUnit;
  final double workingConcentration;
  final ConcentrationUnit workingUnit;
  final double volumePerTube;
  final VolumeUnit volumePerTubeUnit;
  final int numberOfTubes;
  final double? molecularWeight; // Optional, for cross-family conversion

  ReagentMixInput({
    required this.reagentName,
    required this.stockConcentration,
    required this.stockUnit,
    required this.workingConcentration,
    required this.workingUnit,
    required this.volumePerTube,
    required this.volumePerTubeUnit,
    required this.numberOfTubes,
    this.molecularWeight,
  });
}

/// Result of the Reagent Mix calculation
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
  static const double minPipettableVolumeUl = 0.2;

  /// Main calculation method with optimization for pipetting-friendly values
  ReagentMixResult calculateMix(ReagentMixInput input) {
    final List<String> warnings = [];

    // 1. Basic Validations
    if (input.stockConcentration <= 0) {
      return ReagentMixResult(success: false, errorMessage: 'Stock concentration must be greater than 0');
    }
    if (input.numberOfTubes <= 0) {
      return ReagentMixResult(success: false, errorMessage: 'Number of tubes must be greater than 0');
    }

    // 2. Unit Compatibility Check
    final stockFamily = _getFamily(input.stockUnit);
    final workingFamily = _getFamily(input.workingUnit);

    // Special Case: One of them is Molecular Weight
    if (stockFamily == ConcentrationFamily.molecularWeight || workingFamily == ConcentrationFamily.molecularWeight) {
      return _calculateMassFromConc(input);
    }

    bool isCompatible = stockFamily == workingFamily;
    // Ratio is a relative unit and is always compatible with any family
    if (workingFamily == ConcentrationFamily.ratio) {
      isCompatible = true;
    }

    if (!isCompatible && input.molecularWeight == null) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Incompatible concentration units (${input.stockUnit.name} and ${input.workingUnit.name}). Molecular weight is required for conversion.',
      );
    }

    // 3. Convert Internal Values
    final double stockInBase = _convertToBaseConc(input.stockConcentration, input.stockUnit, input.molecularWeight);
    double workingInBase;

    if (workingFamily == ConcentrationFamily.ratio) {
      // If working conc is a ratio (e.g. 1:400), it's relative to the stock.
      // We assume the input value is the denominator (e.g. 400).
      // If the user provided a fraction < 1 (e.g. 0.0025), we treat it as the absolute multiplier.
      if (input.workingConcentration > 0 && input.workingConcentration < 1) {
        workingInBase = stockInBase * input.workingConcentration;
      } else if (input.workingConcentration >= 1) {
        workingInBase = stockInBase / input.workingConcentration;
      } else {
        workingInBase = 0;
      }
    } else {
      workingInBase = _convertToBaseConc(input.workingConcentration, input.workingUnit, input.molecularWeight);
    }

    if (workingInBase >= stockInBase) {
      return ReagentMixResult(success: false, errorMessage: 'Working concentration must be less than stock concentration');
    }

    final double volPerTubeUl = _convertToUl(input.volumePerTube, input.volumePerTubeUnit);
    final double baseTotalVolumeUl = volPerTubeUl * input.numberOfTubes;
    final double minTotalVolumeUl = baseTotalVolumeUl * 1.1;
    final double maxTotalVolumeUl = minTotalVolumeUl * 1.3;

    // 4. Optimization Loop
    double bestTotalVol = minTotalVolumeUl;
    double bestReagentVol = 0;
    double bestScore = double.infinity;

    // Search from minTotal to maxTotal with 0.1 uL resolution
    for (double currentTotalUl = minTotalVolumeUl;
        currentTotalUl <= maxTotalVolumeUl + 0.05;
        currentTotalUl += 0.1) {
      
      final double currentReagentUl = (workingInBase * currentTotalUl) / stockInBase;
      final double currentSolventUl = currentTotalUl - currentReagentUl;

      if (currentReagentUl < minPipettableVolumeUl) continue;

      final double score = _calculatePipettingScore(currentReagentUl, currentSolventUl, currentTotalUl, minTotalVolumeUl);

      if (score < bestScore) {
        bestScore = score;
        bestTotalVol = currentTotalUl;
        bestReagentVol = currentReagentUl;
      }
    }

    // Final Validation of Best Result
    if (bestReagentVol < minPipettableVolumeUl) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Required reagent volume is below the minimum pipettable limit ($minPipettableVolumeUl uL)',
      );
    }
    
    if (bestReagentVol < 1.0) {
      warnings.add('Reagent volume is very low (${bestReagentVol.toStringAsFixed(2)} uL). Use a serial dilution if higher precision is needed.');
    }

    final double finalSolventVol = bestTotalVol - bestReagentVol;

    return ReagentMixResult(
      success: true,
      reagentVolumeUl: bestReagentVol,
      solventVolumeUl: finalSolventVol,
      totalVolumeUl: bestTotalVol,
      formattedReagentVolume: _formatVolume(bestReagentVol),
      formattedSolventVolume: _formatVolume(finalSolventVol),
      formattedTotalVolume: _formatVolume(bestTotalVol),
      optimized: bestScore < double.infinity,
      warnings: warnings,
    );
  }

  // --- Helper Methods ---

  /// Calculates a penalty score for a set of volumes. Lower is better.
  double _calculatePipettingScore(double reagent, double solvent, double total, double minTotal) {
    double score = 0;

    // Penalty for decimals (prefer integers)
    score += _decimalPenalty(reagent);
    score += _decimalPenalty(solvent);
    score += _decimalPenalty(total);

    // Penalty for very low reagent volumes
    if (reagent < 1.0) score += 5.0;
    
    // Penalty for excessive extra volume (prefer smallest friendly volume)
    // Every 1uL of extra volume adds a small penalty
    score += (total - minTotal) * 0.1;

    return score;
  }

  double _decimalPenalty(double val) {
    final String s = val.toStringAsFixed(4);
    if (s.endsWith('.0000')) return 0; // Integer
    if (s.endsWith('000') || s.endsWith('500')) return 1; // .5 or 1 decimal
    return 10; // 2+ decimals
  }

  String _formatMass(double grams) {
    if (grams >= 1) {
      return '${grams.toStringAsFixed(_isClean(grams) ? 0 : 2)} g';
    } else if (grams >= 0.001) {
      final double mg = grams * 1000;
      return '${mg.toStringAsFixed(_isClean(mg) ? 0 : 2)} mg';
    } else {
      final double ug = grams * 1000000;
      return '${ug.toStringAsFixed(_isClean(ug) ? 0 : 2)} µg';
    }
  }

  ReagentMixResult _calculateMassFromConc(ReagentMixInput input) {
    final bool isStockMW = _getFamily(input.stockUnit) == ConcentrationFamily.molecularWeight;
    final double mw = isStockMW ? input.stockConcentration : input.workingConcentration;
    final double conc = isStockMW ? input.workingConcentration : input.stockConcentration;
    final ConcentrationUnit concUnit = isStockMW ? input.workingUnit : input.stockUnit;

    if (mw <= 0) return ReagentMixResult(success: false, errorMessage: 'M.W. must be greater than 0');
    if (conc <= 0) return ReagentMixResult(success: false, errorMessage: 'Concentration must be greater than 0');

    final double totalVolUl = _convertToUl(input.volumePerTube, input.volumePerTubeUnit) * input.numberOfTubes;
    final double totalVolL = totalVolUl / 1e6;
    
    double massGrams = 0;
    final family = _getFamily(concUnit);

    if (family == ConcentrationFamily.molar) {
      final double molarity = _convertToBaseConc(conc, concUnit, null);
      massGrams = molarity * totalVolL * mw;
    } else if (family == ConcentrationFamily.massVolume) {
      final double gL = _convertToBaseConc(conc, concUnit, null);
      massGrams = gL * totalVolL;
    } else if (family == ConcentrationFamily.percentage) {
      // 1% w/v = 1g / 100mL = 10g / L
      massGrams = (conc / 100.0) * (totalVolL * 1000); // g
    } else {
      return ReagentMixResult(success: false, errorMessage: 'Cannot calculate mass from unit ${concUnit.name}');
    }

    return ReagentMixResult(
      success: true,
      reagentVolumeUl: 0,
      reagentMassGrams: massGrams,
      solventVolumeUl: totalVolUl,
      totalVolumeUl: totalVolUl,
      formattedReagentVolume: _formatMass(massGrams),
      formattedSolventVolume: _formatVolume(totalVolUl),
      formattedTotalVolume: _formatVolume(totalVolUl),
      warnings: [],
    );
  }

  /// Categorizes units into families
  ConcentrationFamily _getFamily(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
      case ConcentrationUnit.mM:
      case ConcentrationUnit.uM:
      case ConcentrationUnit.nM:
        return ConcentrationFamily.molar;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML:
      case ConcentrationUnit.ugML:
        return ConcentrationFamily.massVolume;
      case ConcentrationUnit.percent:
        return ConcentrationFamily.percentage;
      case ConcentrationUnit.ratio:
        return ConcentrationFamily.ratio;
      case ConcentrationUnit.gMol:
        return ConcentrationFamily.molecularWeight;
    }
  }

  /// Converts any concentration to a base value for internal math
  /// If mw is provided, converts cross-family to Molar.
  /// Otherwise converts to family base (M or g/L).
  double _convertToBaseConc(double val, ConcentrationUnit unit, double? mw) {
    switch (unit) {
      // Molar family -> Base: M
      case ConcentrationUnit.M: return val;
      case ConcentrationUnit.mM: return val * 1e-3;
      case ConcentrationUnit.uM: return val * 1e-6;
      case ConcentrationUnit.nM: return val * 1e-9;
      
      // Mass/Vol family -> Base: g/L (which is same as mg/mL)
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML: 
        if (mw != null && mw > 0) return val / mw; // Convert to M
        return val;
      case ConcentrationUnit.ugML:
        if (mw != null && mw > 0) return (val * 1e-3) / mw; // Convert to M
        return val * 1e-3;

      case ConcentrationUnit.percent: 
        if (mw != null && mw > 0) return (val * 10) / mw; // 1% = 10g/L -> M
        return val; // Base: %
      case ConcentrationUnit.ratio: return val == 0 ? 0 : 1.0 / val; // e.g. 400 -> 0.0025
      case ConcentrationUnit.gMol: return val; // Base: g/mol
    }
  }

  /// Converts volume to uL
  double _convertToUl(double val, VolumeUnit unit) {
    switch (unit) {
      case VolumeUnit.uL: return val;
      case VolumeUnit.mL: return val * 1000;
      case VolumeUnit.L: return val * 1000000;
    }
  }

  /// Formats volume with smart units
  String _formatVolume(double ul) {
    if (ul >= 1000000) {
      return '${(ul / 1000000).toStringAsFixed(_isClean(ul / 1000000) ? 0 : 2)} L';
    } else if (ul >= 1000) {
      // User said: 1000 uL -> 1 mL, 2500 uL -> 2.5 mL
      final double ml = ul / 1000;
      return '${ml.toStringAsFixed(_isClean(ml) ? 0 : 2)} mL';
    } else {
      return '${ul.toStringAsFixed(_isClean(ul) ? 0 : 1)} µL';
    }
  }

  bool _isClean(double val) {
    return (val - val.round()).abs() < 0.0001;
  }
}
