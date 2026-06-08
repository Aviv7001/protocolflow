import '../models/protocol_table.dart';
import 'json_file_saver.dart';
import 'rich_clipboard_service.dart';
import 'xlsx_export_service.dart';

class TableExportService {
  const TableExportService();

  static const _xlsx = XlsxExportService();
  static const _clipboard = RichClipboardService();

  Future<void> copyToClipboard(
    ProtocolTable table, {
    bool includeRowHeaders = false,
  }) {
    final rows = <List<String>>[
      _headers(table, includeRowHeaders: includeRowHeaders),
      ..._rows(table, includeRowHeaders: includeRowHeaders),
    ];
    return _clipboard.copyTable(
      plainText: _rowsToTsv(rows),
      html: _rowsToHtmlTable(rows),
    );
  }

  Future<void> exportToExcel(
    ProtocolTable table, {
    bool includeRowHeaders = false,
  }) {
    final rows = <List<String>>[
      _headers(table, includeRowHeaders: includeRowHeaders),
      ..._rows(table, includeRowHeaders: includeRowHeaders),
    ];
    return saveBinaryFile(
      _xlsx.buildWorkbook(
        sheetName: table.title.isEmpty ? 'ProtocolFlow Table' : table.title,
        rows: rows,
      ),
      '${_safeFileName(table.title, fallback: 'table')}.xlsx',
      mimeType: XlsxExportService.mimeType,
    );
  }

  Future<void> exportPlateLongToExcel(
    List<ProtocolTable> tables, {
    required String title,
  }) {
    return saveBinaryFile(
      _xlsx.buildWorkbook(
        sheetName: 'Plate Long Format',
        rows: [
          const [
            'Plate num',
            'Column',
            'Row',
            'Sample',
            'Condition',
            'Dilution',
            'Replicate',
          ],
          ..._plateLongRows(tables),
        ],
      ),
      '${_safeFileName(title, fallback: 'plate_layout')}_long.xlsx',
      mimeType: XlsxExportService.mimeType,
    );
  }

  String toTsv(ProtocolTable table, {bool includeRowHeaders = false}) {
    final rows = <List<String>>[
      _headers(table, includeRowHeaders: includeRowHeaders),
      ..._rows(table, includeRowHeaders: includeRowHeaders),
    ];

    return _rowsToTsv(rows);
  }

  List<List<String>> _plateLongRows(List<ProtocolTable> tables) {
    final rows = <List<String>>[];

    for (final table in tables) {
      final plateNumber =
          int.tryParse(table.metadata['plateNumber'] ?? '') ??
          ((int.tryParse(table.metadata['plateIndex'] ?? '') ?? 0) + 1);
      for (var rowIndex = 0; rowIndex < table.data.length; rowIndex++) {
        final row = table.data[rowIndex];
        for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
          final content = _cellText(row[columnIndex]).trim();
          if (content.isEmpty) continue;

          final parts = content.split('\n');
          rows.add([
            plateNumber.toString(),
            (columnIndex + 1).toString(),
            (rowIndex + 1).toString(),
            parts.isNotEmpty ? parts[0] : '',
            parts.length > 1 ? parts[1] : '',
            parts.length > 2 ? parts[2] : '',
            parts.length > 3
                ? parts[3].replaceFirst(
                    RegExp(r'^Rep\s+', caseSensitive: false),
                    '',
                  )
                : '',
          ]);
        }
      }
    }

    return rows;
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

  String _rowsToTsv(List<List<String>> rows) {
    return rows
        .map((row) => row.map((cell) => cell.replaceAll('\n', ' ')).join('\t'))
        .join('\n');
  }

  String _rowsToHtmlTable(List<List<String>> rows) {
    final body = rows.asMap().entries.map((entry) {
      final tag = entry.key == 0 ? 'th' : 'td';
      final style = entry.key == 0
          ? 'border:1px solid #999;padding:4px 6px;background:#e5e7eb;font-weight:bold;'
          : 'border:1px solid #999;padding:4px 6px;';
      final cells = entry.value.map((cell) {
        return '<$tag style="$style">${_escapeHtml(cell).replaceAll('\n', '<br>')}</$tag>';
      }).join();
      return '<tr>$cells</tr>';
    }).join();

    return '''
<table style="border-collapse:collapse;font-family:Arial,sans-serif;font-size:11pt;">
  $body
</table>
''';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _safeFileName(String value, {required String fallback}) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? fallback : sanitized;
  }
}
