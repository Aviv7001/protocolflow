import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class XlsxExportService {
  const XlsxExportService();

  static const mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  Uint8List buildWorkbook({
    required String sheetName,
    required List<List<Object?>> rows,
    Set<int> headerRows = const {0},
  }) {
    final safeRows = rows.isEmpty ? const <List<Object?>>[] : rows;
    final archive = Archive();
    _addTextFile(archive, '[Content_Types].xml', _contentTypesXml());
    _addTextFile(archive, '_rels/.rels', _rootRelationshipsXml());
    _addTextFile(
      archive,
      'xl/workbook.xml',
      _workbookXml(_safeSheetName(sheetName)),
    );
    _addTextFile(
      archive,
      'xl/_rels/workbook.xml.rels',
      _workbookRelationshipsXml(),
    );
    _addTextFile(archive, 'xl/styles.xml', _stylesXml());
    _addTextFile(
      archive,
      'xl/worksheets/sheet1.xml',
      _worksheetXml(safeRows, headerRows),
    );

    final bytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(bytes);
  }

  void _addTextFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String _worksheetXml(List<List<Object?>> rows, Set<int> headerRows) {
    final maxColumns = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final columnXml = maxColumns == 0
        ? ''
        : '<cols>${List.generate(maxColumns, (index) {
            final width = index == 0 ? 16 : 18;
            final column = index + 1;
            return '<col min="$column" max="$column" width="$width" customWidth="1"/>';
          }).join()}</cols>';
    final rowXml = rows.asMap().entries.map((entry) {
      final rowIndex = entry.key;
      final excelRow = rowIndex + 1;
      final styleIndex = headerRows.contains(rowIndex) ? 1 : 0;
      final cells = entry.value.asMap().entries.map((cellEntry) {
        final ref = '${_columnName(cellEntry.key)}$excelRow';
        final value = _cellText(cellEntry.value);
        return '<c r="$ref" t="inlineStr" s="$styleIndex"><is><t>${_escapeXml(value)}</t></is></c>';
      }).join();
      return '<row r="$excelRow">$cells</row>';
    }).join();

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
  $columnXml
  <sheetData>$rowXml</sheetData>
</worksheet>''';
  }

  String _contentTypesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';
  }

  String _rootRelationshipsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
  }

  String _workbookXml(String sheetName) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${_escapeXml(sheetName)}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
  }

  String _workbookRelationshipsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
  }

  String _stylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="11"/><color theme="1"/><name val="Calibri"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF2563EB"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border><left style="thin"><color rgb="FFD9D9D9"/></left><right style="thin"><color rgb="FFD9D9D9"/></right><top style="thin"><color rgb="FFD9D9D9"/></top><bottom style="thin"><color rgb="FFD9D9D9"/></bottom><diagonal/></border>
  </borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="49" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
    <xf numFmtId="49" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''';
  }

  String _columnName(int zeroBasedIndex) {
    var number = zeroBasedIndex + 1;
    final letters = StringBuffer();
    while (number > 0) {
      final remainder = (number - 1) % 26;
      letters.writeCharCode(65 + remainder);
      number = (number - 1) ~/ 26;
    }
    return letters.toString().split('').reversed.join();
  }

  String _cellText(Object? value) {
    return value?.toString().replaceAll('\t', ' ').replaceAll('\n', ' ') ?? '';
  }

  String _escapeXml(String value) {
    return const HtmlEscape().convert(value).replaceAll('&apos;', '&#39;');
  }

  String _safeSheetName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\[\]\*:/\\?]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final safe = sanitized.isEmpty ? 'Sheet1' : sanitized;
    return safe.length > 31 ? safe.substring(0, 31) : safe;
  }
}
