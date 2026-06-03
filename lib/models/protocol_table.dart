enum TableType {
  generic,
  plateLayout,
  reagentMatrix,
  masterMix,
  checklist,
  reagentMix,
  staining,
  serialDilution,
}

class ProtocolTable {
  final String id;
  final String title;
  final TableType type;
  final List<String> columnHeaders;
  final List<String> rowHeaders;
  final List<List<dynamic>> data; // The actual cell values
  final List<List<String>> cellColors; // Hex codes for cell backgrounds
  final Map<String, String> metadata; // e.g., {'plateSize': '96', 'unit': 'µL'}

  ProtocolTable({
    required this.id,
    required this.title,
    this.type = TableType.generic,
    this.columnHeaders = const [],
    this.rowHeaders = const [],
    this.data = const [],
    this.cellColors = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'columnHeaders': columnHeaders,
      'rowHeaders': rowHeaders,
      'data': data,
      'cellColors': cellColors,
      'metadata': metadata,
    };
  }

  factory ProtocolTable.fromJson(Map<String, dynamic> json) {
    return ProtocolTable(
      id: json['id'],
      title: json['title'],
      type: TableType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TableType.generic,
      ),
      columnHeaders: List<String>.from(json['columnHeaders'] ?? []),
      rowHeaders: List<String>.from(json['rowHeaders'] ?? []),
      data: (json['data'] as List? ?? [])
          .map<List<dynamic>>((row) => List<dynamic>.from(row))
          .toList(),
      cellColors: (json['cellColors'] as List? ?? [])
          .map<List<String>>((row) => List<String>.from(row))
          .toList(),
      metadata: Map<String, String>.from(json['metadata'] ?? {}),
    );
  }

  ProtocolTable copyWith({
    String? id,
    String? title,
    TableType? type,
    List<String>? columnHeaders,
    List<String>? rowHeaders,
    List<List<dynamic>>? data,
    List<List<String>>? cellColors,
    Map<String, String>? metadata,
  }) {
    return ProtocolTable(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      columnHeaders: columnHeaders ?? this.columnHeaders,
      rowHeaders: rowHeaders ?? this.rowHeaders,
      data: data ?? this.data,
      cellColors: cellColors ?? this.cellColors,
      metadata: metadata ?? this.metadata,
    );
  }
}
