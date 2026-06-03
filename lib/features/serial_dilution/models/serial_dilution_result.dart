import 'serial_dilution_row.dart';

class SerialDilutionResult {
  final bool success;
  final String? errorMessage;
  final String title;
  final int calculatedNumberOfDilutions;
  final double optimizedFinalVolumeUl;
  final String formattedOptimizedFinalVolume;
  final List<SerialDilutionRow> rows;
  final List<String> warnings;

  SerialDilutionResult({
    required this.success,
    this.errorMessage,
    required this.title,
    this.calculatedNumberOfDilutions = 0,
    this.optimizedFinalVolumeUl = 0,
    this.formattedOptimizedFinalVolume = '',
    this.rows = const [],
    this.warnings = const [],
  });
}
