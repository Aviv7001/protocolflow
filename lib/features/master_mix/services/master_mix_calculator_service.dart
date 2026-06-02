/// Units for volume measurements
enum VolumeUnit { nL, uL, mL, L }

/// Units for concentration measurements
enum ConcentrationUnit {
  // Molar family
  M,
  mM,
  uM,
  nM,
  pM,
  // Mass/Volume family
  gL,
  mgML,
  ugML,
  ngML,
  // Percentage
  percent,
  // Fold/X
  X,
  // Molecular Weight
  gMol
}

/// Categories of concentrations that can be converted between each other
enum ConcentrationFamily { molar, massVolume, percentage, fold, molecularWeight, unknown }

/// Input data for a single reagent in the Master Mix
class MasterMixReagentInput {
  final String reagentName;
  final double stockConcentration;
  final ConcentrationUnit stockConcentrationUnit;
  final double finalConcentration;
  final ConcentrationUnit finalConcentrationUnit;
  final double? molecularWeight; // Required for cross-family conversion

  MasterMixReagentInput({
    required this.reagentName,
    required this.stockConcentration,
    required this.stockConcentrationUnit,
    required this.finalConcentration,
    required this.finalConcentrationUnit,
    this.molecularWeight,
  });
}

/// Input data for the Master Mix calculation
class MasterMixInput {
  final String mixName;
  final double finalVolume;
  final VolumeUnit finalVolumeUnit;
  final String baseSolventName;
  final List<MasterMixReagentInput> reagents;

  MasterMixInput({
    required this.mixName,
    required this.finalVolume,
    required this.finalVolumeUnit,
    required this.baseSolventName,
    required this.reagents,
  });
}

/// Result for a single reagent in the Master Mix
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

