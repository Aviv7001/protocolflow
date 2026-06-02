import 'dart:convert';
import '../../../models/protocol_table.dart';
import 'stain_definition.dart';
import 'staining_sample.dart';
import '../services/staining_table_generator_service.dart';

class StainingWizard {
  final String title;
  final List<StainChain> panel;
  final List<StainingSample> samples;
  
  final bool includeUnstained;
  final bool includeSecondaryOnly;
  final bool includeFullStain;

  StainingWizard({
    this.title = 'Staining Table',
    this.panel = const [],
    this.samples = const [],
    this.includeUnstained = true,
    this.includeSecondaryOnly = true,
    this.includeFullStain = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'panel': panel.map((c) => c.toJson()).toList(),
      'samples': samples.map((s) => s.toJson()).toList(),
      'includeUnstained': includeUnstained,
      'includeSecondaryOnly': includeSecondaryOnly,
      'includeFullStain': includeFullStain,
    };
  }

  factory StainingWizard.fromJson(Map<String, dynamic> json) {
    return StainingWizard(
      title: json['title'] ?? 'Staining Table',
      panel: (json['panel'] as List? ?? []).map<StainChain>((c) => StainChain.fromJson(c)).toList(),
      samples: (json['samples'] as List? ?? []).map<StainingSample>((s) => StainingSample.fromJson(s)).toList(),
      includeUnstained: json['includeUnstained'] ?? true,
      includeSecondaryOnly: json['includeSecondaryOnly'] ?? true,
      includeFullStain: json['includeFullStain'] ?? true,
    );
  }

  StainingWizard copyWith({
    String? title,
    List<StainChain>? panel,
    List<StainingSample>? samples,
    bool? includeUnstained,
    bool? includeSecondaryOnly,
    bool? includeFullStain,
  }) {
    return StainingWizard(
      title: title ?? this.title,
      panel: panel ?? this.panel,
      samples: samples ?? this.samples,
      includeUnstained: includeUnstained ?? this.includeUnstained,
      includeSecondaryOnly: includeSecondaryOnly ?? this.includeSecondaryOnly,
      includeFullStain: includeFullStain ?? this.includeFullStain,
    );
  }

  ProtocolTable generateTable() {
    final service = StainingTableGeneratorService();
    final result = service.generateTable(
      this,
      includeUnstainedControl: includeUnstained,
      includeSecondaryOnlyControl: includeSecondaryOnly,
      includeFullStainRow: includeFullStain,
    );

    final List<String> headers = ['Tube/sample name', 'Total stains', ...result.stainColumns];
    
    // Regular Rows
    final List<List<dynamic>> data = result.rows.map<List<dynamic>>((row) {
      return <dynamic>[
        row.rowName,
        row.totalStainsText,
        ...result.stainColumns.map<String>((col) => row.stainMap[col] == true ? '+' : '-')
      ];
    }).toList();

    final List<List<String>> cellColors = result.rows.map<List<String>>((row) {
      return <String>[
        '', 
        '', 
        ...result.stainColumns.map<String>((col) => row.stainMap[col] == true ? '#4CAF50' : '#EF5350')
      ];
    }).toList();

    // Append Metadata Rows
    for (var metaRow in result.metadataRows) {
      data.add(<dynamic>[
        metaRow.rowName,
        '',
        ...result.stainColumns.map<String>((col) => metaRow.metadataValues[col] ?? '')
      ]);
      cellColors.add(List<String>.generate(headers.length, (_) => '#F5F5F5')); // Light grey for meta rows
    }

    return ProtocolTable(
      id: 'staining_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: TableType.staining,
      columnHeaders: headers,
      rowHeaders: List.generate(data.length, (i) => (i + 1).toString()),
      data: data,
      cellColors: cellColors,
      metadata: {
        'wizard_state': jsonEncode(toJson()),
      },
    );
  }
}
