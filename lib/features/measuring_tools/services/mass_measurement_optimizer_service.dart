import '../../lab_math/lab_calculation.dart';
import '../models/measuring_tool.dart';

enum MassMeasurementStatus { ok, cautionNearMinimum, warningNoCompatibleTool }

extension MassMeasurementStatusLabel on MassMeasurementStatus {
  String get label {
    switch (this) {
      case MassMeasurementStatus.ok:
        return 'OK';
      case MassMeasurementStatus.cautionNearMinimum:
        return 'Caution: near balance minimum';
      case MassMeasurementStatus.warningNoCompatibleTool:
        return 'Warning: no compatible balance';
    }
  }
}

class MassMeasurementEvaluationResult {
  final double calculatedMassMg;
  final String? recommendedToolType;
  final String? recommendedToolName;
  final MassMeasurementStatus status;
  final String? warningMessage;
  final String? suggestionMessage;
  final double score;

  const MassMeasurementEvaluationResult({
    required this.calculatedMassMg,
    required this.status,
    required this.score,
    this.recommendedToolType,
    this.recommendedToolName,
    this.warningMessage,
    this.suggestionMessage,
  });

  bool get hasCompatibleTool =>
      status != MassMeasurementStatus.warningNoCompatibleTool;
}

class MassMeasurementOptimizerService {
  const MassMeasurementOptimizerService();

  MassMeasurementEvaluationResult evaluateMass(
    double massMg,
    List<MeasuringTool> tools, {
    String? componentName,
  }) {
    final massLabel = LabCalculation.formatMass(massMg / 1000);
    if (massMg <= 0 || !massMg.isFinite) {
      return MassMeasurementEvaluationResult(
        calculatedMassMg: massMg,
        status: MassMeasurementStatus.warningNoCompatibleTool,
        score: 0,
        warningMessage: 'Mass must be greater than 0.',
      );
    }

    final candidates = tools.where((tool) {
      if (!tool.active || !tool.isMassTool) return false;
      final min = tool.minMassMg ?? 0;
      final max = tool.maxMassMg ?? double.infinity;
      return massMg >= min && massMg <= max;
    }).toList();

    if (candidates.isEmpty) {
      return MassMeasurementEvaluationResult(
        calculatedMassMg: massMg,
        status: MassMeasurementStatus.warningNoCompatibleTool,
        score: 0,
        warningMessage:
            'No active balance can accurately weigh $massLabel based on the defined mass ranges.',
        suggestionMessage:
            'Scale up the preparation or prepare a concentrated stock from a weighable amount.',
      );
    }

    candidates.sort((left, right) {
      final rank = right.accuracyRank.compareTo(left.accuracyRank);
      if (rank != 0) return rank;
      final leftReadability = left.incrementMassMg ?? double.infinity;
      final rightReadability = right.incrementMassMg ?? double.infinity;
      return leftReadability.compareTo(rightReadability);
    });

    final best = candidates.first;
    final preferredMin = best.preferredMinMassMg ?? best.minMassMg ?? 0;
    final nearMinimum = preferredMin > 0 && massMg < preferredMin;
    return MassMeasurementEvaluationResult(
      calculatedMassMg: massMg,
      recommendedToolType: best.toolType,
      recommendedToolName: best.toolName,
      status: nearMinimum
          ? MassMeasurementStatus.cautionNearMinimum
          : MassMeasurementStatus.ok,
      warningMessage: nearMinimum
          ? '$massLabel is within the range of ${best.toolName}, but below the preferred minimum. Accuracy may be reduced.'
          : null,
      suggestionMessage: nearMinimum
          ? 'Consider scaling up the preparation or making a concentrated stock from a larger weighed amount.'
          : null,
      score: best.accuracyRank * 20.0,
    );
  }
}
