import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DashboardExportRecord {
  final String label;
  final String format;
  final DateTime createdAt;

  const DashboardExportRecord({
    required this.label,
    required this.format,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'format': format,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DashboardExportRecord.fromJson(Map<String, dynamic> json) {
    return DashboardExportRecord(
      label: json['label'] ?? 'ProtocolFlow export',
      format: json['format'] ?? 'File',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class DashboardActivityService {
  static const _exportsKey = 'dashboard_export_history_json';

  Future<List<DashboardExportRecord>> loadExports() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_exportsKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .map(
            (item) =>
                DashboardExportRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> recordExport(String label, String format) async {
    final records = await loadExports();
    records.insert(
      0,
      DashboardExportRecord(
        label: label,
        format: format,
        createdAt: DateTime.now(),
      ),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _exportsKey,
      jsonEncode(records.take(100).map((record) => record.toJson()).toList()),
    );
  }
}
