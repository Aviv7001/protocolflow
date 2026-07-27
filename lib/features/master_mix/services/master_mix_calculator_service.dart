export '../../lab_math/lab_calculation.dart'
    show ConcentrationFamily, ConcentrationUnit, VolumeUnit;

import '../../lab_math/lab_calculation.dart';
import '../../measuring_tools/services/mass_measurement_optimizer_service.dart';
import '../../measuring_tools/services/measuring_tool_service.dart';
import '../../measuring_tools/services/transfer_optimizer_service.dart';

class MasterMixReagentInput {
  final ReagentSourceType sourceType;
  final String reagentName;
  final double stockConcentration;
  final ConcentrationUnit stockConcentrationUnit;
  final double finalConcentration;
  final ConcentrationUnit finalConcentrationUnit;
  final double? molecularWeight;

  MasterMixReagentInput({
    this.sourceType = ReagentSourceType.liquidStock,
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
  final bool autoExtraVolume;
  final String baseSolventName;
  final List<MasterMixReagentInput> reagents;

  MasterMixInput({
    required this.mixName,
    required this.finalVolume,
    required this.finalVolumeUnit,
    this.extraVolumePercent = 10,
    this.autoExtraVolume = false,
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
  final List<IntermediateDilutionSuggestion> suggestions;
  final double? reagentMassGrams;
  final MassMeasurementEvaluationResult? massEvaluation;
  final TransferEvaluationResult? transferEvaluation;

  MasterMixReagentResult({
    required this.reagentName,
    required this.reagentVolumeUl,
    required this.formattedReagentVolume,
    required this.formattedStockConcentration,
    required this.formattedFinalConcentration,
    this.warnings = const [],
    this.suggestions = const [],
    this.reagentMassGrams,
    this.massEvaluation,
    this.transferEvaluation,
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
  final TransferEvaluationResult? solventTransferEvaluation;
  final double selectedExtraVolumePercent;
  final String? autoExtraVolumeReason;

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
    this.solventTransferEvaluation,
    this.selectedExtraVolumePercent = 0,
    this.autoExtraVolumeReason,
  });
}

class MasterMixCalculatorService {
  final TransferOptimizerService _optimizer = const TransferOptimizerService();
  final MassMeasurementOptimizerService _massOptimizer =
      const MassMeasurementOptimizerService();
  final MeasuringToolService _measuringToolService =
      MeasuringToolService.instance;

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
    final params = <_ReagentCalcParams>[];
    final tools = _measuringToolService.activeTools();

    for (final reagent in input.reagents) {
      if (reagent.sourceType == ReagentSourceType.liquidStock &&
          (reagent.stockConcentration <= 0 ||
              reagent.stockConcentration.isNaN)) {
        return MasterMixResult(
          success: false,
          errorMessage:
              'Stock concentration for ${reagent.reagentName} must be a valid number greater than 0',
          mixName: input.mixName,
        );
      }
      if (reagent.finalConcentration <= 0 || reagent.finalConcentration.isNaN) {
        return MasterMixResult(
          success: false,
          errorMessage:
              'Final concentration for ${reagent.reagentName} must be a valid number greater than 0',
          mixName: input.mixName,
        );
      }
      if (reagent.sourceType == ReagentSourceType.solidMaterial) {
        final family = LabCalculation.familyOf(reagent.finalConcentrationUnit);
        if (family != ConcentrationFamily.massVolume &&
            family != ConcentrationFamily.percentage &&
            family != ConcentrationFamily.molar) {
          return MasterMixResult(
            success: false,
            errorMessage:
                'Solid material ${reagent.reagentName} must use mass/volume, percent w/v, or molar final concentration.',
            mixName: input.mixName,
          );
        }
        if (family == ConcentrationFamily.molar &&
            (reagent.molecularWeight == null ||
                reagent.molecularWeight! <= 0)) {
          return MasterMixResult(
            success: false,
            errorMessage:
                'Molecular weight is required for solid material ${reagent.reagentName} with molar final concentration.',
            mixName: input.mixName,
          );
        }
      }

      try {
        final ratio = reagent.sourceType == ReagentSourceType.solidMaterial
            ? 0.0
            : _calculateConcentrationRatio(reagent);
        if (!ratio.isFinite || ratio.isNaN) {
          return MasterMixResult(
            success: false,
            errorMessage:
                'Invalid concentration ratio for ${reagent.reagentName}',
            mixName: input.mixName,
          );
        }
        if (reagent.sourceType == ReagentSourceType.liquidStock &&
            ratio >= 1.0) {
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

    _MasterMixCandidate buildCandidate(double extraPercent) {
      final totalUl = requestedUl * (1 + extraPercent / 100);
      final reagentResults = <MasterMixReagentResult>[];
      final evaluations = <TransferEvaluationResult>[];
      final allWarnings = <String>[];
      var totalReagentUl = 0.0;

      for (final param in params) {
        final volumeUl = param.ratio * totalUl;
        totalReagentUl += volumeUl;
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
        TransferEvaluationResult? transferEvaluation;
        MassMeasurementEvaluationResult? massEvaluation;
        final reagentWarnings = <String>[];
        final reagentSuggestions = <IntermediateDilutionSuggestion>[];

        if (param.input.sourceType == ReagentSourceType.solidMaterial) {
          massGrams = LabCalculation.solidMassForConcentration(
            concentration: param.input.finalConcentration,
            unit: param.input.finalConcentrationUnit,
            volumeUl: totalUl,
            molecularWeight: param.input.molecularWeight,
          );
          if (massGrams == null) {
            return _MasterMixCandidate.invalid(extraPercent);
          }
          formattedAmount = LabCalculation.formatMass(
            massGrams,
            unicodeMicro: true,
          );
          massEvaluation = _massOptimizer.evaluateMass(
            massGrams * 1000,
            tools,
            componentName: param.input.reagentName,
          );
          if (massEvaluation.warningMessage != null) {
            reagentWarnings.add(massEvaluation.warningMessage!);
          }
        } else if (isStockMw || isFinalMw) {
          final mw = isStockMw
              ? param.input.stockConcentration
              : param.input.finalConcentration;
          final targetConc = isStockMw
              ? param.input.finalConcentration
              : param.input.stockConcentration;
          final targetUnit = isStockMw
              ? param.input.finalConcentrationUnit
              : param.input.stockConcentrationUnit;
          massGrams = _calculateMassGrams(targetConc, targetUnit, totalUl, mw);
          if (massGrams != null) {
            formattedAmount = LabCalculation.formatMass(
              massGrams,
              unicodeMicro: true,
            );
          }
        } else {
          final stockBase = _stockBase(param.input);
          final finalBase = _finalBase(param.input);
          final suggestionMessage = _optimizer.suggestIntermediateDilution(
            sourceConcentrationBase: stockBase,
            targetConcentrationBase: finalBase,
            totalVolumeUl: totalUl,
            tools: tools,
          );
          transferEvaluation = _optimizer.evaluateTransferVolume(
            volumeUl,
            tools,
            componentName: param.input.reagentName,
            intermediateSuggestion: suggestionMessage,
          );
          evaluations.add(transferEvaluation);
          if (transferEvaluation.warningMessage != null) {
            reagentWarnings.add(transferEvaluation.warningMessage!);
          }
          if (transferEvaluation.suggestionMessage != null) {
            final intermediate = LabCalculation.intermediateDilutionSuggestion(
              stockConcentrationBase: stockBase,
              targetConcentrationBase: finalBase,
              targetDisplayUnit: param.input.finalConcentrationUnit,
              totalVolumeUl: totalUl,
            );
            if (intermediate != null) {
              reagentSuggestions.add(intermediate);
            }
          }
        }

        allWarnings.addAll(
          reagentWarnings.map(
            (warning) => '${param.input.reagentName}: $warning',
          ),
        );
        reagentResults.add(
          MasterMixReagentResult(
            reagentName: param.input.reagentName,
            reagentVolumeUl: massGrams != null ? 0 : volumeUl,
            reagentMassGrams: massGrams,
            formattedReagentVolume: formattedAmount,
            formattedStockConcentration:
                param.input.sourceType == ReagentSourceType.solidMaterial
                ? 'Solid material'
                : LabCalculation.formatInputConcentration(
                    param.input.stockConcentration,
                    param.input.stockConcentrationUnit,
                  ),
            formattedFinalConcentration:
                LabCalculation.formatInputConcentration(
                  param.input.finalConcentration,
                  param.input.finalConcentrationUnit,
                ),
            warnings: reagentWarnings,
            suggestions: reagentSuggestions,
            massEvaluation: massEvaluation,
            transferEvaluation: transferEvaluation,
          ),
        );
      }

      final solventUl = totalUl - totalReagentUl;
      if (solventUl < 0) {
        return _MasterMixCandidate.invalid(extraPercent);
      }
      final containsSolid = params.any(
        (param) => param.input.sourceType == ReagentSourceType.solidMaterial,
      );
      final solventEvaluation = containsSolid
          ? null
          : _optimizer.evaluateTransferVolume(solventUl, tools);
      if (solventEvaluation != null) evaluations.add(solventEvaluation);
      final solventWarning = solventEvaluation?.warningMessage;
      if (solventWarning != null) {
        allWarnings.add('${input.baseSolventName}: $solventWarning');
      }

      return _MasterMixCandidate(
        valid: true,
        extraPercent: extraPercent,
        totalUl: totalUl,
        solventUl: solventUl,
        reagentResults: reagentResults,
        solventEvaluation: solventEvaluation,
        summary: _optimizer.evaluateMixVolumes(evaluations),
        warnings: allWarnings,
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

    if (!selected.valid) {
      return MasterMixResult(
        success: false,
        errorMessage:
            'Could not calculate this master mix with the current reagent setup.',
        mixName: input.mixName,
      );
    }

    globalWarnings.addAll(selected.warnings);

    return MasterMixResult(
      success: true,
      mixName: input.mixName,
      requestedFinalVolumeUl: requestedUl,
      optimizedFinalVolumeUl: selected.totalUl,
      formattedRequestedFinalVolume: LabCalculation.formatVolume(
        requestedUl,
        unicodeMicro: true,
      ),
      formattedOptimizedFinalVolume: LabCalculation.formatVolume(
        selected.totalUl,
        unicodeMicro: true,
      ),
      reagentResults: selected.reagentResults,
      baseSolventVolumeUl: selected.solventUl,
      formattedBaseSolventVolume:
          input.reagents.any(
            (reagent) => reagent.sourceType == ReagentSourceType.solidMaterial,
          )
          ? 'Bring to ${LabCalculation.formatVolume(selected.totalUl, unicodeMicro: true)} '
                '(~${LabCalculation.formatVolume(selected.solventUl, unicodeMicro: true)})'
          : LabCalculation.formatVolume(selected.solventUl, unicodeMicro: true),
      warnings: globalWarnings,
      solventTransferEvaluation: selected.solventEvaluation,
      selectedExtraVolumePercent: selected.extraPercent,
      autoExtraVolumeReason: selected.autoReason,
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

  double _stockBase(MasterMixReagentInput reagent) {
    final stockFamily = LabCalculation.familyOf(reagent.stockConcentrationUnit);
    final finalFamily = LabCalculation.familyOf(reagent.finalConcentrationUnit);
    final mw = reagent.molecularWeight;
    final isMolarMassPair =
        (stockFamily == ConcentrationFamily.molar &&
            finalFamily == ConcentrationFamily.massVolume) ||
        (stockFamily == ConcentrationFamily.massVolume &&
            finalFamily == ConcentrationFamily.molar);

    if (isMolarMassPair) {
      if (mw == null || mw <= 0) {
        return 0;
      }
      return stockFamily == ConcentrationFamily.molar
          ? LabCalculation.concentrationToBase(
              reagent.stockConcentration,
              reagent.stockConcentrationUnit,
            )
          : LabCalculation.concentrationToBase(
                  reagent.stockConcentration,
                  reagent.stockConcentrationUnit,
                ) /
                mw;
    }

    return LabCalculation.concentrationToBase(
      reagent.stockConcentration,
      reagent.stockConcentrationUnit,
      molecularWeight: mw,
    );
  }

  double _finalBase(MasterMixReagentInput reagent) {
    final stockFamily = LabCalculation.familyOf(reagent.stockConcentrationUnit);
    final finalFamily = LabCalculation.familyOf(reagent.finalConcentrationUnit);
    final mw = reagent.molecularWeight;
    final isMolarMassPair =
        (stockFamily == ConcentrationFamily.molar &&
            finalFamily == ConcentrationFamily.massVolume) ||
        (stockFamily == ConcentrationFamily.massVolume &&
            finalFamily == ConcentrationFamily.molar);

    if (isMolarMassPair) {
      if (mw == null || mw <= 0) {
        return 0;
      }
      return finalFamily == ConcentrationFamily.molar
          ? LabCalculation.concentrationToBase(
              reagent.finalConcentration,
              reagent.finalConcentrationUnit,
            )
          : LabCalculation.concentrationToBase(
                  reagent.finalConcentration,
                  reagent.finalConcentrationUnit,
                ) /
                mw;
    }

    return LabCalculation.concentrationToBase(
      reagent.finalConcentration,
      reagent.finalConcentrationUnit,
      molecularWeight: mw,
    );
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
}

class _ReagentCalcParams {
  final MasterMixReagentInput input;
  final double ratio;

  _ReagentCalcParams({required this.input, required this.ratio});
}

class _MasterMixCandidate {
  final bool valid;
  final double extraPercent;
  final double totalUl;
  final double solventUl;
  final List<MasterMixReagentResult> reagentResults;
  final TransferEvaluationResult? solventEvaluation;
  final MixEvaluationSummary summary;
  final List<String> warnings;
  final String? autoReason;

  const _MasterMixCandidate({
    required this.valid,
    required this.extraPercent,
    required this.totalUl,
    required this.solventUl,
    required this.reagentResults,
    required this.solventEvaluation,
    required this.summary,
    required this.warnings,
    this.autoReason,
  });

  factory _MasterMixCandidate.invalid(double extraPercent) {
    return const _MasterMixCandidate(
      valid: false,
      extraPercent: 0,
      totalUl: 0,
      solventUl: 0,
      reagentResults: [],
      solventEvaluation: null,
      summary: MixEvaluationSummary(
        componentEvaluations: [],
        minComponentScore: 0,
        avgComponentScore: 0,
        warningCount: 0,
      ),
      warnings: [],
    );
  }

  _MasterMixCandidate copyWith({String? autoReason}) {
    return _MasterMixCandidate(
      valid: valid,
      extraPercent: extraPercent,
      totalUl: totalUl,
      solventUl: solventUl,
      reagentResults: reagentResults,
      solventEvaluation: solventEvaluation,
      summary: summary,
      warnings: warnings,
      autoReason: autoReason ?? this.autoReason,
    );
  }
}