/// Result of the Master Mix calculation
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
  static const double minPipettableVolumeUl = 0.2;

  /// Main calculation method for Master Mix with optimization
  MasterMixResult calculateMasterMix(MasterMixInput input) {
    final List<String> globalWarnings = [];

    // 1. Basic Validations
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

    final double requestedUl = _convertToUl(input.finalVolume, input.finalVolumeUnit);
    final double maxTotalUl = requestedUl * 1.3;

    // 2. Pre-calculate reagent parameters (concentration ratios)
    final List<_ReagentCalcParams> params = [];
    for (final r in input.reagents) {
      if (r.stockConcentration <= 0 || r.stockConcentration.isNaN) {
        return MasterMixResult(
          success: false,
          errorMessage: 'Stock concentration for ${r.reagentName} must be a valid number greater than 0',
          mixName: input.mixName,
        );
      }
      if (r.finalConcentration.isNaN) {
        return MasterMixResult(
          success: false,
          errorMessage: 'Final concentration for ${r.reagentName} must be a valid number',
          mixName: input.mixName,
        );
      }
      try {
        final ratio = _calculateConcentrationRatio(r);
        if (!ratio.isFinite || ratio.isNaN) {
          return MasterMixResult(
            success: false,
            errorMessage: 'Invalid concentration ratio for ${r.reagentName}',
            mixName: input.mixName,
          );
        }
        if (ratio >= 1.0) {
          return MasterMixResult(
            success: false,
            errorMessage: 'Final concentration of ${r.reagentName} must be less than its stock concentration',
            mixName: input.mixName,
          );
        }
        params.add(_ReagentCalcParams(input: r, ratio: ratio));
      } catch (e) {
        return MasterMixResult(
          success: false,
          errorMessage: e.toString(),
          mixName: input.mixName,
        );
      }
    }

    // 3. Optimization Loop
    double bestTotalUl = requestedUl;
    double bestScore = double.infinity;
    List<double> bestReagentVolumes = [];

    // Determine step size based on volume
    double step;
    if (requestedUl < 100) {
      step = 0.1;
    } else if (requestedUl < 1000) {
      step = 1.0;
    } else if (requestedUl < 10000) {
      step = 10.0;
    } else {
      step = 100.0;
    }

    for (double currentTotalUl = requestedUl;
        currentTotalUl <= maxTotalUl + (step / 2);
        currentTotalUl += step) {
      
      final List<double> currentReagentVols = params.map((p) => p.ratio * currentTotalUl).toList();
      final double sumReagents = currentReagentVols.fold(0, (a, b) => a + b);
      final double currentSolventUl = currentTotalUl - sumReagents;

      if (currentSolventUl < 0) continue; // Infeasible

      // Check if any reagent is below absolute minimum
      bool anyTooSmall = false;
      for (int i = 0; i < currentReagentVols.length; i++) {
        final bool isPowder = params[i].ratio == 0;
        if (!isPowder && currentReagentVols[i] < minPipettableVolumeUl) {
          anyTooSmall = true;
          break;
        }
      }
      if (anyTooSmall) continue;

      final double score = _calculatePipettingScore(currentTotalUl, requestedUl, currentReagentVols, currentSolventUl);

      if (score < bestScore) {
        bestScore = score;
        bestTotalUl = currentTotalUl;
        bestReagentVolumes = currentReagentVols;
      }
    }

    // 4. Final Validation and Result Construction
    if (bestReagentVolumes.isEmpty) {
      return MasterMixResult(
        success: false,
        errorMessage: 'Could not find a valid mix. Some reagent volumes might be too small.',
        mixName: input.mixName,
      );
    }

    final double finalSolventUl = bestTotalUl - bestReagentVolumes.fold(0, (a, b) => a + b);
    final List<MasterMixReagentResult> reagentResults = [];

    for (int i = 0; i < params.length; i++) {
      final p = params[i];
      final vol = bestReagentVolumes[i];
      final List<String> rWarnings = [];

      final bool isStockMW = _getFamily(p.input.stockConcentrationUnit) == ConcentrationFamily.molecularWeight;
      final bool isFinalMW = _getFamily(p.input.finalConcentrationUnit) == ConcentrationFamily.molecularWeight;
      
      double? massGrams;
      String formattedVolume = _formatVolume(vol);

      if (isStockMW || isFinalMW) {
        final mw = isStockMW ? p.input.stockConcentration : p.input.finalConcentration;
        final targetConc = isStockMW ? p.input.finalConcentration : p.input.stockConcentration;
        final targetUnit = isStockMW ? p.input.finalConcentrationUnit : p.input.stockConcentrationUnit;
        
        final double volL = bestTotalUl / 1e6;
        final family = _getFamily(targetUnit);

        if (family == ConcentrationFamily.molar) {
          final double molarity = _convertToBaseConc(targetConc, targetUnit);
          massGrams = molarity * volL * mw;
        } else if (family == ConcentrationFamily.massVolume) {
          final double gL = _convertToBaseConc(targetConc, targetUnit);
          massGrams = gL * volL;
        } else if (family == ConcentrationFamily.percentage) {
          massGrams = (targetConc / 100.0) * (volL * 1000);
        }
        
        if (massGrams != null) {
          formattedVolume = _formatMass(massGrams);
        }
      }

      if (vol < 1.0 && massGrams == null) {
        rWarnings.add('Volume is very low (${vol.toStringAsFixed(2)} µL). Consider a pre-dilution.');
      }

      reagentResults.add(MasterMixReagentResult(
        reagentName: p.input.reagentName,
        reagentVolumeUl: massGrams != null ? 0 : vol,
        reagentMassGrams: massGrams,
        formattedReagentVolume: formattedVolume,
        formattedStockConcentration: '${p.input.stockConcentration} ${_unitLabel(p.input.stockConcentrationUnit)}',
        formattedFinalConcentration: '${p.input.finalConcentration} ${_unitLabel(p.input.finalConcentrationUnit)}',
        warnings: rWarnings,
      ));
    }

    if (finalSolventUl < 1.0 && finalSolventUl > 0) {
      globalWarnings.add('Base solvent volume is very low (${finalSolventUl.toStringAsFixed(2)} µL).');
    }

    return MasterMixResult(
      success: true,
      mixName: input.mixName,
      requestedFinalVolumeUl: requestedUl,
      optimizedFinalVolumeUl: bestTotalUl,
      formattedRequestedFinalVolume: _formatVolume(requestedUl),
      formattedOptimizedFinalVolume: _formatVolume(bestTotalUl),
      reagentResults: reagentResults,
      baseSolventVolumeUl: finalSolventUl,
      formattedBaseSolventVolume: _formatVolume(finalSolventUl),
      warnings: globalWarnings,
    );
  }

  // --- Helper Methods ---

  /// Calculates ratio: finalConcentration / stockConcentration in same base units
  double _calculateConcentrationRatio(MasterMixReagentInput r) {
    final stockFamily = _getFamily(r.stockConcentrationUnit);
    final finalFamily = _getFamily(r.finalConcentrationUnit);

    if (stockFamily == ConcentrationFamily.molecularWeight || finalFamily == ConcentrationFamily.molecularWeight) {
      // For powders, they don't contribute to volume displacement in the same way liquids do
      // but usually we assume they take up negligible volume.
      return 0; 
    }

    if (stockFamily == finalFamily) {
      final stockBase = _convertToBaseConc(r.stockConcentration, r.stockConcentrationUnit);
      final finalBase = _convertToBaseConc(r.finalConcentration, r.finalConcentrationUnit);
      return finalBase / stockBase;
    }

    // Cross-family conversion (Molar <-> Mass)
    if ((stockFamily == ConcentrationFamily.molar && finalFamily == ConcentrationFamily.massVolume) ||
        (stockFamily == ConcentrationFamily.massVolume && finalFamily == ConcentrationFamily.molar)) {
      
      if (r.molecularWeight == null || r.molecularWeight! <= 0) {
        throw 'Molecular weight is required to convert between ${r.stockConcentrationUnit.name} and ${r.finalConcentrationUnit.name}';
      }

      // Convert both to Molar Base (M)
      double stockMolar;
      double finalMolar;

      if (stockFamily == ConcentrationFamily.molar) {
        stockMolar = _convertToBaseConc(r.stockConcentration, r.stockConcentrationUnit);
      } else {
        // Mass (g/L) to Molar (M): M = (g/L) / MW
        final stockMassBase = _convertToBaseConc(r.stockConcentration, r.stockConcentrationUnit);
        stockMolar = stockMassBase / r.molecularWeight!;
      }

      if (finalFamily == ConcentrationFamily.molar) {
        finalMolar = _convertToBaseConc(r.finalConcentration, r.finalConcentrationUnit);
      } else {
        final finalMassBase = _convertToBaseConc(r.finalConcentration, r.finalConcentrationUnit);
        finalMolar = finalMassBase / r.molecularWeight!;
      }

      return finalMolar / stockMolar;
    }

    throw 'Incompatible concentration units: ${r.stockConcentrationUnit.name} and ${r.finalConcentrationUnit.name}';
  }

  /// Calculates a penalty score for a set of volumes. Lower is better.
  double _calculatePipettingScore(
    double totalUl,
    double requestedUl,
    List<double> reagentsUl,
    double solventUl,
  ) {
    double score = 0;

    // Penalty for extra volume (prefer keeping close to requested)
    score += (totalUl - requestedUl) * 0.1;

    // Penalty for decimals in reagents
    for (final v in reagentsUl) {
      score += _decimalPenalty(v);
      if (v < 1.0) score += 10.0; // Strong penalty for < 1uL
    }

    // Penalty for decimals in solvent and total
    score += _decimalPenalty(solventUl);
    score += _decimalPenalty(totalUl) * 0.5;

    return score;
  }

  double _decimalPenalty(double val) {
    if (!val.isFinite) return 100.0;

    final double remainder = (val * 10) % 10;
    if ((val - val.round()).abs() < 0.0001) return 0; // Integer
    if ((remainder - 5).abs() < 0.0001) return 1;    // .5
    return 10; // Other decimals
  }

  ConcentrationFamily _getFamily(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
      case ConcentrationUnit.mM:
      case ConcentrationUnit.uM:
      case ConcentrationUnit.nM:
      case ConcentrationUnit.pM:
        return ConcentrationFamily.molar;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML:
      case ConcentrationUnit.ugML:
      case ConcentrationUnit.ngML:
        return ConcentrationFamily.massVolume;
      case ConcentrationUnit.percent:
        return ConcentrationFamily.percentage;
      case ConcentrationUnit.X:
        return ConcentrationFamily.fold;
      case ConcentrationUnit.gMol:
        return ConcentrationFamily.molecularWeight;
    }
  }

  /// Converts concentration to family's base unit (M, g/L, %, X)
  double _convertToBaseConc(double val, ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M: return val;
      case ConcentrationUnit.mM: return val * 1e-3;
      case ConcentrationUnit.uM: return val * 1e-6;
      case ConcentrationUnit.nM: return val * 1e-9;
      case ConcentrationUnit.pM: return val * 1e-12;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML: return val;
      case ConcentrationUnit.ugML: return val * 1e-3;
      case ConcentrationUnit.ngML: return val * 1e-6;
      case ConcentrationUnit.percent:
      case ConcentrationUnit.X:
      case ConcentrationUnit.gMol:
        return val;
    }
  }

  double _convertToUl(double val, VolumeUnit unit) {
    switch (unit) {
      case VolumeUnit.nL: return val / 1000;
      case VolumeUnit.uL: return val;
      case VolumeUnit.mL: return val * 1000;
      case VolumeUnit.L: return val * 1000000;
    }
  }

  String _formatVolume(double ul) {
    if (!ul.isFinite) return 'N/A';

    if (ul >= 1000000) {
      return '${(ul / 1000000).toStringAsFixed(_isClean(ul / 1000000) ? 0 : 2)} L';
    } else if (ul >= 1000) {
      final double ml = ul / 1000;
      return '${ml.toStringAsFixed(_isClean(ml) ? 0 : 2)} mL';
    } else if (ul >= 0.1) {
      return '${ul.toStringAsFixed(_isClean(ul) ? 0 : 1)} µL';
    } else {
      return '${(ul * 1000).toStringAsFixed(0)} nL';
    }
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

  bool _isClean(double val) {
    if (!val.isFinite) return false;
    return (val - val.round()).abs() < 0.0001;
  }

  String _unitLabel(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M: return 'M';
      case ConcentrationUnit.mM: return 'mM';
      case ConcentrationUnit.uM: return 'µM';
      case ConcentrationUnit.nM: return 'nM';
      case ConcentrationUnit.pM: return 'pM';
      case ConcentrationUnit.gL: return 'g/L';
      case ConcentrationUnit.mgML: return 'mg/mL';
      case ConcentrationUnit.ugML: return 'µg/mL';
      case ConcentrationUnit.ngML: return 'ng/mL';
      case ConcentrationUnit.percent: return '%';
      case ConcentrationUnit.X: return 'X';
      case ConcentrationUnit.gMol: return 'g/mol';
    }
  }
}

class _ReagentCalcParams {
  final MasterMixReagentInput input;
  final double ratio;
  _ReagentCalcParams({required this.input, required this.ratio});
}
