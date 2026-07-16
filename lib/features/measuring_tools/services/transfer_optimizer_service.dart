import '../../lab_math/lab_calculation.dart';
import '../models/measuring_tool.dart';

enum TransferStatus {
  ok,
  cautionLowRange,
  cautionRepeatedTransfer,
  warningNoCompatibleTool,
  suggestIntermediateDilution,
  suggestAutoExtraVolume,
}

extension TransferStatusLabel on TransferStatus {
  String get label {
    switch (this) {
      case TransferStatus.ok:
        return 'OK';
      case TransferStatus.cautionLowRange:
        return 'Caution: low range';
      case TransferStatus.cautionRepeatedTransfer:
        return 'Caution: repeated transfer';
      case TransferStatus.warningNoCompatibleTool:
        return 'Warning: no compatible tool';
      case TransferStatus.suggestIntermediateDilution:
        return 'Suggest intermediate dilution';
      case TransferStatus.suggestAutoExtraVolume:
        return 'Suggest auto extra volume';
    }
  }
}

class TransferOption {
  final MeasuringTool tool;
  final double requiredVolumeUl;
  final double transferVolumePerRepeatUl;
  final int repeats;
  final double comfortScore;
  final bool lowRangeCaution;
  final double score;

  const TransferOption({
    required this.tool,
    required this.requiredVolumeUl,
    required this.transferVolumePerRepeatUl,
    required this.repeats,
    required this.comfortScore,
    required this.lowRangeCaution,
    required this.score,
  });
}

class TransferEvaluationResult {
  final double calculatedVolumeUl;
  final String? recommendedToolType;
  final String? recommendedToolName;
  final double? transferVolumePerRepeatUl;
  final int repeats;
  final TransferStatus status;
  final String? warningMessage;
  final String? suggestionMessage;
  final double score;
  final List<TransferOption> options;

  const TransferEvaluationResult({
    required this.calculatedVolumeUl,
    required this.status,
    required this.score,
    this.recommendedToolType,
    this.recommendedToolName,
    this.transferVolumePerRepeatUl,
    this.repeats = 1,
    this.warningMessage,
    this.suggestionMessage,
    this.options = const [],
  });

  bool get hasCompatibleTool => options.isNotEmpty;
}

class MixEvaluationSummary {
  final List<TransferEvaluationResult> componentEvaluations;
  final double minComponentScore;
  final double avgComponentScore;
  final int warningCount;

  const MixEvaluationSummary({
    required this.componentEvaluations,
    required this.minComponentScore,
    required this.avgComponentScore,
    required this.warningCount,
  });
}

class AutoExtraVolumeResult {
  final bool selectedAutoMode;
  final double extraPercent;
  final String reason;
  final MixEvaluationSummary evaluation;

  const AutoExtraVolumeResult({
    required this.selectedAutoMode,
    required this.extraPercent,
    required this.reason,
    required this.evaluation,
  });
}

class TransferOptimizerService {
  static const double tolerance = 0.000001;
  static const int maxRepeats = 3;
  static const List<int> preferredIntermediateFactors = [10, 20, 50, 100];

  const TransferOptimizerService();

  bool matchesIncrement(double volumeUl, double incrementUl) {
    if (incrementUl <= 0) return false;
    final remainder = volumeUl % incrementUl;
    return remainder.abs() < tolerance ||
        (remainder - incrementUl).abs() < tolerance;
  }

  List<TransferOption> findTransferOptions(
    double volumeUl,
    List<MeasuringTool> tools, {
    int maxRepeatCount = maxRepeats,
  }) {
    final options = <TransferOption>[];
    if (volumeUl <= 0) {
      return options;
    }

    for (final tool in tools.where((item) => item.active)) {
      for (var repeats = 1; repeats <= maxRepeatCount; repeats++) {
        final perRepeat = volumeUl / repeats;
        if (perRepeat + tolerance < tool.minVolumeUl) {
          continue;
        }
        if (perRepeat - tolerance > tool.maxVolumeUl) {
          continue;
        }
        if (!matchesIncrement(perRepeat, tool.incrementUl)) {
          continue;
        }

        final denominator = tool.maxVolumeUl - tool.minVolumeUl;
        final comfortScore = denominator <= 0
            ? 1.0
            : ((perRepeat - tool.minVolumeUl) / denominator).clamp(0.0, 1.0);
        final lowRangeCaution =
            perRepeat <= tool.minVolumeUl + tool.incrementUl + tolerance;
        final option = TransferOption(
          tool: tool,
          requiredVolumeUl: volumeUl,
          transferVolumePerRepeatUl: perRepeat,
          repeats: repeats,
          comfortScore: comfortScore,
          lowRangeCaution: lowRangeCaution,
          score: scoreTransferOption(
            tool: tool,
            comfortScore: comfortScore,
            repeats: repeats,
            lowRangeCaution: lowRangeCaution,
          ),
        );
        options.add(option);
      }
    }

    options.sort(_compareOptions);
    return options;
  }

