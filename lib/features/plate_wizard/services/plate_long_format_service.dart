import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../../../models/plate_wizard.dart';
import '../../../models/protocol_table.dart';
import '../../../services/json_file_saver.dart';
import '../../../services/xlsx_export_service.dart';

class PlateLongFormatService {
  const PlateLongFormatService();

  static const _xlsx = XlsxExportService();

  static const headers = [
    'Plate num',
    'Column',
    'Row',
    'Sample',
    'Condition',
    'Dilution',
    'Replicate',
  ];

  Future<void> downloadTemplate() {
    final rows = [
      headers,
      ['1', '1', '1', 'sample1', 'PBS', '0.2', '1'],
      ['1', '2', '1', 'sample1', 'PBS', '0.2', '2'],
      ['1', '1', '2', 'sample2', 'Drug A', '1:10', '1'],
      ['1', '2', '2', 'sample2', 'Drug A', '1:10', '2'],
    ];

    return saveBinaryFile(
      _xlsx.buildWorkbook(sheetName: 'Plate Long Format', rows: rows),
      'protocolflow_plate_long_format_template.xlsx',
      mimeType: XlsxExportService.mimeType,
    );
  }

  Future<PlateLongFormatImportResult> importTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null) {
      return const PlateLongFormatImportResult(
        success: false,
        message: 'No file selected.',
      );
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      return const PlateLongFormatImportResult(
        success: false,
        message: 'Could not read selected file.',
      );
    }

    final rows = _parseRows(bytes, extension: file.extension ?? '');
    if (rows.length < 2) {
      return const PlateLongFormatImportResult(
        success: false,
        message: 'No plate rows found in the selected file.',
      );
    }

    final headerIndex = _findHeaderIndex(rows);
    if (headerIndex == -1) {
      return PlateLongFormatImportResult(
        success: false,
        message: _looksLikeBinaryFile(bytes)
            ? 'Could not read this Excel file. Please use a .xlsx workbook exported from ProtocolFlow or saved by Excel as .xlsx.'
            : 'Missing required headers: Plate num, Column, Row, Sample, Condition, Dilution, Replicate.',
      );
    }

    final headerMap = _headerMap(rows[headerIndex]);
    final entries = <_PlateLongEntry>[];
    for (final row in rows.skip(headerIndex + 1)) {
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      final entry = _entryFromRow(row, headerMap);
      if (entry != null) entries.add(entry);
    }

    if (entries.isEmpty) {
      return const PlateLongFormatImportResult(
        success: false,
        message: 'No valid occupied wells were found.',
      );
    }

    final maxRows = entries.map((entry) => entry.row).reduce(_max);
    final maxColumns = entries.map((entry) => entry.column).reduce(_max);
    final plateCount = entries.map((entry) => entry.plateNum).reduce(_max);

    return PlateLongFormatImportResult(
      success: true,
      message: 'Imported ${entries.length} wells.',
      tables: _tablesFromEntries(
        entries,
        rows: maxRows,
        columns: maxColumns,
        plateCount: plateCount,
      ),
      items: _itemsFromEntries(entries),
      rows: maxRows,
      columns: maxColumns,
      plateCount: plateCount,
    );
  }

  List<TestItem> _itemsFromEntries(List<_PlateLongEntry> entries) {
    final bySample = <String, List<_PlateLongEntry>>{};
    for (final entry in entries) {
      bySample.putIfAbsent(entry.sample, () => []).add(entry);
    }

    return bySample.entries.map((entry) {
      final sampleEntries = entry.value;
      final conditions = sampleEntries
          .map((item) => item.condition)
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      final dilutions = sampleEntries
          .map((item) => item.dilution)
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      final replicateNumbers = sampleEntries
          .map((item) => int.tryParse(item.replicate))
          .whereType<int>();

      return TestItem(
        sampleName: entry.key,
        conditions: conditions.isEmpty ? [''] : conditions,
        dilutions: dilutions.isEmpty ? [''] : dilutions,
        duplicates: replicateNumbers.isEmpty
            ? 1
            : replicateNumbers.reduce(_max),
      );
    }).toList();
  }

  List<ProtocolTable> _tablesFromEntries(
    List<_PlateLongEntry> entries, {
    required int rows,
    required int columns,
    required int plateCount,
  }) {
    final byPlate = <int, List<_PlateLongEntry>>{};
    for (final entry in entries) {
      byPlate.putIfAbsent(entry.plateNum, () => []).add(entry);
    }

    final palette = [
      '#FFEBEE',
      '#E3F2FD',
      '#F1F8E9',
      '#FFF3E0',
      '#F3E5F5',
      '#E0F2F1',
      '#FFFDE7',
      '#FBE9E7',
      '#EFEBE9',
      '#ECEFF1',
    ];
    final sampleColors = <String, String>{};

    return List.generate(plateCount, (index) {
      final plateNum = index + 1;
      final plateEntries = byPlate[plateNum] ?? const <_PlateLongEntry>[];
      final data = List.generate(
        rows,
        (_) => List.generate(columns, (_) => ''),
      );
      final colors = List.generate(
        rows,
        (_) => List.generate(columns, (_) => ''),
      );

      for (final entry in plateEntries) {
        final rowIndex = entry.row - 1;
        final colIndex = entry.column - 1;
        data[rowIndex][colIndex] =
            '${entry.sample}\n${entry.condition}\n${entry.dilution}\nRep ${entry.replicate}';
        colors[rowIndex][colIndex] = sampleColors.putIfAbsent(
          entry.sample.toLowerCase(),
          () => palette[sampleColors.length % palette.length],
        );
      }

      return ProtocolTable(
        id: 'plate_long_${DateTime.now().millisecondsSinceEpoch}_$plateNum',
        title: plateCount > 1
            ? 'Imported Plate Layout $plateNum'
            : 'Imported Plate Layout',
        type: TableType.plateLayout,
        columnHeaders: List.generate(
          columns,
          (index) => (index + 1).toString(),
        ),
        rowHeaders: List.generate(
          rows,
          (index) => String.fromCharCode(65 + index),
        ),
        data: data,
        cellColors: colors,
        metadata: {
          'rows': rows.toString(),
          'columns': columns.toString(),
          'plateNumber': plateNum.toString(),
          'plateIndex': (plateNum - 1).toString(),
          'totalPlates': plateCount.toString(),
          'source': 'long_format_import',
        },
      );
    });
  }

  _PlateLongEntry? _entryFromRow(List<String> row, Map<String, int> headerMap) {
    String value(String header) {
      final index = headerMap[_normalizeHeader(header)];
      if (index == null || index >= row.length) return '';
      return row[index].trim();
    }

    final plateNum = int.tryParse(value('Plate num'));
    final column = int.tryParse(value('Column'));
    final rowNumber = int.tryParse(value('Row'));
    final sample = value('Sample');
    if (plateNum == null ||
        column == null ||
        rowNumber == null ||
        plateNum < 1 ||
        column < 1 ||
        rowNumber < 1 ||
        sample.isEmpty) {
      return null;
    }

    return _PlateLongEntry(
      plateNum: plateNum,
      column: column,
      row: rowNumber,
      sample: sample,
      condition: value('Condition'),
      dilution: value('Dilution'),
      replicate: value('Replicate').isEmpty ? '1' : value('Replicate'),
    );
  }

  int _findHeaderIndex(List<List<String>> rows) {
    for (var i = 0; i < rows.length; i++) {
      final map = _headerMap(rows[i]);
      if (headers.every(
        (header) => map.containsKey(_normalizeHeader(header)),
      )) {
        return i;
      }
    }
    return -1;
  }

  Map<String, int> _headerMap(List<String> row) {
    return {for (var i = 0; i < row.length; i++) _normalizeHeader(row[i]): i};
  }

  List<List<String>> _parseRows(List<int> bytes, {required String extension}) {
    if (_isZip(bytes) || extension.toLowerCase() == 'xlsx') {
      final xlsxRows = _parseXlsxRows(bytes);
      if (xlsxRows.isNotEmpty) return xlsxRows;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    if (content.toLowerCase().contains('<table')) {
      return _parseHtmlTable(content);
    }
    if (extension.toLowerCase() == 'tsv' || content.contains('\t')) {
      return const LineSplitter()
          .convert(content)
          .map((line) => line.split('\t').map((cell) => cell.trim()).toList())
          .toList();
    }
    return const LineSplitter().convert(content).map(_parseCsvLine).toList();
  }

  bool _isZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  bool _looksLikeBinaryFile(List<int> bytes) {
    if (_isZip(bytes)) return false;
    final sample = bytes.take(512).toList();
    if (sample.isEmpty) return false;
    final controlBytes = sample.where((byte) {
      return byte < 0x09 || (byte > 0x0D && byte < 0x20);
    }).length;
    return controlBytes > sample.length * 0.1;
  }

  List<List<String>> _parseXlsxRows(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedStrings = _parseSharedStrings(
        _archiveText(archive, 'xl/sharedStrings.xml'),
      );
      final timeStyles = _parseTimeStyles(
        _archiveText(archive, 'xl/styles.xml'),
      );
      final worksheet =
          _archiveText(archive, 'xl/worksheets/sheet1.xml') ??
          _firstWorksheetText(archive);
      if (worksheet == null) return const [];
      return _parseWorksheetRows(worksheet, sharedStrings, timeStyles);
    } catch (_) {
      return const [];
    }
  }

  String? _firstWorksheetText(Archive archive) {
    for (final file in archive.files) {
      if (file.name.startsWith('xl/worksheets/') &&
          file.name.endsWith('.xml')) {
        return _archiveFileText(file);
      }
    }
    return null;
  }

  String? _archiveText(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    return _archiveFileText(file);
  }

  String _archiveFileText(ArchiveFile file) {
    return utf8.decode(file.content, allowMalformed: true);
  }

  List<String> _parseSharedStrings(String? xml) {
    if (xml == null) return const [];
    final itemRegex = RegExp(
      r'<si[^>]*>(.*?)</si>',
      caseSensitive: false,
      dotAll: true,
    );
    return itemRegex.allMatches(xml).map((match) {
      final itemXml = match.group(1) ?? '';
      final text =
          RegExp(
            r'<t[^>]*>(.*?)</t>',
            caseSensitive: false,
            dotAll: true,
          ).allMatches(itemXml).map((textMatch) {
            return _decodeHtml(textMatch.group(1) ?? '');
          }).join();
      return text.trim();
    }).toList();
  }

  List<List<String>> _parseWorksheetRows(
    String worksheetXml,
    List<String> sharedStrings,
    List<bool> timeStyles,
  ) {
    final rows = <List<String>>[];
    final rowRegex = RegExp(
      r'<row[^>]*>(.*?)</row>',
      caseSensitive: false,
      dotAll: true,
    );
    final cellRegex = RegExp(
      r'<c\b([^>]*)>(.*?)</c>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final rowMatch in rowRegex.allMatches(worksheetXml)) {
      final rowXml = rowMatch.group(1) ?? '';
      final row = <String>[];
      for (final cellMatch in cellRegex.allMatches(rowXml)) {
        final attributes = cellMatch.group(1) ?? '';
        final cellXml = cellMatch.group(2) ?? '';
        final cellRef = _xmlAttribute(attributes, 'r') ?? '';
        final columnIndex = _columnIndexFromCellRef(cellRef);
        while (row.length <= columnIndex) {
          row.add('');
        }
        row[columnIndex] = _parseWorksheetCell(
          attributes,
          cellXml,
          sharedStrings,
          timeStyles,
        );
      }
      if (row.any((cell) => cell.trim().isNotEmpty)) rows.add(row);
    }

    return rows;
  }

  String _parseWorksheetCell(
    String attributes,
    String cellXml,
    List<String> sharedStrings,
    List<bool> timeStyles,
  ) {
    final type = _xmlAttribute(attributes, 't');
    if (type == 'inlineStr') {
      return RegExp(r'<t[^>]*>(.*?)</t>', caseSensitive: false, dotAll: true)
          .allMatches(cellXml)
          .map((match) {
            return _decodeHtml(match.group(1) ?? '');
          })
          .join()
          .trim();
    }

    final value = RegExp(
      r'<v[^>]*>(.*?)</v>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(cellXml)?.group(1);
    if (value == null) return '';

    final decodedValue = _decodeHtml(value).trim();
    if (type == 's') {
      final sharedIndex = int.tryParse(decodedValue);
      if (sharedIndex != null && sharedIndex < sharedStrings.length) {
        return sharedStrings[sharedIndex];
      }
    }
    final styleIndex = int.tryParse(_xmlAttribute(attributes, 's') ?? '');
    if (styleIndex != null &&
        styleIndex < timeStyles.length &&
        timeStyles[styleIndex]) {
      return _formatExcelTime(decodedValue);
    }
    return decodedValue;
  }

  List<bool> _parseTimeStyles(String? stylesXml) {
    if (stylesXml == null) return const [];
    final customFormats = <int, String>{};
    final numFmtRegex = RegExp(
      r'<numFmt\b([^>]*)/?>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in numFmtRegex.allMatches(stylesXml)) {
      final attributes = match.group(1) ?? '';
      final id = int.tryParse(_xmlAttribute(attributes, 'numFmtId') ?? '');
      final code = _xmlAttribute(attributes, 'formatCode');
      if (id != null && code != null) {
        customFormats[id] = _decodeHtml(code);
      }
    }

    final cellXfsMatch = RegExp(
      r'<cellXfs[^>]*>(.*?)</cellXfs>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(stylesXml);
    if (cellXfsMatch == null) return const [];

    final xfRegex = RegExp(
      r'<xf\b([^>]*)/?>',
      caseSensitive: false,
      dotAll: true,
    );
    return xfRegex.allMatches(cellXfsMatch.group(1) ?? '').map((match) {
      final attributes = match.group(1) ?? '';
      final numFmtId = int.tryParse(
        _xmlAttribute(attributes, 'numFmtId') ?? '',
      );
      if (numFmtId == null) return false;
      if ({18, 19, 20, 21, 22, 45, 46, 47}.contains(numFmtId)) return true;
      final customFormat = customFormats[numFmtId]?.toLowerCase() ?? '';
      return customFormat.contains('h') &&
          !customFormat.contains('yyyy') &&
          !customFormat.contains('yy');
    }).toList();
  }

  String _formatExcelTime(String value) {
    final serial = double.tryParse(value);
    if (serial == null) return value;
    final totalMinutes = (serial * 24 * 60).round();
    final hours = (totalMinutes ~/ 60) % 24;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String? _xmlAttribute(String attributes, String name) {
    return RegExp(
      '$name="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(attributes)?.group(1);
  }

  int _columnIndexFromCellRef(String cellRef) {
    final letters = RegExp(
      r'^[A-Z]+',
      caseSensitive: false,
    ).firstMatch(cellRef)?.group(0);
    if (letters == null || letters.isEmpty) return 0;

    var index = 0;
    for (final codeUnit in letters.toUpperCase().codeUnits) {
      index = index * 26 + (codeUnit - 64);
    }
    return index - 1;
  }

  List<List<String>> _parseHtmlTable(String html) {
    final rowRegex = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    );
    final cellRegex = RegExp(
      r'<t[dh][^>]*>(.*?)</t[dh]>',
      caseSensitive: false,
      dotAll: true,
    );

    return rowRegex
        .allMatches(html)
        .map((rowMatch) {
          final rowHtml = rowMatch.group(1) ?? '';
          return cellRegex.allMatches(rowHtml).map((cellMatch) {
            final text = (cellMatch.group(1) ?? '').replaceAll(
              RegExp(r'<[^>]+>'),
              '',
            );
            return _decodeHtml(text).trim();
          }).toList();
        })
        .where((row) => row.isNotEmpty)
        .toList();
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  String _normalizeHeader(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  int _max(int a, int b) => a > b ? a : b;
}

class PlateLongFormatImportResult {
  final bool success;
  final String message;
  final List<ProtocolTable> tables;
  final List<TestItem> items;
  final int? rows;
  final int? columns;
  final int? plateCount;

  const PlateLongFormatImportResult({
    required this.success,
    required this.message,
    this.tables = const [],
    this.items = const [],
    this.rows,
    this.columns,
    this.plateCount,
  });
}

class _PlateLongEntry {
  final int plateNum;
  final int column;
  final int row;
  final String sample;
  final String condition;
  final String dilution;
  final String replicate;

  const _PlateLongEntry({
    required this.plateNum,
    required this.column,
    required this.row,
    required this.sample,
    required this.condition,
    required this.dilution,
    required this.replicate,
  });
}
