import 'dart:math';

import '../../master_mix/services/master_mix_calculator_service.dart'
    show ConcentrationFamily, ConcentrationUnit, VolumeUnit;
import '../models/serial_dilution_input.dart';
import '../models/serial_dilution_result.dart';
import '../models/serial_dilution_row.dart';

class SerialDilutionCalculatorService {
  static const double minPipettableVolumeUl = 0.2;
  static const int maxDilutions = 50;

  SerialDilutionResult generateDilutionTable(SerialDilutionInput input) {
    final validationError = _validateBasics(input);
    if (validationError != null) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: validationError,
      );
    }

    final stockFamily = _getFamily(input.stockConcentrationUnit);
    final stockBase = _convertToBaseConc(
      input.stockConcentration,
      input.stockConcentrationUnit,
    );
    final startingUnit =
        input.startingDilutionConcentrationUnit ?? input.stockConcentrationUnit;
    final startingFamily = _getFamily(startingUnit);
    if (startingFamily != stockFamily) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage:
            'Cannot convert ${_unitLabel(input.stockConcentrationUnit)} to ${_unitLabel(startingUnit)} without molecular weight.',
      );
    }

    final startingConcentration =
        input.startingDilutionConcentration ??
        _convertFromBaseConc(stockBase / input.dilutionFactor, startingUnit);
    final startingBase = _convertToBaseConc(
      startingConcentration,
      startingUnit,
    );
    if (startingBase <= 0) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: 'Starting dilution concentration must be greater than 0.',
      );
    }
    if (startingBase > stockBase) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage:
            'Starting dilution concentration cannot be higher than stock concentration.',
      );
    }

    int dilutionCount;
    if (input.seriesLengthMode == SeriesLengthMode.targetLowestConcentration) {
      final targetUnit =
          input.targetLowestConcentrationUnit ?? input.stockConcentrationUnit;
      final targetFamily = _getFamily(targetUnit);
      if (targetFamily != stockFamily) {
        return SerialDilutionResult(
          success: false,
          title: input.title,
          errorMessage:
              'Cannot convert ${_unitLabel(input.stockConcentrationUnit)} to ${_unitLabel(targetUnit)} without molecular weight.',
        );
      }

      final targetBase = _convertToBaseConc(
        input.targetLowestConcentration ?? 0,
        targetUnit,
      );
      if (targetBase <= 0) {
        return SerialDilutionResult(
          success: false,
          title: input.title,
          errorMessage: 'Target lowest concentration must be greater than 0.',
        );
      }
      if (targetBase >= startingBase) {
        return SerialDilutionResult(
          success: false,
          title: input.title,
          errorMessage:
              'Target lowest concentration must be lower than starting dilution concentration.',
        );
      }

      dilutionCount = _calculateDilutionCount(
        startingBase,
        targetBase,
        input.dilutionFactor,
      );
      if (dilutionCount > maxDilutions) {
        return SerialDilutionResult(
          success: false,
          title: input.title,
          errorMessage:
              'Target concentration requires too many dilution steps. Please increase the dilution factor or target concentration.',
        );
      }
    } else {
      dilutionCount = input.numberOfDilutions ?? 0;
    }

    if (dilutionCount < 1) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: 'Number of dilutions must be at least 1.',
      );
    }
    if (dilutionCount > maxDilutions) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: 'Number of dilutions cannot exceed $maxDilutions.',
      );
    }

    final requestedUl = _convertToUl(input.finalVolume, input.finalVolumeUnit);
    final requestedWithExtra =
        requestedUl * (1 + input.extraVolumePercent.clamp(0, 100) / 100);
    final preparedVolumeRequestUl = input.dilutionMode == DilutionMode.forward
        ? requestedWithExtra * input.dilutionFactor / (input.dilutionFactor - 1)
        : requestedWithExtra;
    final smallestRatio = min(
      startingBase / stockBase,
      input.dilutionMode == DilutionMode.forward
          ? 1 / input.dilutionFactor
          : (startingBase / stockBase) /
                pow(input.dilutionFactor, dilutionCount).toDouble(),
    );
    final optimizedFinalVolumeUl = input.dilutionMode == DilutionMode.forward
        ? _ensureMinimumPipettableVolume(preparedVolumeRequestUl, smallestRatio)
        : _optimizeFinalVolume(preparedVolumeRequestUl, smallestRatio);
    final retainedVolumeUl = input.dilutionMode == DilutionMode.forward
        ? optimizedFinalVolumeUl -
              (optimizedFinalVolumeUl / input.dilutionFactor)
        : optimizedFinalVolumeUl;

    final rows = <SerialDilutionRow>[
      SerialDilutionRow(
        dilutionName: input.stockSolutionName.isEmpty
            ? 'Stock'
            : input.stockSolutionName,
        concentrationBaseUnit: stockBase,
        formattedConcentration: _formatConcentration(
          stockBase,
          input.stockConcentrationUnit,
        ),
        transferFrom: '-',
        transferVolumeUl: 0,
        formattedTransferVolume: '-',
        solventVolumeUl: 0,
        formattedSolventVolume: '-',
        finalVolumeUl: 0,
        formattedFinalVolume: '-',
      ),
    ];
    final warnings = <String>[];

    final startingTransferVolumeUl =
        optimizedFinalVolumeUl * (startingBase / stockBase);
    final startingSolventVolumeUl =
        optimizedFinalVolumeUl - startingTransferVolumeUl;
    final startingWarnings = _volumeWarnings(startingTransferVolumeUl);
    warnings.addAll(startingWarnings.map((w) => 'D0: $w'));
    rows.add(
      SerialDilutionRow(
        dilutionName: 'D0',
        concentrationBaseUnit: startingBase,
        formattedConcentration: _formatConcentration(
          startingBase,
          input.stockConcentrationUnit,
        ),
        transferFrom: input.stockSolutionName.isEmpty
            ? 'Stock'
            : input.stockSolutionName,
        transferVolumeUl: startingTransferVolumeUl,
        formattedTransferVolume: _formatVolume(startingTransferVolumeUl),
        solventVolumeUl: startingSolventVolumeUl,
        formattedSolventVolume: _formatVolume(startingSolventVolumeUl),
        finalVolumeUl: optimizedFinalVolumeUl,
        formattedFinalVolume: _formatVolume(optimizedFinalVolumeUl),
        warnings: startingWarnings,
      ),
    );

    for (var i = 1; i <= dilutionCount; i++) {
      final concentrationBase =
          startingBase / pow(input.dilutionFactor, i).toDouble();
      final ratio = input.dilutionMode == DilutionMode.forward
          ? 1 / input.dilutionFactor
          : concentrationBase / stockBase;
      final transferVolumeUl = optimizedFinalVolumeUl * ratio;
      final solventVolumeUl = optimizedFinalVolumeUl - transferVolumeUl;
      final rowWarnings = _volumeWarnings(transferVolumeUl);
      warnings.addAll(rowWarnings.map((w) => 'D$i: $w'));

      rows.add(
        SerialDilutionRow(
          dilutionName: 'D$i',
          concentrationBaseUnit: concentrationBase,
          formattedConcentration: _formatConcentration(
            concentrationBase,
            input.stockConcentrationUnit,
          ),
          transferFrom: input.dilutionMode == DilutionMode.forward
              ? (i == 1 ? 'D0' : 'D${i - 1}')
              : (input.stockSolutionName.isEmpty
                    ? 'Stock'
                    : input.stockSolutionName),
          transferVolumeUl: transferVolumeUl,
          formattedTransferVolume: _formatVolume(transferVolumeUl),
          solventVolumeUl: solventVolumeUl,
          formattedSolventVolume: _formatVolume(solventVolumeUl),
          finalVolumeUl: optimizedFinalVolumeUl,
          formattedFinalVolume: _formatVolume(optimizedFinalVolumeUl),
          warnings: rowWarnings,
        ),
      );
    }

    if (input.includeZeroConcentrationRow) {
      rows.add(
        SerialDilutionRow(
          dilutionName: 'Blank',
          concentrationBaseUnit: 0,
          formattedConcentration:
              '0 ${_unitLabel(input.stockConcentrationUnit)}',
          transferFrom: 'Solvent only',
          transferVolumeUl: 0,
          formattedTransferVolume: _formatVolume(0),
          solventVolumeUl: retainedVolumeUl,
          formattedSolventVolume: _formatVolume(retainedVolumeUl),
          finalVolumeUl: retainedVolumeUl,
          formattedFinalVolume: _formatVolume(retainedVolumeUl),
          isZeroConcentrationRow: true,
        ),
      );
    }

    if (rows.any((r) => r.solventVolumeUl < 0)) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: 'Negative volume calculated.',
      );
    }

    return SerialDilutionResult(
      success: true,
      title: input.title,
      calculatedNumberOfDilutions: dilutionCount,
      optimizedFinalVolumeUl: optimizedFinalVolumeUl,
      formattedOptimizedFinalVolume: _formatVolume(optimizedFinalVolumeUl),
      rows: rows,
      warnings: warnings.toSet().toList(),
    );
  }

  String? _validateBasics(SerialDilutionInput input) {
    if (input.stockConcentration <= 0 || input.stockConcentration.isNaN) {
      return 'Stock concentration must be greater than 0.';
    }
    if (input.dilutionFactor <= 1 || input.dilutionFactor.isNaN) {
      return 'Dilution factor must be greater than 1.';
    }
    if (input.finalVolume <= 0 || input.finalVolume.isNaN) {
      return 'Final volume must be greater than 0.';
    }
    if (_getFamily(input.stockConcentrationUnit) ==
        ConcentrationFamily.molecularWeight) {
      return 'Molecular weight cannot be used as a serial dilution concentration unit.';
    }
    if (_getFamily(input.stockConcentrationUnit) == ConcentrationFamily.fold) {
      return 'Fold units cannot be used as serial dilution concentration units.';
    }
    return null;
  }

  int _calculateDilutionCount(
    double stockBase,
    double targetBase,
    double dilutionFactor,
  ) {
    return (log(stockBase / targetBase) / log(dilutionFactor)).ceil();
  }

  List<String> _volumeWarnings(double transferVolumeUl) {
    if (transferVolumeUl < minPipettableVolumeUl) {
      return ['Transfer volume below minimum pipettable volume.'];
    }
    if (transferVolumeUl < 1) {
      return ['Transfer volume below recommended pipetting range.'];
    }
    return const [];
  }

  double _optimizeFinalVolume(double requestedUl, double smallestRatio) {
    final minNeeded = minPipettableVolumeUl / smallestRatio;
    final start = max(requestedUl, minNeeded);
    final maxTotal = start * 1.3;
    final step = start < 100 ? 0.1 : (start < 1000 ? 1.0 : 10.0);

    var best = start;
    var bestScore = double.infinity;
    for (var candidate = start; candidate <= maxTotal; candidate += step) {
      final transfer = candidate * smallestRatio;
      if (transfer < minPipettableVolumeUl) continue;
      final score = _pipettingScore(candidate, start, transfer);
      if (score < bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return (best * 10).round() / 10;
  }

  double _ensureMinimumPipettableVolume(
    double requestedUl,
    double smallestRatio,
  ) {
    final minNeeded = minPipettableVolumeUl / smallestRatio;
    return (max(requestedUl, minNeeded) * 10).round() / 10;
  }

  double _pipettingScore(
    double totalUl,
    double requestedUl,
    double transferUl,
  ) {
    var score = (totalUl - requestedUl) * 0.1;
    score += _decimalPenalty(totalUl) * 0.5;
    score += _decimalPenalty(transferUl);
    if (transferUl < 1) score += 10;
    return score;
  }

  double _decimalPenalty(double val) {
    if ((val - val.round()).abs() < 0.0001) return 0;
    if (((val * 2) - (val * 2).round()).abs() < 0.0001) return 1;
    return 10;
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

  double _convertToBaseConc(double val, ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return val;
      case ConcentrationUnit.mM:
        return val * 1e-3;
      case ConcentrationUnit.uM:
        return val * 1e-6;
      case ConcentrationUnit.nM:
        return val * 1e-9;
      case ConcentrationUnit.pM:
        return val * 1e-12;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML:
        return val;
      case ConcentrationUnit.ugML:
        return val * 1e-3;
      case ConcentrationUnit.ngML:
        return val * 1e-6;
      case ConcentrationUnit.percent:
      case ConcentrationUnit.X:
      case ConcentrationUnit.gMol:
        return val;
    }
  }

  double _convertFromBaseConc(double val, ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return val;
      case ConcentrationUnit.mM:
        return val / 1e-3;
      case ConcentrationUnit.uM:
        return val / 1e-6;
      case ConcentrationUnit.nM:
        return val / 1e-9;
      case ConcentrationUnit.pM:
        return val / 1e-12;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML:
        return val;
      case ConcentrationUnit.ugML:
        return val / 1e-3;
      case ConcentrationUnit.ngML:
        return val / 1e-6;
      case ConcentrationUnit.percent:
      case ConcentrationUnit.X:
      case ConcentrationUnit.gMol:
        return val;
    }
  }

  double _convertToUl(double val, VolumeUnit unit) {
    switch (unit) {
      case VolumeUnit.nL:
        return val / 1000;
      case VolumeUnit.uL:
        return val;
      case VolumeUnit.mL:
        return val * 1000;
      case VolumeUnit.L:
        return val * 1000000;
    }
  }

  String _formatConcentration(double baseValue, ConcentrationUnit unit) {
    final value = _convertFromBaseConc(baseValue, unit);
    return '${_formatNumber(value)} ${_unitLabel(unit)}';
  }

  String _formatVolume(double ul) {
    if (ul == 0) return '0 uL';
    if (ul >= 1000000) return '${_formatNumber(ul / 1000000)} L';
    if (ul >= 1000) return '${_formatNumber(ul / 1000)} mL';
    if (ul >= 0.1) return '${_formatNumber(ul)} uL';
    return '${_formatNumber(ul * 1000)} nL';
  }

  String _formatNumber(double value) {
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

  String _unitLabel(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return 'M';
      case ConcentrationUnit.mM:
        return 'mM';
      case ConcentrationUnit.uM:
        return 'uM';
      case ConcentrationUnit.nM:
        return 'nM';
      case ConcentrationUnit.pM:
        return 'pM';
      case ConcentrationUnit.gL:
        return 'g/L';
      case ConcentrationUnit.mgML:
        return 'mg/mL';
      case ConcentrationUnit.ugML:
        return 'ug/mL';
      case ConcentrationUnit.ngML:
        return 'ng/mL';
      case ConcentrationUnit.percent:
        return '%';
      case ConcentrationUnit.X:
        return 'X';
      case ConcentrationUnit.gMol:
        return 'g/mol';
    }
  }
}