  double scoreTransferOption({
    required MeasuringTool tool,
    required double comfortScore,
    required int repeats,
    required bool lowRangeCaution,
  }) {
    final baseScore = switch (tool.accuracyRank) {
      3 => 80.0,
      2 => 60.0,
      1 => 40.0,
      _ => 20.0 * tool.accuracyRank.clamp(0, 5),
    };
    final repeatPenalty = repeats == 2
        ? 5.0
        : repeats == 3
        ? 10.0
        : 0.0;
    final lowRangePenalty = lowRangeCaution ? 15.0 : 0.0;
    return baseScore +
        (comfortScore.clamp(0.0, 1.0) * 20.0) -
        repeatPenalty -
        lowRangePenalty;
  }

  TransferEvaluationResult evaluateTransferVolume(
    double volumeUl,
    List<MeasuringTool> tools, {
    String? componentName,
    String? intermediateSuggestion,
  }) {
    final options = findTransferOptions(volumeUl, tools);
    if (options.isEmpty) {
      return TransferEvaluationResult(
        calculatedVolumeUl: volumeUl,
        status: TransferStatus.warningNoCompatibleTool,
        score: 0,
        warningMessage:
            'No active measuring tool can accurately measure ${LabCalculation.formatVolume(volumeUl, unicodeMicro: true)} based on the defined ranges and increments.',
        suggestionMessage:
            intermediateSuggestion ??
            'Consider preparing an intermediate dilution.',
        options: const [],
      );
    }

    final best = options.first;
    final isRepeated = best.repeats > 1;
    final isLowRange = best.lowRangeCaution;

    final warningMessage = isLowRange
        ? '${LabCalculation.formatVolume(best.transferVolumePerRepeatUl, unicodeMicro: true)} is within the range of ${best.tool.toolName}, but it is near the lower edge of the tool range. Accuracy may be reduced.'
        : isRepeated
        ? 'Required volume is ${LabCalculation.formatVolume(volumeUl, unicodeMicro: true)}. Suggested transfer: ${LabCalculation.formatVolume(best.transferVolumePerRepeatUl, unicodeMicro: true)} x ${best.repeats} using ${best.tool.toolName}.'
        : null;

    final suggestionMessage = isLowRange
        ? (intermediateSuggestion ??
              'Consider preparing an intermediate dilution or increasing total mix volume.')
        : null;

    return TransferEvaluationResult(
      calculatedVolumeUl: volumeUl,
      recommendedToolType: best.tool.toolType,
      recommendedToolName: best.tool.toolName,
      transferVolumePerRepeatUl: best.transferVolumePerRepeatUl,
      repeats: best.repeats,
      status: isLowRange
          ? TransferStatus.cautionLowRange
          : isRepeated
          ? TransferStatus.cautionRepeatedTransfer
          : TransferStatus.ok,
      warningMessage: warningMessage,
      suggestionMessage: suggestionMessage,
      score: best.score,
      options: options,
    );
  }

  MixEvaluationSummary evaluateMixVolumes(
    List<TransferEvaluationResult> evaluations,
  ) {
    if (evaluations.isEmpty) {
      return const MixEvaluationSummary(
        componentEvaluations: [],
        minComponentScore: 0,
        avgComponentScore: 0,
        warningCount: 0,
      );
    }

    final scores = evaluations.map((item) => item.score).toList();
    final minScore = scores.reduce(
      (left, right) => left < right ? left : right,
    );
    final avgScore =
        scores.reduce((left, right) => left + right) / scores.length;
    final warningCount = evaluations.where((item) {
      return item.status != TransferStatus.ok;
    }).length;

    return MixEvaluationSummary(
      componentEvaluations: evaluations,
      minComponentScore: minScore,
      avgComponentScore: avgScore,
      warningCount: warningCount,
    );
  }

