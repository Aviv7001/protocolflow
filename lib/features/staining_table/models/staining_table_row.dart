class StainingTableRow {
  final String rowName;
  final String totalStainsText;
  final Map<String, bool> stainMap;
  final bool isMetadataRow; // To distinguish Ex/Em/Laser rows
  final Map<String, String> metadataValues; // Added directly to class

  StainingTableRow({
    required this.rowName,
    required this.totalStainsText,
    required this.stainMap,
    this.isMetadataRow = false,
    this.metadataValues = const {},
  });
}

class StainingTableResult {
  final List<String> stainColumns;
  final List<StainingTableRow> rows;
  final List<StainingTableRow> metadataRows;

  StainingTableResult({
    required this.stainColumns,
    required this.rows,
    this.metadataRows = const [],
  });
}
