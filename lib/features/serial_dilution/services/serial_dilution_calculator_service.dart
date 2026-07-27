import 'dart:math';

import '../../lab_math/lab_calculation.dart';
import '../../measuring_tools/services/mass_measurement_optimizer_service.dart';
import '../../measuring_tools/services/measuring_tool_service.dart';
import '../../measuring_tools/services/transfer_optimizer_service.dart';
import '../models/serial_dilution_input.dart';
import '../models/serial_dilution_result.dart';
import '../models/serial_dilution_row.dart';

class SerialDilutionCalculatorService {
  static const int maxDilutions = 50;

  final TransferOptimizerService _optimizer = const TransferOptimizerService();
  final MassMeasurementOptimizerService _massOptimizer =
      const MassMeasurementOptimizerService();
  final MeasuringToolService _measuringToolService =
      MeasuringToolService.instance;

  SerialDilutionResult generateDilutionTable(SerialDilutionInput input) {
    final validationError = _validateBasics(input);
    if (validationError != null) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: validationError,
      );
    }

    final startingUnit =
        input.startingDilutionConcentrationUnit ?? input.stockConcentrationUnit;
    final isSolidSource =
        input.startingSourceType == ReagentSourceType.solidMaterial;
    final stockFamily = isSolidSource
        ? _getFamily(startingUnit)
        : _getFamily(input.stockConcentrationUnit);
    final stockBase = isSolidSource
        ? 0.0
        : _convertToBaseConc(
            input.stockConcentration,
            input.stockConcentrationUnit,
          );
    final startingFamily = _getFamily(startingUnit);
    if (startingFamily != stockFamily) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage:
            'Cannot convert ${_unitLabel(input.stockConcentrationUnit)} to ${_unitLabel(startingUnit)} without molecular weight.',
      );
    }
    if (isSolidSource &&
        startingFamily != ConcentrationFamily.massVolume &&
        startingFamily != ConcentrationFamily.percentage &&
        startingFamily != ConcentrationFamily.molar) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage:
            'Solid starting source must use mass/volume, percent w/v, or molar concentration.',
      );
    }
    if (isSolidSource &&
        startingFamily == ConcentrationFamily.molar &&
        (input.molecularWeight == null || input.molecularWeight! <= 0)) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage:
            'Molecular weight is required for solid starting source with molar concentration.',
      );
    }

    final startingConcentration =
        input.startingDilutionConcentration ??
        (isSolidSource
            ? 0.0
            : _convertFromBaseConc(
                stockBase / input.dilutionFactor,
                startingUnit,
              ));
    final startingBase = _convertToBaseConc(
      startingConcentration,
      startingUnit,
    );
    final seriesSourceBase = isSolidSource ? startingBase : stockBase;
    final displayUnit = isSolidSource
        ? startingUnit
        : input.stockConcentrationUnit;
    if (startingBase <= 0) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: 'Starting dilution concentration must be greater than 0.',
      );
    }
    if (!isSolidSource && startingBase > stockBase) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage:
            'Starting dilution concentration cannot be higher than stock concentration.',
      );
    }

    final dilutionCount = _resolveDilutionCount(
      input,
      seriesSourceBase,
      startingBase,
      stockFamily,
    );
    if (dilutionCount.errorMessage != null) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: dilutionCount.errorMessage,
      );
    }

    final requestedUl = _convertToUl(input.finalVolume, input.finalVolumeUnit);
    final tools = _measuringToolService.activeTools();

    _SerialDilutionCandidate buildCandidate(double extraPercent) {
      final requestedWithExtra = requestedUl * (1 + extraPercent / 100);
      final preparedVolumeUl = input.dilutionMode == DilutionMode.forward
          ? requestedWithExtra *
                input.dilutionFactor /
                (input.dilutionFactor - 1)
          : requestedWithExtra;
      final retainedVolumeUl = input.dilutionMode == DilutionMode.forward
          ? preparedVolumeUl - (preparedVolumeUl / input.dilutionFactor)
          : preparedVolumeUl;

      final rows = <SerialDilutionRow>[];
      if (!isSolidSource) {
        rows.add(
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
        );
      }
      final warnings = <String>[];
      final evaluations = <TransferEvaluationResult>[];

      SerialDilutionRow buildMeasuredRow({
        required String name,
        required double concentrationBase,
        required String transferFrom,
        required double transferVolumeUl,
        required double solventVolumeUl,
        required double finalVolumeUl,
        bool isZeroConcentrationRow = false,
      }) {
        final sourceBase =
            transferFrom == 'Stock' ||
                transferFrom == input.stockSolutionName ||
                transferFrom == '-' ||
                (isSolidSource && transferFrom == 'D0')
            ? seriesSourceBase
            : concentrationBase * input.dilutionFactor;
        final suggestionMessage = transferVolumeUl > 0
            ? _optimizer.suggestIntermediateDilution(
                sourceConcentrationBase: sourceBase,
                targetConcentrationBase: concentrationBase,
                totalVolumeUl: finalVolumeUl,
                tools: tools,
              )
            : null;

        final transferEvaluation = transferVolumeUl > 0
            ? _optimizer.evaluateTransferVolume(
                transferVolumeUl,
                tools,
                componentName: name,
                intermediateSuggestion: suggestionMessage,
              )
            : null;
        final solventEvaluation = solventVolumeUl > 0
            ? _optimizer.evaluateTransferVolume(solventVolumeUl, tools)
            : null;

        if (transferEvaluation != null) {
          evaluations.add(transferEvaluation);
        }
        if (solventEvaluation != null) {
          evaluations.add(solventEvaluation);
        }

        final rowWarnings = <String>[
          if (transferEvaluation?.warningMessage != null)
            transferEvaluation!.warningMessage!,
          if (solventEvaluation?.warningMessage != null)
            '${input.solventName}: ${solventEvaluation!.warningMessage!}',
        ];
        final rowSuggestions = <IntermediateDilutionSuggestion>[];
        if (transferEvaluation?.suggestionMessage != null) {
          final intermediate = LabCalculation.intermediateDilutionSuggestion(
            stockConcentrationBase: sourceBase,
            targetConcentrationBase: concentrationBase,
            targetDisplayUnit: displayUnit,
            totalVolumeUl: finalVolumeUl,
          );
          if (intermediate != null) {
            rowSuggestions.add(intermediate);
          }
        }
        warnings.addAll(rowWarnings.map((warning) => '$name: $warning'));

        return SerialDilutionRow(
          dilutionName: name,
          concentrationBaseUnit: concentrationBase,
          formattedConcentration: _formatConcentration(
            concentrationBase,
            displayUnit,
          ),
          transferFrom: transferFrom,
          transferVolumeUl: transferVolumeUl,
          formattedTransferVolume: _formatVolume(transferVolumeUl),
          solventVolumeUl: solventVolumeUl,
          formattedSolventVolume: _formatVolume(solventVolumeUl),
          finalVolumeUl: finalVolumeUl,
          formattedFinalVolume: _formatVolume(finalVolumeUl),
          isZeroConcentrationRow: isZeroConcentrationRow,
          warnings: rowWarnings,
          suggestions: rowSuggestions,
          transferEvaluation: transferEvaluation,
          solventTransferEvaluation: solventEvaluation,
        );
      }

      if (isSolidSource) {
        final massGrams = LabCalculation.solidMassForConcentration(
          concentration: startingConcentration,
          unit: startingUnit,
          volumeUl: preparedVolumeUl,
          molecularWeight: input.molecularWeight,
        );
        if (massGrams == null) {
          return _SerialDilutionCandidate.invalid(extraPercent);
        }
        final massEvaluation = _massOptimizer.evaluateMass(
          massGrams * 1000,
          tools,
          componentName: input.stockSolutionName,
        );
        final rowWarnings = <String>[
          if (massEvaluation.warningMessage != null)
            massEvaluation.warningMessage!,
        ];
        warnings.addAll(rowWarnings.map((warning) => 'D0: $warning'));
        rows.add(
          SerialDilutionRow(
            dilutionName: 'D0',
            concentrationBaseUnit: startingBase,
            formattedConcentration: _formatConcentration(
              startingBase,
              startingUnit,
            ),
            transferFrom: input.stockSolutionName.isEmpty
                ? 'Solid material'
                : input.stockSolutionName,
            transferVolumeUl: 0,
            formattedTransferVolume: LabCalculation.formatMass(
              massGrams,
              unicodeMicro: true,
            ),
            solventVolumeUl: preparedVolumeUl,
            formattedSolventVolume:
                'Bring to ${_formatVolume(preparedVolumeUl)}',
            finalVolumeUl: preparedVolumeUl,
            formattedFinalVolume: _formatVolume(preparedVolumeUl),
            warnings: rowWarnings,
            massEvaluation: massEvaluation,
          ),
        );
      } else {
        final d0TransferVolumeUl =
            preparedVolumeUl * (startingBase / stockBase);
        final d0SolventVolumeUl = preparedVolumeUl - d0TransferVolumeUl;
        rows.add(
          buildMeasuredRow(
            name: 'D0',
            concentrationBase: startingBase,
            transferFrom: input.stockSolutionName.isEmpty
                ? 'Stock'
                : input.stockSolutionName,
            transferVolumeUl: d0TransferVolumeUl,
            solventVolumeUl: d0SolventVolumeUl,
            finalVolumeUl: preparedVolumeUl,
          ),
        );
      }

      for (var i = 1; i <= dilutionCount.count; i++) {
        final concentrationBase =
            startingBase / pow(input.dilutionFactor, i).toDouble();
        final ratio = input.dilutionMode == DilutionMode.forward
            ? 1 / input.dilutionFactor
            : concentrationBase / seriesSourceBase;
        final transferVolumeUl = preparedVolumeUl * ratio;
        final solventVolumeUl = preparedVolumeUl - transferVolumeUl;
        rows.add(
          buildMeasuredRow(
            name: 'D$i',
            concentrationBase: concentrationBase,
            transferFrom: input.dilutionMode == DilutionMode.forward
                ? (i == 1 ? 'D0' : 'D${i - 1}')
                : isSolidSource
                ? 'D0'
                : (input.stockSolutionName.isEmpty
                      ? 'Stock'
                      : input.stockSolutionName),
            transferVolumeUl: transferVolumeUl,
            solventVolumeUl: solventVolumeUl,
            finalVolumeUl: preparedVolumeUl,
          ),
        );
      }

      if (input.includeZeroConcentrationRow) {
        rows.add(
          buildMeasuredRow(
            name: 'Blank',
            concentrationBase: 0,
            transferFrom: 'Solvent only',
            transferVolumeUl: 0,
            solventVolumeUl: retainedVolumeUl,
            finalVolumeUl: retainedVolumeUl,
            isZeroConcentrationRow: true,
          ),
        );
      }

      return _SerialDilutionCandidate(
        extraPercent: extraPercent,
        optimizedFinalVolumeUl: preparedVolumeUl,
        retainedVolumeUl: retainedVolumeUl,
        rows: rows,
        warnings: warnings.toSet().toList(),
        summary: _optimizer.evaluateMixVolumes(evaluations),
      );
    }

    final selected = input.autoExtraVolume
        ? (() {
            final autoResult = _optimizer.autoOptimizeExtraVolume(
              evaluateForExtraPercent: (extraPercent) =>
                  buildCandidate(extraPercent).summary,
              currentExtraPercent: input.extraVolumePercent,
            );
            return buildCandidate(
              autoResult.extraPercent,
            ).copyWith(autoReason: autoResult.reason);
          })()
        : buildCandidate(input.extraVolumePercent);

    if (selected.rows.isEmpty) {
      return SerialDilutionResult(
        success: false,
        title: input.title,
        errorMessage: selected.warnings.isEmpty
            ? 'Could not calculate this serial dilution.'
            : selected.warnings.first,
      );
    }

    return SerialDilutionResult(
      success: true,
      title: input.title,
      calculatedNumberOfDilutions: dilutionCount.count,
      optimizedFinalVolumeUl: selected.optimizedFinalVolumeUl,
      formattedOptimizedFinalVolume: _formatVolume(
        selected.optimizedFinalVolumeUl,
      ),
      rows: selected.rows,
      warnings: selected.warnings,
      selectedExtraVolumePercent: selected.extraPercent,
      autoExtraVolumeReason: selected.autoReason,
    );
  }

  _DilutionCountResult _resolveDilutionCount(
    SerialDilutionInput input,
    double stockBase,
    double startingBase,
    ConcentrationFamily stockFamily,
  ) {
    int dilutionCount;
    if (input.seriesLengthMode == SeriesLengthMode.targetLowestConcentration) {
      final targetUnit =
          input.targetLowestConcentrationUnit ??
          (input.startingSourceType == ReagentSourceType.solidMaterial
              ? input.startingDilutionConcentrationUnit ??
                    input.stockConcentrationUnit
              : input.stockConcentrationUnit);
      final targetFamily = _getFamily(targetUnit);
      if (targetFamily != stockFamily) {
        return _DilutionCountResult(
          errorMessage:
              'Cannot convert ${_unitLabel(input.startingSourceType == ReagentSourceType.solidMaterial ? input.startingDilutionConcentrationUnit ?? input.stockConcentrationUnit : input.stockConcentrationUnit)} to ${_unitLabel(targetUnit)}.',
        );
      }

      final targetBase = _convertToBaseConc(
        input.targetLowestConcentration ?? 0,
        targetUnit,
      );
      if (targetBase <= 0) {
        return const _DilutionCountResult(
          errorMessage: 'Target lowest concentration must be greater than 0.',
        );
      }
      if (targetBase >= startingBase) {
        return const _DilutionCountResult(
          errorMessage:
              'Target lowest concentration must be lower than starting dilution concentration.',
        );
      }

      dilutionCount =
          (log(startingBase / targetBase) / log(input.dilutionFactor)).ceil();
      if (dilutionCount > maxDilutions) {
        return const _DilutionCountResult(
          errorMessage:
              'Target concentration requires too many dilution steps. Please increase the dilution factor or target concentration.',
        );
      }
    } else {
      dilutionCount = input.numberOfDilutions ?? 0;
    }

    if (dilutionCount < 1) {
      return const _DilutionCountResult(
        errorMessage: 'Number of dilutions must be at least 1.',
      );
    }
    if (dilutionCount > maxDilutions) {
      return const _DilutionCountResult(
        errorMessage: 'Number of dilutions cannot exceed 50.',
      );
    }

    return _DilutionCountResult(count: dilutionCount);
  }

  String? _validateBasics(SerialDilutionInput input) {
    if (input.startingSourceType == ReagentSourceType.liquidStock &&
        (input.stockConcentration <= 0 || input.stockConcentration.isNaN)) {
      return 'Stock concentration must be greater than 0.';
    }
    if (input.dilutionFactor <= 1 || input.dilutionFactor.isNaN) {
      return 'Dilution factor must be greater than 1.';
    }
    if (input.finalVolume <= 0 || input.finalVolume.isNaN) {
      return 'Final volume must be greater than 0.';
    }
    final sourceUnit =
        input.startingSourceType == ReagentSourceType.solidMaterial
        ? input.startingDilutionConcentrationUnit ??
              input.stockConcentrationUnit
        : input.stockConcentrationUnit;
    if (_getFamily(sourceUnit) == ConcentrationFamily.molecularWeight) {
      return 'Molecular weight cannot be used as a serial dilution concentration unit.';
    }
    if (_getFamily(sourceUnit) == ConcentrationFamily.fold) {
      return 'Fold units cannot be used as serial dilution concentration units.';
    }
    return null;
  }

  ConcentrationFamily _getFamily(ConcentrationUnit unit) {
    return LabCalculation.familyOf(unit);
  }

  double _convertToBaseConc(double val, ConcentrationUnit unit) {
    return LabCalculation.concentrationToBase(val, unit);
  }

  double _convertFromBaseConc(double val, ConcentrationUnit unit) {
    return LabCalculation.concentrationFromBase(val, unit);
  }

  double _convertToUl(double val, VolumeUnit unit) {
    return LabCalculation.volumeToUl(val, unit);
  }

  String _formatConcentration(double baseValue, ConcentrationUnit unit) {
    return LabCalculation.formatConcentration(baseValue, unit);
  }

  String _formatVolume(double ul) {
    return LabCalculation.formatVolume(ul, unicodeMicro: true);
  }

  String _unitLabel(ConcentrationUnit unit) {
    return LabCalculation.unitLabel(unit, unicodeMicro: true);
  }
}

