import 'dart:math' as math;

enum VolumeUnit { nL, uL, mL, L }

enum ReagentSourceType { liquidStock, solidMaterial }

enum ConcentrationUnit {
  M,
  mM,
  uM,
  nM,
  pM,
  gL,
  gUL,
  mgML,
  mgUL,
  ugML,
  ugUL,
  ngML,
  ngUL,
  percent,
  X,
  ratio,
  cellsML,
  gMol,
}

enum ConcentrationFamily {
  molar,
  massVolume,
  percentage,
  fold,
  ratio,
  cellDensity,
  molecularWeight,
}

class IntermediateDilutionSuggestion {
  final double intermediateStockConcentration;
  final ConcentrationUnit intermediateStockUnit;
  final double dilutionFactorFromStock;
  final double finalTransferVolumeUl;
  final double finalSolventVolumeUl;
  final String message;

  const IntermediateDilutionSuggestion({
    required this.intermediateStockConcentration,
    required this.intermediateStockUnit,
    required this.dilutionFactorFromStock,
    required this.finalTransferVolumeUl,
    required this.finalSolventVolumeUl,
    required this.message,
  });
}

class LabCalculation {
  static const double minPipettableVolumeUl = 0.2;
  static const double practicalMinimumTransferFraction = 0.05;

  const LabCalculation._();

