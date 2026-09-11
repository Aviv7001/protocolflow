import 'serial_dilution_row.dart';
import '../../lab_math/lab_calculation.dart';

class SerialDilutionResult {
  final bool success;
  final String? errorMessage;
  final String title;
  final int calculatedNumberOfDilutions;
  final double optimizedFinalVolumeUl;
  final String formattedOptimizedFinalVolume;
  final List<SerialDilutionRow> rows;
  final List<String> warnings;
  final double selectedExtraVolumePercent;
  final String? autoExtraVolumeReason;
  final IntermediateDilutionSuggestion? d0IntermediateSuggestion;
  final bool includesD0IntermediateDilution;

  SerialDilutionResult({
    required this.success,
    this.errorMessage,
    required this.title,
    this.calculatedNumberOfDilutions = 0,
    this.optimizedFinalVolumeUl = 0,
    this.formattedOptimizedFinalVolume = '',
    this.rows = const [],
    this.warnings = const [],
    this.selectedExtraVolumePercent = 0,
    this.autoExtraVolumeReason,
    this.d0IntermediateSuggestion,
    this.includesD0IntermediateDilution = false,
  });
}
