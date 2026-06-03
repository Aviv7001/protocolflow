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
  });
}