  static ConcentrationFamily familyOf(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
      case ConcentrationUnit.mM:
      case ConcentrationUnit.uM:
      case ConcentrationUnit.nM:
      case ConcentrationUnit.pM:
        return ConcentrationFamily.molar;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.gUL:
      case ConcentrationUnit.mgML:
      case ConcentrationUnit.mgUL:
      case ConcentrationUnit.ugML:
      case ConcentrationUnit.ugUL:
      case ConcentrationUnit.ngML:
      case ConcentrationUnit.ngUL:
        return ConcentrationFamily.massVolume;
      case ConcentrationUnit.percent:
        return ConcentrationFamily.percentage;
      case ConcentrationUnit.X:
        return ConcentrationFamily.fold;
      case ConcentrationUnit.ratio:
        return ConcentrationFamily.ratio;
      case ConcentrationUnit.cellsML:
        return ConcentrationFamily.cellDensity;
      case ConcentrationUnit.gMol:
        return ConcentrationFamily.molecularWeight;
    }
  }

  static double volumeToUl(double value, VolumeUnit unit) {
    switch (unit) {
      case VolumeUnit.nL:
        return value / 1000;
      case VolumeUnit.uL:
        return value;
      case VolumeUnit.mL:
        return value * 1000;
      case VolumeUnit.L:
        return value * 1000000;
    }
  }

  static double concentrationToBase(
    double value,
    ConcentrationUnit unit, {
    double? molecularWeight,
  }) {
    switch (unit) {
      case ConcentrationUnit.M:
        return value;
      case ConcentrationUnit.mM:
        return value * 1e-3;
      case ConcentrationUnit.uM:
        return value * 1e-6;
      case ConcentrationUnit.nM:
        return value * 1e-9;
      case ConcentrationUnit.pM:
        return value * 1e-12;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML:
        if (molecularWeight != null && molecularWeight > 0) {
          return value / molecularWeight;
        }
        return value;
      case ConcentrationUnit.gUL:
        final gPerL = value * 1e6;
        if (molecularWeight != null && molecularWeight > 0) {
          return gPerL / molecularWeight;
        }
        return gPerL;
      case ConcentrationUnit.mgUL:
        final gPerL = value * 1e3;
        if (molecularWeight != null && molecularWeight > 0) {
          return gPerL / molecularWeight;
        }
        return gPerL;
      case ConcentrationUnit.ugML:
        final gPerL = value * 1e-3;
        if (molecularWeight != null && molecularWeight > 0) {
          return gPerL / molecularWeight;
        }
        return gPerL;
      case ConcentrationUnit.ugUL:
        if (molecularWeight != null && molecularWeight > 0) {
          return value / molecularWeight;
        }
        return value;
      case ConcentrationUnit.ngML:
        final gPerL = value * 1e-6;
        if (molecularWeight != null && molecularWeight > 0) {
          return gPerL / molecularWeight;
        }
        return gPerL;
      case ConcentrationUnit.ngUL:
        final gPerL = value * 1e-3;
        if (molecularWeight != null && molecularWeight > 0) {
          return gPerL / molecularWeight;
        }
        return gPerL;
      case ConcentrationUnit.percent:
        if (molecularWeight != null && molecularWeight > 0) {
          return (value * 10) / molecularWeight;
        }
        return value;
      case ConcentrationUnit.X:
        return value;
      case ConcentrationUnit.ratio:
        return value == 0 ? 0 : 1.0 / value;
      case ConcentrationUnit.cellsML:
        return value;
      case ConcentrationUnit.gMol:
        return value;
    }
  }

  static double concentrationFromBase(double value, ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return value;
      case ConcentrationUnit.mM:
        return value / 1e-3;
      case ConcentrationUnit.uM:
        return value / 1e-6;
      case ConcentrationUnit.nM:
        return value / 1e-9;
      case ConcentrationUnit.pM:
        return value / 1e-12;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML:
        return value;
      case ConcentrationUnit.gUL:
        return value / 1e6;
      case ConcentrationUnit.mgUL:
        return value / 1e3;
      case ConcentrationUnit.ugML:
        return value / 1e-3;
      case ConcentrationUnit.ugUL:
        return value;
      case ConcentrationUnit.ngML:
        return value / 1e-6;
      case ConcentrationUnit.ngUL:
        return value / 1e-3;
      case ConcentrationUnit.percent:
      case ConcentrationUnit.X:
      case ConcentrationUnit.cellsML:
      case ConcentrationUnit.gMol:
        return value;
      case ConcentrationUnit.ratio:
        return value == 0 ? 0 : 1.0 / value;
    }
  }

  static double? parseConcentrationInput(
    String input,
    ConcentrationUnit unit, {
    int cellsExponent = 0,
  }) {
    final trimmed = input.trim();
    if (unit == ConcentrationUnit.ratio) {
      final parts = trimmed.split(RegExp(r'[:/]'));
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0].trim());
        final denominator = double.tryParse(parts[1].trim());
        if (numerator == null ||
            denominator == null ||
            numerator <= 0 ||
            denominator <= 0) {
          return null;
        }
        return denominator / numerator;
      }
    }

    final value = double.tryParse(trimmed);
    if (value == null) return null;
    if (unit == ConcentrationUnit.cellsML) {
      return value * _powerOfTen(cellsExponent);
    }
    return value;
  }

  static String concentrationInputText(double value, ConcentrationUnit unit) {
    if (unit == ConcentrationUnit.ratio) {
      return '1:${formatNumber(value)}';
    }
    if (unit == ConcentrationUnit.cellsML) {
      return formatNumber(cellsCoefficient(value));
    }
    return formatNumber(value);
  }

  static int cellsExponent(double value, {int fallback = 6}) {
    if (!value.isFinite || value == 0) return fallback;
    return (math.log(value.abs()) / math.ln10).floor();
  }

  static double cellsCoefficient(double value, {int fallbackExponent = 6}) {
    if (!value.isFinite || value == 0) return value;
    return value /
        _powerOfTen(cellsExponent(value, fallback: fallbackExponent));
  }

  static String formatInputConcentration(double value, ConcentrationUnit unit) {
    return formatConcentration(concentrationToBase(value, unit), unit);
  }

  static double decimalPenalty(double value) {
    if (!value.isFinite) return 100;
    if ((value - value.round()).abs() < 0.0001) return 0;
    if (((value * 2) - (value * 2).round()).abs() < 0.0001) return 1;
    return 10;
  }

  static double pipettingScore({
    required double totalUl,
    required double requestedUl,
    required Iterable<double> measuredVolumesUl,
    double totalWeight = 0.1,
  }) {
    var score = (totalUl - requestedUl) * totalWeight;
    score += decimalPenalty(totalUl) * 0.5;
    for (final value in measuredVolumesUl) {
      score += decimalPenalty(value);
      if (value < 1) score += 10;
    }
    return score;
  }

  static List<String> lowVolumeWarnings(
    double volumeUl, {
    String label = 'Volume',
  }) {
    if (volumeUl < minPipettableVolumeUl) {
      return ['$label below minimum pipettable volume.'];
    }
    if (volumeUl < 1) {
      return ['$label below recommended pipetting range.'];
    }
    return const [];
  }

  static bool isBelowPracticalTransferFraction({
    required double transferUl,
    required double totalUl,
    double minimumFraction = practicalMinimumTransferFraction,
  }) {
    if (transferUl <= 0 || totalUl <= 0) return false;
    return transferUl / totalUl < minimumFraction;
  }

  static String practicalTransferWarning({
    required double transferUl,
    required double totalUl,
    double minimumFraction = practicalMinimumTransferFraction,
  }) {
    final fraction = totalUl <= 0 ? 0 : transferUl / totalUl;
    return 'Direct transfer is ${formatNumber(fraction * 100)}% of the final volume. For better accuracy, use at least ${formatNumber(minimumFraction * 100)}% or prepare an intermediate stock.';
  }

  static double? solidMassForConcentration({
    required double concentration,
    required ConcentrationUnit unit,
    required double volumeUl,
    double? molecularWeight,
  }) {
    if (concentration <= 0 || volumeUl <= 0) return null;
    final volumeL = volumeUl / 1e6;
    final family = familyOf(unit);
    if (family == ConcentrationFamily.molar) {
      if (molecularWeight == null || molecularWeight <= 0) return null;
      return concentrationToBase(concentration, unit) *
          volumeL *
          molecularWeight;
    }
    if (family == ConcentrationFamily.massVolume) {
      return concentrationToBase(concentration, unit) * volumeL;
    }
    if (family == ConcentrationFamily.percentage) {
      return (concentration / 100.0) * (volumeL * 1000);
    }
    return null;
  }

  static IntermediateDilutionSuggestion? intermediateDilutionSuggestion({
    required double stockConcentrationBase,
    required double targetConcentrationBase,
    required ConcentrationUnit targetDisplayUnit,
    required double totalVolumeUl,
    double minimumTransferFraction = practicalMinimumTransferFraction,
  }) {
    if (stockConcentrationBase <= 0 ||
        targetConcentrationBase <= 0 ||
        totalVolumeUl <= 0 ||
        minimumTransferFraction <= 0) {
      return null;
    }

    final intermediateBase = targetConcentrationBase / minimumTransferFraction;
    if (intermediateBase >= stockConcentrationBase) return null;

    final dilutionFactorFromStock = stockConcentrationBase / intermediateBase;
    final intermediateConcentration = concentrationFromBase(
      intermediateBase,
      targetDisplayUnit,
    );
    final finalTransferVolumeUl = totalVolumeUl * minimumTransferFraction;
    final finalSolventVolumeUl = totalVolumeUl - finalTransferVolumeUl;

    final intermediateLabel =
        '${formatNumber(intermediateConcentration)} ${unitLabel(targetDisplayUnit)}';
    final dilutionLabel = '1:${formatNumber(dilutionFactorFromStock)}';
    final stepNote = dilutionFactorFromStock > 20
        ? ' Prepare it as serial intermediate dilutions so each transfer can stay near ${formatNumber(minimumTransferFraction * 100)}% or higher.'
        : '';

    return IntermediateDilutionSuggestion(
      intermediateStockConcentration: intermediateConcentration,
      intermediateStockUnit: targetDisplayUnit,
      dilutionFactorFromStock: dilutionFactorFromStock,
      finalTransferVolumeUl: finalTransferVolumeUl,
      finalSolventVolumeUl: finalSolventVolumeUl,
      message:
          'Suggested intermediate: make a $intermediateLabel intermediate stock ($dilutionLabel from the original stock). Then use ${formatVolume(finalTransferVolumeUl, unicodeMicro: true)} intermediate + ${formatVolume(finalSolventVolumeUl, unicodeMicro: true)} solvent for the final mix.$stepNote',
    );
  }

  static String formatVolume(double ul, {bool unicodeMicro = false}) {
    final micro = unicodeMicro ? 'µL' : 'uL';
    if (!ul.isFinite) return 'N/A';
    if (ul == 0) return '0.000 $micro';
    if (ul >= 1000000) return '${(ul / 1000000).toStringAsFixed(3)} L';
    if (ul >= 1000) return '${(ul / 1000).toStringAsFixed(3)} mL';
    if (ul >= 0.1) return '${ul.toStringAsFixed(3)} $micro';
    return '${(ul * 1000).toStringAsFixed(3)} nL';
  }

  static String formatMass(double grams, {bool unicodeMicro = false}) {
    final micro = unicodeMicro ? 'µg' : 'ug';
    if (!grams.isFinite) return 'N/A';
    if (grams >= 1) return '${formatNumber(grams)} g';
    if (grams >= 0.001) return '${formatNumber(grams * 1000)} mg';
    return '${formatNumber(grams * 1000000)} $micro';
  }

  static String formatConcentration(double baseValue, ConcentrationUnit unit) {
    if (unit == ConcentrationUnit.ratio) {
      return '1:${formatNumber(concentrationFromBase(baseValue, unit))}';
    }
    if (unit == ConcentrationUnit.cellsML) {
      final value = concentrationFromBase(baseValue, unit);
      if (value > 0) {
        final exponent = (math.log(value) / math.ln10).floor();
        final mantissa = value / _powerOfTen(exponent);
        return '${formatNumber(mantissa)} x 10^$exponent cells/mL';
      }
    }
    return '${formatNumber(concentrationFromBase(baseValue, unit))} ${unitLabel(unit)}';
  }

  static double _powerOfTen(int exponent) {
    var value = 1.0;
    for (var index = 0; index < exponent.abs(); index++) {
      value = exponent >= 0 ? value * 10 : value / 10;
    }
    return value;
  }

  static String formatNumber(double value) {
    if (!value.isFinite) return 'N/A';
    if ((value - value.round()).abs() < 0.0001) {
      return value.round().toString();
    }
    if (value.abs() >= 100) return value.toStringAsFixed(1);
    if (value.abs() >= 10) return value.toStringAsFixed(2);
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String unitLabel(ConcentrationUnit unit, {bool unicodeMicro = false}) {
    final micro = unicodeMicro ? 'µ' : 'u';
    switch (unit) {
      case ConcentrationUnit.M:
        return 'M';
      case ConcentrationUnit.mM:
        return 'mM';
      case ConcentrationUnit.uM:
        return '${micro}M';
      case ConcentrationUnit.nM:
        return 'nM';
      case ConcentrationUnit.pM:
        return 'pM';
      case ConcentrationUnit.gL:
        return 'g/L';
      case ConcentrationUnit.gUL:
        return 'g/${micro}L';
      case ConcentrationUnit.mgML:
        return 'mg/mL';
      case ConcentrationUnit.mgUL:
        return 'mg/${micro}L';
      case ConcentrationUnit.ugML:
        return '${micro}g/mL';
      case ConcentrationUnit.ugUL:
        return '${micro}g/${micro}L';
      case ConcentrationUnit.ngML:
        return 'ng/mL';
      case ConcentrationUnit.ngUL:
        return 'ng/${micro}L';
      case ConcentrationUnit.percent:
        return '%';
      case ConcentrationUnit.X:
        return 'X';
      case ConcentrationUnit.ratio:
        return 'ratio';
      case ConcentrationUnit.cellsML:
        return 'cells/mL';
      case ConcentrationUnit.gMol:
        return 'g/mol';
    }
  }
}
