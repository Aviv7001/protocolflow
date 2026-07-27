import '../../lab_math/lab_calculation.dart';
import '../../measuring_tools/services/mass_measurement_optimizer_service.dart';
import '../../measuring_tools/services/transfer_optimizer_service.dart';

class SerialDilutionRow {
  final String dilutionName;
  final double concentrationBaseUnit;
  final String formattedConcentration;
  final String transferFrom;
  final double transferVolumeUl;
  final String formattedTransferVolume;
  final double solventVolumeUl;
  final String formattedSolventVolume;
  final double finalVolumeUl;
  final String formattedFinalVolume;
  final bool isZeroConcentrationRow;
  final List<String> warnings;
  final List<IntermediateDilutionSuggestion> suggestions;
  final TransferEvaluationResult? transferEvaluation;
  final MassMeasurementEvaluationResult? massEvaluation;
  final TransferEvaluationResult? solventTransferEvaluation;

  SerialDilutionRow({
    required this.dilutionName,
    required this.concentrationBaseUnit,
    required this.formattedConcentration,
    required this.transferFrom,
    required this.transferVolumeUl,
    required this.formattedTransferVolume,
    required this.solventVolumeUl,
    required this.formattedSolventVolume,
    required this.finalVolumeUl,
    required this.formattedFinalVolume,
    this.isZeroConcentrationRow = false,
    this.warnings = const [],
    this.suggestions = const [],
    this.transferEvaluation,
    this.massEvaluation,
    this.solventTransferEvaluation,
  });
}
