import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../models/protocol_table.dart';

class GenericTableImportResult {
  const GenericTableImportResult({
    required this.success,
    required this.message,
    this.table,
  });

  final bool success;
  final String message;
  final ProtocolTable? table;
}

class GenericTableImportService {
  const GenericTableImportService();

  Future<GenericTableImportResult> importTable() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'tsv', 'xlsx', 'html', 'htm'],
      withData: true,
    );
    if (result == null) {
      return const GenericTableImportResult(
        success: false,
        message: 'No file selected.',
      );
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      return const GenericTableImportResult(
        success: false,
        message: 'Could not read selected file.',
      );
    }

    final rows = _parseRows(bytes, extension: file.extension ?? '')
        .map(_trimTrailingEmptyCells)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();
    if (rows.length < 2) {
      return const GenericTableImportResult(
        success: false,
        message:
            'The imported table needs a header row and at least one data row.',
      );
    }

    final headers = rows.first.asMap().entries.map((entry) {
      final value = entry.value.trim();
      return value.isEmpty ? _columnName(entry.key) : value;
    }).toList();
    final columnCount = headers.length;
    final data = rows.skip(1).map((row) {
      return List<dynamic>.generate(
        columnCount,
        (index) => index < row.length ? row[index] : '',
      );
    }).toList();

    if (data.isEmpty || columnCount == 0) {
      return const GenericTableImportResult(
        success: false,
        message: 'No table data was found in the selected file.',
      );
    }

    final title = _fileTitle(file.name);
    return GenericTableImportResult(
      success: true,
      message: 'Imported ${data.length} rows.',
      table: ProtocolTable(
        id: 'table_${DateTime.now().millisecondsSinceEpoch}',
        title: title.isEmpty ? 'Imported Table' : title,
        type: TableType.generic,
        columnHeaders: headers,
        rowHeaders: List.generate(data.length, (index) => '${index + 1}'),
        data: data,
        cellColors: List.generate(
          data.length,
          (_) => List.generate(columnCount, (_) => ''),
        ),
        metadata: {'source': 'generic_table_import'},
      ),
    );
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

  List<List<String>> _parseXlsxRows(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedStrings = _parseSharedStrings(
        _archiveText(archive, 'xl/sharedStrings.xml'),
      );
      final worksheet =
          _archiveText(archive, 'xl/worksheets/sheet1.xml') ??
          _firstWorksheetText(archive);
      if (worksheet == null) return const [];
      return _parseWorksheetRows(worksheet, sharedStrings);
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
      return RegExp(r'<t[^>]*>(.*?)</t>', caseSensitive: false, dotAll: true)
          .allMatches(itemXml)
          .map((textMatch) {
            return _decodeHtml(textMatch.group(1) ?? '');
          })
          .join()
          .trim();
    }).toList();
  }

  List<List<String>> _parseWorksheetRows(
    String worksheetXml,
    List<String> sharedStrings,
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
        final columnIndex = _columnIndexFromCellRef(
          _xmlAttribute(attributes, 'r') ?? '',
        );
        while (row.length <= columnIndex) {
          row.add('');
        }
        row[columnIndex] = _parseWorksheetCell(
          attributes,
          cellXml,
          sharedStrings,
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
  ) {
    if (_xmlAttribute(attributes, 't') == 'inlineStr') {
      return RegExp(r'<t[^>]*>(.*?)</t>', caseSensitive: false, dotAll: true)
          .allMatches(cellXml)
          .map((match) => _decodeHtml(match.group(1) ?? ''))
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
    if (_xmlAttribute(attributes, 't') == 's') {
      final sharedIndex = int.tryParse(decodedValue);
      if (sharedIndex != null && sharedIndex < sharedStrings.length) {
        return sharedStrings[sharedIndex];
      }
    }
    return decodedValue;
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

  List<String> _trimTrailingEmptyCells(List<String> row) {
    final trimmed = row.map((cell) => cell.trim()).toList();
    while (trimmed.isNotEmpty && trimmed.last.isEmpty) {
      trimmed.removeLast();
    }
    return trimmed;
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

  String _fileTitle(String fileName) {
    return fileName.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
  }

  String _columnName(int index) {
    var value = index + 1;
    final chars = <String>[];
    while (value > 0) {
      value--;
      chars.insert(0, String.fromCharCode(65 + (value % 26)));
      value ~/= 26;
    }
    return chars.join();
  }
}