class _SerialDilutionCandidate {
  final double extraPercent;
  final double optimizedFinalVolumeUl;
  final double retainedVolumeUl;
  final List<SerialDilutionRow> rows;
  final List<String> warnings;
  final MixEvaluationSummary summary;
  final String? autoReason;

  const _SerialDilutionCandidate({
    required this.extraPercent,
    required this.optimizedFinalVolumeUl,
    required this.retainedVolumeUl,
    required this.rows,
    required this.warnings,
    required this.summary,
    this.autoReason,
  });

  factory _SerialDilutionCandidate.invalid(double extraPercent) {
    return _SerialDilutionCandidate(
      extraPercent: extraPercent,
      optimizedFinalVolumeUl: 0,
      retainedVolumeUl: 0,
      rows: const [],
      warnings: const ['Could not calculate the solid starting material mass.'],
      summary: const MixEvaluationSummary(
        componentEvaluations: [],
        minComponentScore: 0,
        avgComponentScore: 0,
        warningCount: 1,
      ),
    );
  }

  _SerialDilutionCandidate copyWith({String? autoReason}) {
    return _SerialDilutionCandidate(
      extraPercent: extraPercent,
      optimizedFinalVolumeUl: optimizedFinalVolumeUl,
      retainedVolumeUl: retainedVolumeUl,
      rows: rows,
      warnings: warnings,
      summary: summary,
      autoReason: autoReason ?? this.autoReason,
    );
  }
}

class _DilutionCountResult {
  final int count;
  final String? errorMessage;

  const _DilutionCountResult({this.count = 0, this.errorMessage});
}
