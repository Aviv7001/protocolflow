export '../../lab_math/lab_calculation.dart'
    show ConcentrationFamily, ConcentrationUnit, VolumeUnit;

import '../../lab_math/lab_calculation.dart';
import '../../measuring_tools/services/measuring_tool_service.dart';
import '../../measuring_tools/services/transfer_optimizer_service.dart';

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
  final bool autoExtraVolume;
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
    this.autoExtraVolume = false,
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
  final List<IntermediateDilutionSuggestion> suggestions;
  final double? reagentMassGrams;
  final TransferEvaluationResult? reagentTransferEvaluation;
  final TransferEvaluationResult? solventTransferEvaluation;
  final double selectedExtraVolumePercent;
  final String? autoExtraVolumeReason;

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
    this.suggestions = const [],
    this.reagentMassGrams,
    this.reagentTransferEvaluation,
    this.solventTransferEvaluation,
    this.selectedExtraVolumePercent = 0,
    this.autoExtraVolumeReason,
  });
}

class ReagentMixCalculatorService {
  final TransferOptimizerService _optimizer = const TransferOptimizerService();
  final MeasuringToolService _measuringToolService =
      MeasuringToolService.instance;

  ReagentMixResult calculateSuspension(ReagentMixInput input) {
    if (input.workingConcentration <= 0) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Target concentration must be greater than 0',
      );
    }
    if (input.numberOfTubes <= 0) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Number of preparations must be greater than 0',
      );
    }

    final totalVolumeUl =
        LabCalculation.volumeToUl(
          input.volumePerTube,
          input.volumePerTubeUnit,
        ) *
        input.numberOfTubes;
    if (totalVolumeUl <= 0) {
      return ReagentMixResult(
        success: false,
        errorMessage: 'Final volume must be greater than 0',
      );
    }

    final totalVolumeL = totalVolumeUl / 1e6;
    final massGrams = _solidMassForConcentration(
      input.workingConcentration,
      input.workingUnit,
      totalVolumeL,
      input.molecularWeight,
    );

    if (massGrams == null) {
      return ReagentMixResult(
        success: false,
        errorMessage:
            'Cannot calculate solid mass from unit ${LabCalculation.unitLabel(input.workingUnit)}',
      );
    }

    return ReagentMixResult(
      success: true,
      reagentMassGrams: massGrams,
      solventVolumeUl: totalVolumeUl,
      totalVolumeUl: totalVolumeUl,
      formattedReagentVolume: LabCalculation.formatMass(
        massGrams,
        unicodeMicro: true,
      ),
      formattedSolventVolume:
          'Bring to ${LabCalculation.formatVolume(totalVolumeUl, unicodeMicro: true)}',
      formattedTotalVolume: LabCalculation.formatVolume(
        totalVolumeUl,
        unicodeMicro: true,
      ),
      solventTransferEvaluation: _optimizer.evaluateTransferVolume(
        totalVolumeUl,
        _measuringToolService.activeTools(),
      ),
      selectedExtraVolumePercent: 0,
    );
  }

  ReagentMixResult calculateMix(ReagentMixInput input) {
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
    if (workingFamily == ConcentrationFamily.ratio) {
      isCompatible = true;
    }

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
    final tools = _measuringToolService.activeTools();

    _ReagentMixCandidate buildCandidate(double extraPercent) {
      final totalVolumeUl = baseTotalVolumeUl * (1 + extraPercent / 100);
      final reagentVolumeUl = (workingInBase * totalVolumeUl) / stockInBase;
      final solventVolumeUl = totalVolumeUl - reagentVolumeUl;
      final suggestionMessage = _optimizer.suggestIntermediateDilution(
        sourceConcentrationBase: stockInBase,
        targetConcentrationBase: workingInBase,
        totalVolumeUl: totalVolumeUl,
        tools: tools,
      );
      final reagentEvaluation = _optimizer.evaluateTransferVolume(
        reagentVolumeUl,
        tools,
        componentName: input.reagentName,
        intermediateSuggestion: suggestionMessage,
      );
      final solventEvaluation = _optimizer.evaluateTransferVolume(
        solventVolumeUl,
        tools,
      );
      final summary = _optimizer.evaluateMixVolumes([
        reagentEvaluation,
        solventEvaluation,
      ]);
      return _ReagentMixCandidate(
        extraPercent: extraPercent,
        totalVolumeUl: totalVolumeUl,
        reagentVolumeUl: reagentVolumeUl,
        solventVolumeUl: solventVolumeUl,
        reagentEvaluation: reagentEvaluation,
        solventEvaluation: solventEvaluation,
        summary: summary,
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

    final warnings = <String>[
      if (selected.reagentEvaluation.warningMessage != null)
        selected.reagentEvaluation.warningMessage!,
      if (selected.solventEvaluation.warningMessage != null)
        selected.solventEvaluation.warningMessage!,
    ];

    final suggestions = <IntermediateDilutionSuggestion>[];
    if (selected.reagentEvaluation.suggestionMessage != null) {
      final intermediate = LabCalculation.intermediateDilutionSuggestion(
        stockConcentrationBase: stockInBase,
        targetConcentrationBase: workingInBase,
        targetDisplayUnit: input.workingUnit,
        totalVolumeUl: selected.totalVolumeUl,
      );
      if (intermediate != null) {
        suggestions.add(intermediate);
      }
    }

    return ReagentMixResult(
      success: true,
      reagentVolumeUl: selected.reagentVolumeUl,
      solventVolumeUl: selected.solventVolumeUl,
      totalVolumeUl: selected.totalVolumeUl,
      formattedReagentVolume: LabCalculation.formatVolume(
        selected.reagentVolumeUl,
        unicodeMicro: true,
      ),
      formattedSolventVolume: LabCalculation.formatVolume(
        selected.solventVolumeUl,
        unicodeMicro: true,
      ),
      formattedTotalVolume: LabCalculation.formatVolume(
        selected.totalVolumeUl,
        unicodeMicro: true,
      ),
      optimized: input.autoExtraVolume,
      warnings: warnings,
      suggestions: suggestions,
      reagentTransferEvaluation: selected.reagentEvaluation,
      solventTransferEvaluation: selected.solventEvaluation,
      selectedExtraVolumePercent: selected.extraPercent,
      autoExtraVolumeReason: selected.autoReason,
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
      solventTransferEvaluation: _optimizer.evaluateTransferVolume(
        totalVolumeUl,
        _measuringToolService.activeTools(),
      ),
      selectedExtraVolumePercent: input.extraVolumePercent,
    );
  }

  double? _massForConcentration(
    double concentration,
    ConcentrationUnit unit,
    double volumeL,
    double molecularWeight,
  ) {
    return _solidMassForConcentration(
      concentration,
      unit,
      volumeL,
      molecularWeight,
    );
  }

  double? _solidMassForConcentration(
    double concentration,
    ConcentrationUnit unit,
    double volumeL, [
    double? molecularWeight,
  ]) {
    final family = LabCalculation.familyOf(unit);
    if (family == ConcentrationFamily.molar) {
      if (molecularWeight == null || molecularWeight <= 0) {
        return null;
      }
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

class _ReagentMixCandidate {
  final double extraPercent;
  final double totalVolumeUl;
  final double reagentVolumeUl;
  final double solventVolumeUl;
  final TransferEvaluationResult reagentEvaluation;
  final TransferEvaluationResult solventEvaluation;
  final MixEvaluationSummary summary;
  final String? autoReason;

  const _ReagentMixCandidate({
    required this.extraPercent,
    required this.totalVolumeUl,
    required this.reagentVolumeUl,
    required this.solventVolumeUl,
    required this.reagentEvaluation,
    required this.solventEvaluation,
    required this.summary,
    this.autoReason,
  });

  _ReagentMixCandidate copyWith({String? autoReason}) {
    return _ReagentMixCandidate(
      extraPercent: extraPercent,
      totalVolumeUl: totalVolumeUl,
      reagentVolumeUl: reagentVolumeUl,
      solventVolumeUl: solventVolumeUl,
      reagentEvaluation: reagentEvaluation,
      solventEvaluation: solventEvaluation,
      summary: summary,
      autoReason: autoReason ?? this.autoReason,
    );
  }
}
