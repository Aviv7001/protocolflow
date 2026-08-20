enum TableType {
  generic,
  materialList,
  plateLayout,
  masterMix,
  checklist,
  staining,
  serialDilution,
}

ProtocolTable createMaterialListTable({
  required String id,
  List<List<dynamic>> data = const [],
}) {
  const headers = ['Name', 'Qty', 'Stock conc', 'Catalog #', 'Mfr'];
  final rows = data.isEmpty
      ? <List<dynamic>>[
          ['', '', '', '', ''],
        ]
      : data.map((row) => List<dynamic>.from(row)).toList();
  return ProtocolTable(
    id: id,
    title: 'Material List',
    type: TableType.materialList,
    columnHeaders: headers,
    rowHeaders: List.generate(rows.length, (index) => '${index + 1}'),
    data: rows,
    cellColors: List.generate(
      rows.length,
      (_) => List.generate(headers.length, (_) => ''),
    ),
  );
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

  final String? projectId;
  final DateTime? createdAt;

  ProtocolTable({
    required this.id,
    required this.title,
    this.type = TableType.generic,
    this.columnHeaders = const [],
    this.rowHeaders = const [],
    this.data = const [],
    this.cellColors = const [],
    this.metadata = const {},
    this.projectId,
    this.createdAt,
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
      'projectId': projectId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  ProtocolTable deepCopy() {
    return copyWith();
  }

  factory ProtocolTable.fromJson(Map<String, dynamic> json) {
    return ProtocolTable(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
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
      projectId: json['projectId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
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
    String? projectId,
    bool clearProjectId = false,
    DateTime? createdAt,
  }) {
    return ProtocolTable(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      columnHeaders: List<String>.from(columnHeaders ?? this.columnHeaders),
      rowHeaders: List<String>.from(rowHeaders ?? this.rowHeaders),
      data: (data ?? this.data)
          .map<List<dynamic>>((row) => List<dynamic>.from(row))
          .toList(),
      cellColors: (cellColors ?? this.cellColors)
          .map<List<String>>((row) => List<String>.from(row))
          .toList(),
      metadata: Map<String, String>.from(metadata ?? this.metadata),
      projectId: clearProjectId ? null : projectId ?? this.projectId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