  AutoExtraVolumeResult autoOptimizeExtraVolume({
    required MixEvaluationSummary Function(double extraPercent)
    evaluateForExtraPercent,
    double? currentExtraPercent,
  }) {
    final baselineExtraPercent = currentExtraPercent ?? 10.0;
    final baselineEvaluation = evaluateForExtraPercent(baselineExtraPercent);
    var bestEvaluation = baselineEvaluation;
    var bestExtraPercent = baselineExtraPercent;

    for (var extraPercent = 10; extraPercent <= 30; extraPercent++) {
      final evaluation = evaluateForExtraPercent(extraPercent.toDouble());
      if (_isBetterAutoExtraCandidate(
        candidate: evaluation,
        candidateExtraPercent: extraPercent.toDouble(),
        current: bestEvaluation,
        currentExtraPercent: bestExtraPercent,
      )) {
        bestEvaluation = evaluation;
        bestExtraPercent = extraPercent.toDouble();
      }
    }

    final improved =
        bestEvaluation.warningCount < baselineEvaluation.warningCount;
    final selectedEvaluation = improved ? bestEvaluation : baselineEvaluation;
    final selectedPercent = improved ? bestExtraPercent : baselineExtraPercent;
    final reason = improved
        ? _buildAutoReason(
            baseline: baselineEvaluation,
            selected: selectedEvaluation,
            extraPercent: selectedPercent,
          )
        : baselineEvaluation.warningCount == 0
        ? 'Auto extra volume kept at ${LabCalculation.formatNumber(selectedPercent)}%. Existing volumes already fit the active measuring tools.'
        : 'Auto extra volume did not reduce warnings. Using ${LabCalculation.formatNumber(selectedPercent)}%.';

    return AutoExtraVolumeResult(
      selectedAutoMode: improved,
      extraPercent: selectedPercent,
      reason: reason,
      evaluation: selectedEvaluation,
    );
  }

  String? suggestIntermediateDilution({
    required double sourceConcentrationBase,
    required double targetConcentrationBase,
    required double totalVolumeUl,
    required List<MeasuringTool> tools,
  }) {
    if (sourceConcentrationBase <= 0 ||
        targetConcentrationBase <= 0 ||
        totalVolumeUl <= 0) {
      return null;
    }

    for (final factor in preferredIntermediateFactors) {
      final intermediateBase = sourceConcentrationBase / factor;
      if (intermediateBase <= targetConcentrationBase) {
        continue;
      }
      final finalTransferUl =
          totalVolumeUl * (targetConcentrationBase / intermediateBase);
      final evaluation = evaluateTransferVolume(finalTransferUl, tools);
      if (!evaluation.hasCompatibleTool) {
        continue;
      }
      final preferredVolume = evaluation.transferVolumePerRepeatUl ?? 0;
      if (preferredVolume < 20 || preferredVolume > 200) {
        continue;
      }
      final secondFactor = intermediateBase / targetConcentrationBase;
      return 'Consider preparing a ${_ratioLabel(factor.toDouble())} intermediate stock, then dilute ${_ratioLabel(secondFactor)} again to reach the target dilution.';
    }

    return 'Consider preparing an intermediate dilution of this reagent.';
  }

  bool _isBetterAutoExtraCandidate({
    required MixEvaluationSummary candidate,
    required double candidateExtraPercent,
    required MixEvaluationSummary current,
    required double currentExtraPercent,
  }) {
    if (candidate.warningCount != current.warningCount) {
      return candidate.warningCount < current.warningCount;
    }
    return candidateExtraPercent < currentExtraPercent;
  }

  int _compareOptions(TransferOption left, TransferOption right) {
    final rankCompare = right.tool.accuracyRank.compareTo(
      left.tool.accuracyRank,
    );
    if (rankCompare != 0) return rankCompare;

    final repeatCompare = left.repeats.compareTo(right.repeats);
    if (repeatCompare != 0) return repeatCompare;

    final comfortCompare = right.comfortScore.compareTo(left.comfortScore);
    if (comfortCompare != 0) return comfortCompare;

    return left.tool.maxVolumeUl.compareTo(right.tool.maxVolumeUl);
  }

  String _ratioLabel(double factor) {
    return '1:${LabCalculation.formatNumber(factor)}';
  }

  String _buildAutoReason({
    required MixEvaluationSummary baseline,
    required MixEvaluationSummary selected,
    required double extraPercent,
  }) {
    final baselineMin = baseline.componentEvaluations
        .map((item) => item.calculatedVolumeUl)
        .fold<double?>(null, (current, item) {
          if (current == null) return item;
          return item < current ? item : current;
        });
    final selectedMin = selected.componentEvaluations
        .map((item) => item.calculatedVolumeUl)
        .fold<double?>(null, (current, item) {
          if (current == null) return item;
          return item < current ? item : current;
        });

    if (baseline.warningCount > selected.warningCount) {
      return 'Auto-selected extra volume: ${LabCalculation.formatNumber(extraPercent)}%. Reduced warnings from ${baseline.warningCount} to ${selected.warningCount}.';
    }
    if (baselineMin != null &&
        selectedMin != null &&
        selectedMin > baselineMin + tolerance) {
      return 'Auto-selected extra volume: ${LabCalculation.formatNumber(extraPercent)}%. Improved lowest transfer volume from ${LabCalculation.formatVolume(baselineMin, unicodeMicro: true)} to ${LabCalculation.formatVolume(selectedMin, unicodeMicro: true)}.';
    }
    return 'Auto-selected extra volume: ${LabCalculation.formatNumber(extraPercent)}%. Selected the lowest extra volume that achieved the best pipetting score.';
  }
}
