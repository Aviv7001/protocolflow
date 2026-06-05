import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/protocol_table.dart';
import 'json_file_saver.dart';

class TableExportService {
  const TableExportService();

  Future<void> copyToClipboard(
    ProtocolTable table, {
    bool includeRowHeaders = false,
  }) {
    return Clipboard.setData(
      ClipboardData(text: toTsv(table, includeRowHeaders: includeRowHeaders)),
    );
  }

  Future<void> exportToExcel(
    ProtocolTable table, {
    bool includeRowHeaders = false,
  }) {
    return saveJsonFile(
      _toExcelHtml(table, includeRowHeaders: includeRowHeaders),
      '${_safeFileName(table.title, fallback: 'table')}.xls',
    );
  }

  String toTsv(ProtocolTable table, {bool includeRowHeaders = false}) {
    final rows = <List<String>>[
      _headers(table, includeRowHeaders: includeRowHeaders),
      ..._rows(table, includeRowHeaders: includeRowHeaders),
    ];

    return rows
        .map((row) => row.map((cell) => cell.replaceAll('\n', ' ')).join('\t'))
        .join('\n');
  }

  String _toExcelHtml(ProtocolTable table, {bool includeRowHeaders = false}) {
    final title = const HtmlEscape().convert(
      table.title.isEmpty ? 'ProtocolFlow Table' : table.title,
    );
    final headers = _headers(
      table,
      includeRowHeaders: includeRowHeaders,
    ).map((header) => '<th>${const HtmlEscape().convert(header)}</th>').join();
    final rows = _rows(table, includeRowHeaders: includeRowHeaders)
        .map(
          (row) =>
              '<tr>${row.map((cell) => '<td>${const HtmlEscape().convert(_cellText(cell))}</td>').join()}</tr>',
        )
        .join();

    return '''
<html>
  <head>
    <meta charset="utf-8">
    <style>
      table { border-collapse: collapse; font-family: Arial, sans-serif; }
      th, td { border: 1px solid #bdbdbd; padding: 6px 8px; }
      th { background: #eeeeee; font-weight: bold; }
    </style>
  </head>
  <body>
    <h3>$title</h3>
    <table>
      <thead><tr>$headers</tr></thead>
      <tbody>$rows</tbody>
    </table>
  </body>
</html>
''';
  }

  List<String> _headers(
    ProtocolTable table, {
    required bool includeRowHeaders,
  }) {
    if (!includeRowHeaders) return table.columnHeaders;
    return ['#', ...table.columnHeaders];
  }

  List<List<String>> _rows(
    ProtocolTable table, {
    required bool includeRowHeaders,
  }) {
    return table.data.asMap().entries.map((entry) {
      final row = entry.value
          .map((cell) => _cellText(cell).replaceAll('\t', ' '))
          .toList();
      if (!includeRowHeaders) return row;

      final rowHeader = entry.key < table.rowHeaders.length
          ? table.rowHeaders[entry.key]
          : (entry.key + 1).toString();
      return [rowHeader, ...row];
    }).toList();
  }

  String _cellText(Object? value) => value?.toString() ?? '';

  String _safeFileName(String value, {required String fallback}) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? fallback : sanitized;
  }
}
