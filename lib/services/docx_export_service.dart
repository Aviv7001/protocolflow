import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/completed_protocol.dart';
import '../models/protocol.dart';
import '../models/protocol_additional_data.dart';
import '../models/protocol_step.dart';
import '../models/protocol_table.dart';
import '../models/step_note.dart';
import 'docx_image_loader.dart';
import 'json_file_saver.dart';
import 'protocol_export_filename.dart';

class DocxExportService {
  static const String mimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  const DocxExportService();

  Future<void> exportProtocol(Protocol protocol) async {
    final bytes = await buildDocument(protocol);
    await saveBinaryFile(
      bytes,
      ProtocolExportFilename.protocol(protocol, 'docx'),
      mimeType: mimeType,
    );
  }

  Future<void> exportCompletedProtocol(CompletedProtocol completed) async {
    final bytes = await buildDocument(
      completed.protocol,
      notes: completed.notes,
      completedAt: completed.completedAt,
    );
    await saveBinaryFile(
      bytes,
      ProtocolExportFilename.completed(
        completed.protocol,
        completed.completedAt,
        'docx',
      ),
      mimeType: mimeType,
    );
  }

  Future<Uint8List> buildDocument(
    Protocol protocol, {
    List<StepNote> notes = const [],
    DateTime? completedAt,
  }) async {
    final assets = await _collectAssets(protocol, notes);
    final archive = Archive();
    _addText(archive, '[Content_Types].xml', _contentTypes(assets.images));
    _addText(archive, '_rels/.rels', _rootRelationships());
    _addText(archive, 'docProps/core.xml', _coreProperties(protocol));
    _addText(archive, 'docProps/app.xml', _appProperties());
    _addText(archive, 'word/styles.xml', _styles());
    _addText(archive, 'word/numbering.xml', _numbering());
    _addText(
      archive,
      'word/_rels/document.xml.rels',
      _documentRelationships(assets),
    );
    _addText(
      archive,
      'word/document.xml',
      _documentXml(protocol, notes, completedAt, assets),
    );

    for (final image in assets.images) {
      archive.addFile(
        ArchiveFile(
          'word/media/image${image.index}.${image.extension}',
          image.bytes.length,
          image.bytes,
        ),
      );
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<_DocxAssets> _collectAssets(
    Protocol protocol,
    List<StepNote> notes,
  ) async {
    final sources = <String>{
      ...notes.expand((note) => note.photoPaths),
      ...protocol.additionalData.expand((data) => data.photoPaths),
    };
    final images = <_DocxImage>[];
    final imageBySource = <String, _DocxImage>{};

    for (final source in sources) {
      final bytes = await loadDocxImageBytes(source);
      if (bytes == null || bytes.isEmpty) continue;
      final format = _imageFormat(bytes);
      if (format == null) continue;
      final image = _DocxImage(
        index: images.length + 1,
        source: source,
        bytes: bytes,
        extension: format.$1,
        contentType: format.$2,
        relationshipId: 'rIdImage${images.length + 1}',
      );
      images.add(image);
      imageBySource[source] = image;
    }

    final links = <String, String>{};
    var linkIndex = 1;
    for (final data in protocol.additionalData) {
      final link = data.link.trim();
      if (link.isEmpty || links.containsKey(link)) continue;
      links[link] = 'rIdLink${linkIndex++}';
    }

    return _DocxAssets(
      images: images,
      imageBySource: imageBySource,
      linkRelationships: links,
    );
  }

  (String, String)? _imageFormat(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return ('png', 'image/png');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return ('jpg', 'image/jpeg');
    }
    if (bytes.length >= 6 &&
        ascii.decode(bytes.sublist(0, 3), allowInvalid: true) == 'GIF') {
      return ('gif', 'image/gif');
    }
    return null;
  }

  String _documentXml(
    Protocol protocol,
    List<StepNote> notes,
    DateTime? completedAt,
    _DocxAssets assets,
  ) {
    final body = StringBuffer();
    body.write(_paragraph(protocol.title, style: 'Title'));
    body.write(
      _paragraph(
        completedAt == null
            ? 'Protocol'
            : 'Completed ${_formatDate(completedAt)}',
        style: 'Subtitle',
      ),
    );

    if (protocol.objective.trim().isNotEmpty) {
      body.write(_heading('Objective', 1));
      body.write(_paragraph(protocol.objective));
    }
    if (protocol.description.trim().isNotEmpty) {
      body.write(_heading('Description', 1));
      body.write(_paragraph(protocol.description));
    }

    if (protocol.samples.isNotEmpty) {
      body.write(_heading('Samples', 1));
      for (final sample in protocol.samples.where((s) => s.trim().isNotEmpty)) {
        body.write(_bullet(sample));
      }
    }

    body.write(_heading('Materials', 1));
    if (protocol.materials.isEmpty) {
      body.write(_paragraph('No materials listed.'));
    } else {
      body.write(
        _table(
          const [
            'Name',
            'Quantity',
            'Catalog #',
            'Manufacturer',
            'Location',
            'Stock concentration',
          ],
          protocol.materials
              .map(
                (material) => [
                  material.name,
                  material.quantity,
                  material.catalogNumber,
                  material.manufacturer,
                  material.location,
                  material.stockConcentration,
                ],
              )
              .toList(),
        ),
      );
    }
    body.write(_notesXml(notes.where((n) => n.stepId == 'materials'), assets));

    body.write(_heading('Steps', 1));
    final sortedSteps = List<ProtocolStep>.from(protocol.steps)
      ..sort((a, b) => a.day.compareTo(b.day));
    String? previousGroup;
    for (var index = 0; index < sortedSteps.length; index++) {
      final step = sortedSteps[index];
      final group = step.phaseName?.trim().isNotEmpty == true
          ? step.phaseName!.trim()
          : 'Day ${step.day}';
      if (group != previousGroup) {
        body.write(_heading(group, 2));
        previousGroup = group;
      }
      body.write(_heading('${index + 1}. ${step.title}', 3));
      if (step.instructions.trim().isNotEmpty) {
        body.write(_paragraph(step.instructions));
      }
      for (
        var actionIndex = 0;
        actionIndex < step.actionItems.length;
        actionIndex++
      ) {
        final action = step.actionItems[actionIndex];
        final timer = step.actionTimers[actionIndex];
        final suffix = timer == null || timer <= 0
            ? ''
            : ' (${_formatDuration(timer)})';
        body.write(_bullet('$action$suffix'));
      }
      for (final tableId in step.tableIds) {
        final table = protocol.tables.cast<ProtocolTable?>().firstWhere(
          (candidate) => candidate?.id == tableId,
          orElse: () => null,
        );
        if (table != null) {
          body.write(_protocolTableXml(table));
        }
      }
      body.write(_notesXml(notes.where((n) => n.stepId == step.id), assets));
    }

    final overviewNotes = notes.where((n) => n.stepId == 'overview');
    if (overviewNotes.isNotEmpty) {
      body.write(_heading('General Notes', 1));
      body.write(_notesXml(overviewNotes, assets));
    }

    final assignedTableIds = protocol.steps.expand((s) => s.tableIds).toSet();
    final referenceTables = protocol.tables
        .where((table) => !assignedTableIds.contains(table.id))
        .toList();
    if (protocol.files.isNotEmpty ||
        referenceTables.isNotEmpty ||
        protocol.additionalData.isNotEmpty) {
      body.write(_heading('Supplementary', 1));
      if (protocol.files.isNotEmpty) {
        body.write(_heading('Attached Files', 2));
        for (final file in protocol.files) {
          body.write(_bullet(file));
        }
      }
      if (referenceTables.isNotEmpty) {
        body.write(_heading('Reference Tables', 2));
        for (final table in referenceTables) {
          body.write(_protocolTableXml(table));
        }
      }
      if (protocol.additionalData.isNotEmpty) {
        body.write(_heading('Additional Data', 2));
        for (final data in protocol.additionalData) {
          body.write(_additionalDataXml(data, assets));
        }
      }
    }

    body.write(
      '<w:sectPr>'
      '<w:pgSz w:w="12240" w:h="15840"/>'
      '<w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" '
      'w:header="720" w:footer="720" w:gutter="0"/>'
      '</w:sectPr>',
    );

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:body>$body</w:body></w:document>';
  }

  String _additionalDataXml(ProtocolAdditionalData data, _DocxAssets assets) {
    final xml = StringBuffer()..write(_heading(data.title, 3));
    if (data.description.trim().isNotEmpty) {
      xml.write(_paragraph(data.description));
    }
    final relationshipId = assets.linkRelationships[data.link.trim()];
    if (relationshipId != null) {
      xml.write(_hyperlink(data.link.trim(), relationshipId));
    }
    for (final source in data.photoPaths) {
      final image = assets.imageBySource[source];
      if (image != null) xml.write(_imageParagraph(image));
    }
    return xml.toString();
  }

  String _notesXml(Iterable<StepNote> notes, _DocxAssets assets) {
    final xml = StringBuffer();
    for (final note in notes) {
      if (note.note.trim().isNotEmpty) {
        xml.write(_paragraph('Note: ${note.note}', italic: true));
      }
      for (final source in note.photoPaths) {
        final image = assets.imageBySource[source];
        if (image != null) xml.write(_imageParagraph(image));
      }
    }
    return xml.toString();
  }

  String _protocolTableXml(ProtocolTable table) {
    final hasRowHeaders = table.rowHeaders.isNotEmpty;
    final headers = <String>[if (hasRowHeaders) '', ...table.columnHeaders];
    final rows = <List<String>>[];
    for (var rowIndex = 0; rowIndex < table.data.length; rowIndex++) {
      rows.add([
        if (hasRowHeaders)
          rowIndex < table.rowHeaders.length ? table.rowHeaders[rowIndex] : '',
        ...table.data[rowIndex].map(_cellText),
      ]);
    }
    return _heading(table.title, 3) + _table(headers, rows);
  }

  String _table(List<String> headers, List<List<String>> rows) {
    final columnCount = [
      headers.length,
      ...rows.map((row) => row.length),
    ].fold<int>(0, (max, value) => value > max ? value : max);
    if (columnCount == 0) return '';
    const usableWidth = 10080;
    final columnWidth = usableWidth ~/ columnCount;
    final grid = List.generate(
      columnCount,
      (_) => '<w:gridCol w:w="$columnWidth"/>',
    ).join();
    final xml = StringBuffer()
      ..write(
        '<w:tbl><w:tblPr><w:tblW w:w="$usableWidth" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/><w:tblBorders>'
        '<w:top w:val="single" w:sz="4" w:color="B8C2CC"/>'
        '<w:left w:val="single" w:sz="4" w:color="B8C2CC"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="B8C2CC"/>'
        '<w:right w:val="single" w:sz="4" w:color="B8C2CC"/>'
        '<w:insideH w:val="single" w:sz="4" w:color="D9E0E6"/>'
        '<w:insideV w:val="single" w:sz="4" w:color="D9E0E6"/>'
        '</w:tblBorders><w:tblCellMar>'
        '<w:top w:w="90" w:type="dxa"/><w:left w:w="90" w:type="dxa"/>'
        '<w:bottom w:w="90" w:type="dxa"/><w:right w:w="90" w:type="dxa"/>'
        '</w:tblCellMar></w:tblPr><w:tblGrid>$grid</w:tblGrid>',
      );
    if (headers.isNotEmpty) {
      xml.write(_tableRow(headers, columnCount, columnWidth, header: true));
    }
    for (final row in rows) {
      xml.write(_tableRow(row, columnCount, columnWidth));
    }
    xml.write('</w:tbl><w:p/>');
    return xml.toString();
  }

  String _tableRow(
    List<String> values,
    int columnCount,
    int columnWidth, {
    bool header = false,
  }) {
    final xml = StringBuffer()..write('<w:tr>');
    for (var index = 0; index < columnCount; index++) {
      final value = index < values.length ? values[index] : '';
      xml.write(
        '<w:tc><w:tcPr><w:tcW w:w="$columnWidth" w:type="dxa"/>'
        '${header ? '<w:shd w:val="clear" w:color="auto" w:fill="DCEAF7"/>' : ''}'
        '<w:vAlign w:val="center"/></w:tcPr>'
        '${_paragraph(value, bold: header, compact: true, fontSize: 16)}'
        '</w:tc>',
      );
    }
    xml.write('</w:tr>');
    return xml.toString();
  }

  String _heading(String text, int level) {
    return _paragraph(text, style: 'Heading$level');
  }

  String _bullet(String text) {
    return '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/>'
        '<w:numId w:val="1"/></w:numPr></w:pPr>${_run(text)}</w:p>';
  }

  String _paragraph(
    String text, {
    String? style,
    bool bold = false,
    bool italic = false,
    bool compact = false,
    int? fontSize,
  }) {
    final properties = StringBuffer();
    if (style != null) properties.write('<w:pStyle w:val="$style"/>');
    if (compact) properties.write('<w:spacing w:after="0"/>');
    final pPr = properties.isEmpty ? '' : '<w:pPr>$properties</w:pPr>';
    return '<w:p>$pPr${_run(text, bold: bold, italic: italic, fontSize: fontSize)}</w:p>';
  }

  String _run(
    String text, {
    bool bold = false,
    bool italic = false,
    int? fontSize,
  }) {
    final properties = StringBuffer();
    if (bold) properties.write('<w:b/>');
    if (italic) properties.write('<w:i/>');
    if (fontSize != null) {
      properties.write('<w:sz w:val="$fontSize"/><w:szCs w:val="$fontSize"/>');
    }
    final rPr = properties.isEmpty ? '' : '<w:rPr>$properties</w:rPr>';
    return '<w:r>$rPr<w:t xml:space="preserve">${_escape(text)}</w:t></w:r>';
  }

  String _hyperlink(String text, String relationshipId) {
    return '<w:p><w:hyperlink r:id="$relationshipId">'
        '<w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr>'
        '<w:t>${_escape(text)}</w:t></w:r></w:hyperlink></w:p>';
  }

  String _imageParagraph(_DocxImage image) {
    const width = 2743200;
    const height = 2057400;
    return '<w:p><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$width" cy="$height"/>'
        '<wp:docPr id="${image.index}" name="ProtocolFlow photo ${image.index}"/>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="image${image.index}.${image.extension}"/>'
        '<pic:cNvPicPr/></pic:nvPicPr><pic:blipFill>'
        '<a:blip r:embed="${image.relationshipId}"/><a:stretch><a:fillRect/></a:stretch>'
        '</pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="$width" cy="$height"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic>'
        '</wp:inline></w:drawing></w:r></w:p>';
  }

  String _contentTypes(List<_DocxImage> images) {
    final defaults = images
        .map((image) => (image.extension, image.contentType))
        .toSet()
        .map(
          (entry) =>
              '<Default Extension="${entry.$1}" ContentType="${entry.$2}"/>',
        )
        .join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>$defaults'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';
  }

  String _rootRelationships() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
        '</Relationships>';
  }

