enum VolumeUnit { nL, uL, mL, L }

enum ConcentrationUnit {
  M,
  mM,
  uM,
  nM,
  pM,
  gL,
  mgML,
  ugML,
  ngML,
  percent,
  X,
  ratio,
  gMol,
}

enum ConcentrationFamily {
  molar,
  massVolume,
  percentage,
  fold,
  ratio,
  molecularWeight,
}

class LabCalculation {
  static const double minPipettableVolumeUl = 0.2;

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
      case ConcentrationUnit.mgML:
      case ConcentrationUnit.ugML:
      case ConcentrationUnit.ngML:
        return ConcentrationFamily.massVolume;
      case ConcentrationUnit.percent:
        return ConcentrationFamily.percentage;
      case ConcentrationUnit.X:
        return ConcentrationFamily.fold;
      case ConcentrationUnit.ratio:
        return ConcentrationFamily.ratio;
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
      case ConcentrationUnit.ugML:
        final gPerL = value * 1e-3;
        if (molecularWeight != null && molecularWeight > 0) {
          return gPerL / molecularWeight;
        }
        return gPerL;
      case ConcentrationUnit.ngML:
        final gPerL = value * 1e-6;
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
      case ConcentrationUnit.ugML:
        return value / 1e-3;
      case ConcentrationUnit.ngML:
        return value / 1e-6;
      case ConcentrationUnit.percent:
      case ConcentrationUnit.X:
      case ConcentrationUnit.ratio:
      case ConcentrationUnit.gMol:
        return value;
    }
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

  static String formatVolume(double ul, {bool unicodeMicro = false}) {
    final micro = unicodeMicro ? 'µL' : 'uL';
    if (!ul.isFinite) return 'N/A';
    if (ul == 0) return '0 $micro';
    if (ul >= 1000000) return '${formatNumber(ul / 1000000)} L';
    if (ul >= 1000) return '${formatNumber(ul / 1000)} mL';
    if (ul >= 0.1) return '${formatNumber(ul)} $micro';
    return '${formatNumber(ul * 1000)} nL';
  }

  static String formatMass(double grams, {bool unicodeMicro = false}) {
    final micro = unicodeMicro ? 'µg' : 'ug';
    if (!grams.isFinite) return 'N/A';
    if (grams >= 1) return '${formatNumber(grams)} g';
    if (grams >= 0.001) return '${formatNumber(grams * 1000)} mg';
    return '${formatNumber(grams * 1000000)} $micro';
  }

  static String formatConcentration(double baseValue, ConcentrationUnit unit) {
    return '${formatNumber(concentrationFromBase(baseValue, unit))} ${unitLabel(unit)}';
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
      case ConcentrationUnit.mgML:
        return 'mg/mL';
      case ConcentrationUnit.ugML:
        return '${micro}g/mL';
      case ConcentrationUnit.ngML:
        return 'ng/mL';
      case ConcentrationUnit.percent:
        return '%';
      case ConcentrationUnit.X:
        return 'X';
      case ConcentrationUnit.ratio:
        return 'ratio';
      case ConcentrationUnit.gMol:
        return 'g/mol';
    }
  }
}