  String _documentRelationships(_DocxAssets assets) {
    final relationships = StringBuffer()
      ..write(
        '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '<Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>',
      );
    for (final image in assets.images) {
      relationships.write(
        '<Relationship Id="${image.relationshipId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image${image.index}.${image.extension}"/>',
      );
    }
    assets.linkRelationships.forEach((link, id) {
      relationships.write(
        '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="${_escapeAttribute(link)}" TargetMode="External"/>',
      );
    });
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$relationships</Relationships>';
  }

  String _styles() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
        '${_paragraphStyle('Normal', 'Normal', 22, '000000', 120)}'
        '${_paragraphStyle('Title', 'Title', 40, '17365D', 180, bold: true, keepNext: true)}'
        '${_paragraphStyle('Subtitle', 'Subtitle', 22, '5B6770', 240, keepNext: true)}'
        '${_paragraphStyle('Heading1', 'Heading 1', 30, '17365D', 160, bold: true, before: 280, keepNext: true)}'
        '${_paragraphStyle('Heading2', 'Heading 2', 26, '2F5D7C', 120, bold: true, before: 220, keepNext: true)}'
        '${_paragraphStyle('Heading3', 'Heading 3', 23, '1F2933', 80, bold: true, before: 160, keepNext: true)}'
        '<w:style w:type="character" w:styleId="Hyperlink"><w:name w:val="Hyperlink"/>'
        '<w:basedOn w:val="DefaultParagraphFont"/><w:uiPriority w:val="99"/>'
        '<w:unhideWhenUsed/><w:rPr><w:color w:val="0563C1"/><w:u w:val="single"/></w:rPr></w:style>'
        '</w:styles>';
  }

  String _paragraphStyle(
    String id,
    String name,
    int size,
    String color,
    int after, {
    bool bold = false,
    int before = 0,
    bool keepNext = false,
  }) {
    return '<w:style w:type="paragraph" w:styleId="$id">'
        '<w:name w:val="$name"/><w:qFormat/><w:pPr>'
        '${keepNext ? '<w:keepNext/>' : ''}<w:spacing w:before="$before" w:after="$after"/></w:pPr>'
        '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>'
        '${bold ? '<w:b/>' : ''}<w:color w:val="$color"/>'
        '<w:sz w:val="$size"/><w:szCs w:val="$size"/></w:rPr></w:style>';
  }

  String _numbering() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/>'
        '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/>'
        '<w:lvlText w:val="&#x2022;"/><w:lvlJc w:val="left"/>'
        '<w:pPr><w:tabs><w:tab w:val="num" w:pos="540"/></w:tabs>'
        '<w:ind w:left="540" w:hanging="270"/></w:pPr>'
        '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/></w:rPr>'
        '</w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
        '</w:numbering>';
  }

  String _coreProperties(Protocol protocol) {
    final now = DateTime.now().toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_escape(protocol.title)}</dc:title><dc:creator>ProtocolFlow</dc:creator>'
        '<cp:lastModifiedBy>ProtocolFlow</cp:lastModifiedBy>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>'
        '</cp:coreProperties>';
  }

  String _appProperties() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Application>ProtocolFlow</Application></Properties>';
  }

  void _addText(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String _cellText(dynamic value) {
    if (value is bool) return value ? 'Yes' : 'No';
    return value?.toString() ?? '';
  }

  String _formatDuration(int seconds) {
    if (seconds % 3600 == 0) return '${seconds ~/ 3600} h';
    if (seconds % 60 == 0) return '${seconds ~/ 60} min';
    return '$seconds sec';
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _escape(String value) => const HtmlEscape().convert(value);

  String _escapeAttribute(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class _DocxAssets {
  final List<_DocxImage> images;
  final Map<String, _DocxImage> imageBySource;
  final Map<String, String> linkRelationships;

  const _DocxAssets({
    required this.images,
    required this.imageBySource,
    required this.linkRelationships,
  });
}

class _DocxImage {
  final int index;
  final String source;
  final Uint8List bytes;
  final String extension;
  final String contentType;
  final String relationshipId;

  const _DocxImage({
    required this.index,
    required this.source,
    required this.bytes,
    required this.extension,
    required this.contentType,
    required this.relationshipId,
  });
}
