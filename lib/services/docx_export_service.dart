import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as image;
import 'package:qr/qr.dart';

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
  static const String _qrSource = 'protocolflow:publication-qr';
  static const String _primary = '156F7A';
  static const String _primaryContainer = 'D7F0F3';
  static const String _onPrimaryContainer = '0F4D54';
  static const String _outline = 'AEBCC1';
  static const String _outlineVariant = 'D8E1E4';
  static const String _textPrimary = '1F2933';
  static const String _textSecondary = '61717A';
  static const int _pageWidth = 11906;
  static const int _pageHeight = 16838;
  static const int _pageMargin = 520;
  static const int _usableWidth = _pageWidth - (_pageMargin * 2);
  static const int _columnWidth = _usableWidth;
  static const double _wordPageHeightPoints = _pageHeight / 20;
  static const double _wordVerticalMarginsPoints = (_pageMargin * 2) / 20;
  static const double _wordFooterReservePoints = 32;
  static const double _wordPhasePageBudget =
      _wordPageHeightPoints -
      _wordVerticalMarginsPoints -
      _wordFooterReservePoints;

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
    _addText(archive, 'word/numbering.xml', _numbering(protocol));
    _addText(archive, 'word/footer1.xml', _footer());
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

    final publication = protocol.publication;
    final shareUri = publication != null && publication.isPublic
        ? publication.shareUri.trim()
        : '';
    if (shareUri.isNotEmpty) {
      final bytes = _buildQrPng(shareUri);
      final qrImage = _DocxImage(
        index: 1,
        source: _qrSource,
        bytes: bytes,
        extension: 'png',
        contentType: 'image/png',
        relationshipId: 'rIdImage1',
      );
      images.add(qrImage);
      imageBySource[_qrSource] = qrImage;
    }

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

  Uint8List _buildQrPng(String data) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qr = QrImage(code);
    const quietZone = 4;
    const moduleSize = 6;
    final pixelSize = (qr.moduleCount + quietZone * 2) * moduleSize;
    final output = image.Image(width: pixelSize, height: pixelSize);
    image.fill(output, color: image.ColorRgb8(255, 255, 255));
    final foreground = image.ColorRgb8(21, 111, 122);
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var column = 0; column < qr.moduleCount; column++) {
        if (!qr.isDark(row, column)) continue;
        final left = (column + quietZone) * moduleSize;
        final top = (row + quietZone) * moduleSize;
        image.fillRect(
          output,
          x1: left,
          y1: top,
          x2: left + moduleSize - 1,
          y2: top + moduleSize - 1,
          color: foreground,
        );
      }
    }
    return Uint8List.fromList(image.encodePng(output));
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
    body.write(_reportHeaderXml(protocol, assets));

    body.write(_protocolInformationCard(protocol, notes, completedAt, assets));
    body.write(_stepCardsXml(protocol, notes, assets));

    final overviewNotes = notes.where((note) => note.stepId == 'overview');
    if (overviewNotes.isNotEmpty) {
      body.write(
        _card(_cardTitle('General Notes') + _notesXml(overviewNotes, assets)),
      );
    }
    if (protocol.files.isNotEmpty || protocol.additionalData.isNotEmpty) {
      final supplementary = StringBuffer()
        ..write(_cardTitle('Additional Data'));
      if (protocol.files.isNotEmpty) {
        supplementary.write(_label('Attached Files'));
        for (final file in protocol.files) {
          supplementary.write(_bullet(file));
        }
      }
      for (final data in protocol.additionalData) {
        supplementary.write(_additionalDataXml(data, assets));
      }
      body.write(_card(supplementary.toString()));
    }

    final tables = _orderedTables(protocol);
    if (tables.isNotEmpty) {
      body.write(_pageBreak());
      body.write(_heading('Tables', 1));
      body.write(_divider());
      for (final table in tables) {
        body.write(_protocolTableXml(table));
      }
    }
    body.write(_sectionProperties());

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
        'xmlns:v="urn:schemas-microsoft-com:vml">'
        '<w:body>$body</w:body></w:document>';
  }

  String _reportHeaderXml(Protocol protocol, _DocxAssets assets) {
    final qr = assets.imageBySource[_qrSource];
    if (qr == null) {
      return '<w:tbl><w:tblPr><w:tblW w:w="$_usableWidth" w:type="dxa"/>'
          '<w:tblLayout w:type="fixed"/><w:tblBorders>${_nilBorders()}</w:tblBorders>'
          '</w:tblPr><w:tblGrid><w:gridCol w:w="$_usableWidth"/></w:tblGrid>'
          '<w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr>'
          '<w:tcW w:w="$_usableWidth" w:type="dxa"/><w:vAlign w:val="center"/>'
          '</w:tcPr>${_paragraph(protocol.title, style: 'Title', compact: true)}'
          '</w:tc></w:tr></w:tbl>${_divider()}';
    }
    const titleWidth = _usableWidth - 1320;
    const qrWidth = 1320;
    final qrContent =
        '${_imageParagraph(qr, width: 685800, height: 685800, centered: true)}'
        '${_paragraph('Scan', compact: true, fontSize: 20, alignment: 'center')}';
    return '<w:tbl><w:tblPr><w:tblW w:w="$_usableWidth" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/><w:tblBorders>${_nilBorders()}</w:tblBorders>'
        '<w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/>'
        '<w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar>'
        '</w:tblPr><w:tblGrid><w:gridCol w:w="$titleWidth"/><w:gridCol w:w="$qrWidth"/></w:tblGrid>'
        '<w:tr><w:trPr><w:cantSplit/></w:trPr>'
        '<w:tc><w:tcPr><w:tcW w:w="$titleWidth" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
        '${_paragraph(protocol.title, style: 'Title', compact: true)}</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="$qrWidth" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
        '$qrContent</w:tc></w:tr></w:tbl>${_divider()}';
  }

  String _protocolInformationCard(
    Protocol protocol,
    List<StepNote> notes,
    DateTime? completedAt,
    _DocxAssets assets,
  ) {
    final content = StringBuffer()
      ..write(_cardTitle('Protocol Information'))
      ..write(
        _paragraph(
          completedAt == null ? 'Type: Template' : 'Type: Completed',
          compact: true,
          color: _textSecondary,
        ),
      )
      ..write(
        _paragraph(
          'Created on: ${_formatDate(protocol.createdAt).split(' ').first}',
          compact: true,
          color: _textSecondary,
        ),
      )
      ..write(
        _paragraph(
          'Created by: ${protocol.createdByName ?? 'Unknown user'}',
          compact: true,
          color: _textSecondary,
        ),
      );
    if (completedAt != null) {
      content.write(
        _paragraph(
          'Completed on: ${_formatDate(completedAt)}',
          compact: true,
          color: _textSecondary,
        ),
      );
    }
    content
      ..write(_label('Objective'))
      ..write(_paragraph(_valueOrFallback(protocol.objective), compact: true))
      ..write(_label('Description'))
      ..write(
        _paragraph(_valueOrFallback(protocol.description), compact: true),
      );
    if (protocol.samples.isNotEmpty) {
      content.write(_label('Samples'));
      for (final sample in protocol.samples.where(
        (item) => item.trim().isNotEmpty,
      )) {
        content.write(_bullet(sample));
      }
    }
    final materialNotes = notes.where((note) => note.stepId == 'materials');
    if (materialNotes.isNotEmpty) {
      content.write(_label('Material Notes'));
      content.write(_notesXml(materialNotes, assets));
    }
    return _card(content.toString());
  }

  String _stepCardsXml(
    Protocol protocol,
    List<StepNote> notes,
    _DocxAssets assets,
  ) {
    if (protocol.steps.isEmpty) {
      return _card(_cardTitle('Steps') + _paragraph('No steps added.'));
    }
    final sorted = _sortedProtocolSteps(protocol);
    final hasPhases = sorted.any(
      (step) => step.phaseName != null && step.phaseName!.trim().isNotEmpty,
    );
    final groups = <String, List<ProtocolStep>>{};
    final order = <String>[];
    for (final step in sorted) {
      final title = hasPhases
          ? (step.phaseName?.trim().isNotEmpty == true
                ? step.phaseName!.trim()
                : 'General')
          : 'Day ${step.day}';
      if (!groups.containsKey(title)) {
        groups[title] = <ProtocolStep>[];
        order.add(title);
      }
      groups[title]!.add(step);
    }

    final output = StringBuffer();
    var globalIndex = 0;
    for (final groupTitle in order) {
      final steps = groups[groupTitle]!;
      final chunks = _splitWordPhase(steps, notes);
      for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunk = chunks[chunkIndex];
        output.write(
          _stepGroupCard(
            chunkIndex == 0 ? groupTitle : '$groupTitle (continued)',
            chunk,
            globalIndex,
            protocol,
            notes,
            assets,
          ),
        );
        globalIndex += chunk.length;
      }
    }
    return output.toString();
  }

  String _stepGroupCard(
    String title,
    List<ProtocolStep> steps,
    int startIndex,
    Protocol protocol,
    List<StepNote> notes,
    _DocxAssets assets,
  ) {
    final content = StringBuffer()..write(_groupTitle(title));
    for (var index = 0; index < steps.length; index++) {
      content.write(
        _timelineStep(
          steps[index],
          startIndex + index,
          protocol,
          notes,
          assets,
          isLast: index == steps.length - 1,
        ),
      );
    }
    return _card(content.toString());
  }

  List<List<ProtocolStep>> _splitWordPhase(
    List<ProtocolStep> steps,
    List<StepNote> notes,
  ) {
    const cardAndHeadingHeight = 42.0;
    const betweenStepsHeight = 8.0;
    final chunks = <List<ProtocolStep>>[];
    var current = <ProtocolStep>[];
    var currentHeight = cardAndHeadingHeight;

    for (final step in steps) {
      final stepHeight = _estimateWordStepHeight(step, notes);
      final addedHeight =
          stepHeight + (current.isEmpty ? 0 : betweenStepsHeight);
      if (current.isNotEmpty &&
          currentHeight + addedHeight > _wordPhasePageBudget) {
        chunks.add(current);
        current = <ProtocolStep>[];
        currentHeight = cardAndHeadingHeight;
      }
      current.add(step);
      currentHeight +=
          stepHeight + (current.length == 1 ? 0 : betweenStepsHeight);
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  double _estimateWordStepHeight(ProtocolStep step, List<StepNote> notes) {
    final textWidth = ((_columnWidth / 20) - 76).clamp(180, 500).toDouble();
    var height = 14.0;
    height += _estimateWordTextHeight('Step: ${step.title}', textWidth, 12, 14);
    height += _estimateWordTextHeight(step.instructions, textWidth, 10, 12);
    if (step.timerInSeconds != null) height += 14;
    if (step.materials.isNotEmpty) {
      height += _estimateWordTextHeight(
        step.materials
            .map((material) => '${material.name} (${material.quantity})')
            .join(', '),
        textWidth,
        10,
        12,
      );
    }
    for (final action in step.actionItems) {
      height += _estimateWordTextHeight(action, textWidth - 28, 10, 12) + 1;
    }
    if (step.notes.isNotEmpty) {
      height += 15;
      for (final note in step.notes) {
        height += _estimateWordTextHeight(note, textWidth - 28, 10, 12);
      }
    }
    if (step.tableIds.isNotEmpty) height += 20;

    final userNotes = notes.where((note) => note.stepId == step.id);
    if (userNotes.isNotEmpty) {
      height += 17;
      for (final note in userNotes) {
        height += _estimateWordTextHeight(note.note, textWidth, 10, 12);
        height += note.photoPaths.length * 127;
      }
    }
    return height + 10;
  }

  double _estimateWordTextHeight(
    String text,
    double width,
    double fontSize,
    double lineHeight,
  ) {
    if (text.trim().isEmpty) return 0;
    final averageCharacterWidth = fontSize * 0.5;
    final charactersPerLine = (width / averageCharacterWidth).floor().clamp(
      12,
      180,
    );
    var lines = 0;
    for (final rawLine in text.split('\n')) {
      final length = rawLine.trim().length;
      lines += length == 0 ? 1 : (length / charactersPerLine).ceil();
    }
    return lines * lineHeight;
  }

  String _timelineStep(
    ProtocolStep step,
    int index,
    Protocol protocol,
    List<StepNote> notes,
    _DocxAssets assets, {
    required bool isLast,
  }) {
    final content = StringBuffer()
      ..write(
        _paragraph(
          'Step ${index + 1}: ${step.title}',
          bold: true,
          fontSize: 24,
          compact: true,
          keepNext: true,
          color: _textPrimary,
        ),
      );
    if (step.instructions.trim().isNotEmpty) {
      content.write(_paragraph(step.instructions, compact: true));
    }
    if (step.timerInSeconds != null && step.timerInSeconds! > 0) {
      content.write(
        _paragraph(
          'Timer: ${_formatDuration(step.timerInSeconds!)}',
          italic: true,
          compact: true,
        ),
      );
    }
    if (step.materials.isNotEmpty) {
      content.write(
        _paragraph(
          'Step Materials: ${step.materials.map((material) => '${material.name} (${material.quantity})').join(', ')}',
          compact: true,
        ),
      );
    }
    for (
      var actionIndex = 0;
      actionIndex < step.actionItems.length;
      actionIndex++
    ) {
      final timer = step.actionTimers[actionIndex];
      final suffix = timer == null || timer <= 0
          ? ''
          : ' (${_formatDuration(timer)})';
      content.write(
        _numbered(
          '${step.actionItems[actionIndex]}$suffix',
          numId: 100 + index,
        ),
      );
    }
    if (step.notes.isNotEmpty) {
      content.write(_stepNotesLabel());
      for (final note in step.notes) {
        content.write(_bullet(note));
      }
    }
    final linkedTables = _tablesForIds(protocol, step.tableIds);
    if (linkedTables.isNotEmpty) {
      content.write(
        _paragraph(
          'Tables: ${linkedTables.map((table) => table.title).join(', ')}',
          bold: true,
          compact: true,
          color: _primary,
        ),
      );
    }
    final userNotes = notes.where((note) => note.stepId == step.id);
    if (userNotes.isNotEmpty) {
      content.write(_label('User Notes'));
      content.write(_notesXml(userNotes, assets));
    }

    const markerWidth = 360;
    const contentWidth = _columnWidth - markerWidth - 320;
    final timelineBorder = isLast
        ? '<w:right w:val="nil"/>'
        : '<w:right w:val="dashed" w:sz="8" w:space="0" w:color="$_outline"/>';
    return '<w:tbl><w:tblPr><w:tblW w:w="${markerWidth + contentWidth}" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/><w:tblBorders>${_nilBorders()}</w:tblBorders>'
        '<w:tblCellMar><w:top w:w="80" w:type="dxa"/><w:left w:w="0" w:type="dxa"/>'
        '<w:bottom w:w="120" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar>'
        '</w:tblPr><w:tblGrid><w:gridCol w:w="$markerWidth"/><w:gridCol w:w="$contentWidth"/></w:tblGrid>'
        '<w:tr><w:trPr><w:cantSplit/></w:trPr>'
        '<w:tc><w:tcPr><w:tcW w:w="$markerWidth" w:type="dxa"/>'
        '<w:tcBorders>$timelineBorder</w:tcBorders><w:vAlign w:val="top"/></w:tcPr>'
        '${_stepMarker(index + 1)}</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="$contentWidth" w:type="dxa"/>'
        '<w:tcMar><w:left w:w="360" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr>'
        '$content</w:tc></w:tr></w:tbl>';
  }

  String _card(String content) {
    return '<w:tbl><w:tblPr><w:tblW w:w="$_columnWidth" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/><w:tblBorders>'
        '<w:top w:val="single" w:sz="6" w:color="$_outlineVariant"/>'
        '<w:left w:val="single" w:sz="6" w:color="$_outlineVariant"/>'
        '<w:bottom w:val="single" w:sz="6" w:color="$_outlineVariant"/>'
        '<w:right w:val="single" w:sz="6" w:color="$_outlineVariant"/>'
        '<w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>'
        '<w:tblCellMar><w:top w:w="180" w:type="dxa"/><w:left w:w="180" w:type="dxa"/>'
        '<w:bottom w:w="180" w:type="dxa"/><w:right w:w="180" w:type="dxa"/></w:tblCellMar>'
        '</w:tblPr><w:tblGrid><w:gridCol w:w="$_columnWidth"/></w:tblGrid>'
        '<w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr>'
        '<w:tcW w:w="$_columnWidth" w:type="dxa"/><w:vAlign w:val="top"/></w:tcPr>'
        '$content<w:p/></w:tc></w:tr></w:tbl>'
        '<w:p><w:pPr><w:spacing w:after="120"/></w:pPr></w:p>';
  }

  String _cardTitle(String text) {
    return _paragraph(
      text,
      bold: true,
      fontSize: 24,
      compact: true,
      keepNext: true,
      color: _textPrimary,
    );
  }

  String _groupTitle(String text) {
    return _paragraph(
      text,
      bold: true,
      fontSize: 24,
      compact: true,
      keepNext: true,
      color: _primary,
    );
  }

  String _label(String text) {
    return _paragraph(
      text,
      bold: true,
      compact: true,
      keepNext: true,
      before: 100,
      color: _textPrimary,
    );
  }

  String _stepNotesLabel() {
    return _paragraph(
      'Notes',
      bold: true,
      fontSize: 18,
      compact: true,
      keepNext: true,
      before: 50,
      color: _textSecondary,
    );
  }

  String _stepMarker(int number) {
    return '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/><w:jc w:val="right"/></w:pPr>'
        '<w:r><w:pict><v:oval style="position:relative;left:9pt;width:18pt;height:18pt" '
        'fillcolor="#$_primaryContainer" strokecolor="#$_primary" strokeweight="1pt">'
        '<v:textbox inset="0,0,0,0"><w:txbxContent>'
        '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/><w:jc w:val="center"/></w:pPr>'
        '<w:r><w:rPr><w:b/><w:color w:val="$_onPrimaryContainer"/>'
        '<w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr><w:t>$number</w:t></w:r>'
        '</w:p></w:txbxContent></v:textbox></v:oval></w:pict></w:r></w:p>';
  }

  String _divider() {
    return '<w:p><w:pPr><w:spacing w:before="40" w:after="160"/>'
        '<w:pBdr><w:bottom w:val="single" w:sz="4" w:space="1" '
        'w:color="$_outlineVariant"/></w:pBdr></w:pPr></w:p>';
  }

  String _pageBreak() {
    return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
  }

  String _sectionProperties() {
    const content =
        '<w:footerReference w:type="default" r:id="rIdFooter"/>'
        '<w:pgSz w:w="$_pageWidth" w:h="$_pageHeight"/>'
        '<w:pgMar w:top="$_pageMargin" w:right="$_pageMargin" '
        'w:bottom="$_pageMargin" w:left="$_pageMargin" '
        'w:header="360" w:footer="360" w:gutter="0"/>'
        '<w:cols w:num="1" w:space="0"/>';
    return '<w:sectPr>$content</w:sectPr>';
  }

  String _nilBorders() {
    return '<w:top w:val="nil"/><w:left w:val="nil"/>'
        '<w:bottom w:val="nil"/><w:right w:val="nil"/>'
        '<w:insideH w:val="nil"/><w:insideV w:val="nil"/>';
  }

  String _valueOrFallback(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Not provided.' : trimmed;
  }

  List<ProtocolStep> _sortedProtocolSteps(Protocol protocol) {
    final indexed = protocol.steps.asMap().entries.toList()
      ..sort((a, b) {
        final dayComparison = a.value.day.compareTo(b.value.day);
        return dayComparison != 0 ? dayComparison : a.key.compareTo(b.key);
      });
    return indexed.map((entry) => entry.value).toList();
  }

  List<ProtocolTable> _tablesForIds(Protocol protocol, Iterable<String> ids) {
    final byId = {for (final table in protocol.tables) table.id: table};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  List<ProtocolTable> _orderedTables(Protocol protocol) {
    final ordered = <ProtocolTable>[];
    final added = <String>{};

    void add(ProtocolTable? table) {
      if (table != null && added.add(table.id)) ordered.add(table);
    }

    add(protocol.materialListTable);
    for (final step in _sortedProtocolSteps(protocol)) {
      for (final table in _tablesForIds(protocol, step.tableIds)) {
        add(table);
      }
    }
    for (final table in protocol.tables) {
      add(table);
    }
    return ordered;
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
    final columnCount = _tableColumnCount(table);
    final headers = <String>[
      if (hasRowHeaders) '',
      ..._normalizedHeaders(table),
    ];
    final rows = <List<String>>[];
    final colors = <List<String>>[];
    for (var rowIndex = 0; rowIndex < table.data.length; rowIndex++) {
      final row = table.data[rowIndex];
      rows.add([
        if (hasRowHeaders)
          rowIndex < table.rowHeaders.length ? table.rowHeaders[rowIndex] : '',
        ...List<String>.generate(
          columnCount,
          (index) => index < row.length ? _cellText(row[index]) : '',
        ),
      ]);
      final rowColors = rowIndex < table.cellColors.length
          ? table.cellColors[rowIndex]
          : const <String>[];
      colors.add([
        if (hasRowHeaders) '',
        ...List<String>.generate(
          columnCount,
          (index) => index < rowColors.length ? rowColors[index] : '',
        ),
      ]);
    }
    final title = _paragraph(
      table.title,
      bold: true,
      fontSize: 16,
      color: _primary,
      compact: true,
      keepNext: true,
    );
    if (table.type != TableType.plateLayout) {
      return title + _table(headers, rows, cellColors: colors);
    }

    const innerWidth = _usableWidth - 360;
    return '<w:tbl><w:tblPr><w:tblW w:w="$_usableWidth" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/><w:tblBorders>'
        '<w:top w:val="single" w:sz="6" w:color="$_outlineVariant"/>'
        '<w:left w:val="single" w:sz="6" w:color="$_outlineVariant"/>'
        '<w:bottom w:val="single" w:sz="6" w:color="$_outlineVariant"/>'
        '<w:right w:val="single" w:sz="6" w:color="$_outlineVariant"/>'
        '<w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>'
        '<w:tblCellMar><w:top w:w="180" w:type="dxa"/><w:left w:w="180" w:type="dxa"/>'
        '<w:bottom w:w="180" w:type="dxa"/><w:right w:w="180" w:type="dxa"/></w:tblCellMar>'
        '</w:tblPr><w:tblGrid><w:gridCol w:w="$_usableWidth"/></w:tblGrid>'
        '<w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr>'
        '<w:tcW w:w="$_usableWidth" w:type="dxa"/></w:tcPr>$title'
        '${_table(headers, rows, width: innerWidth, cellColors: colors)}'
        '</w:tc></w:tr></w:tbl><w:p/>';
  }

  int _tableColumnCount(ProtocolTable table) {
    return table.data.fold<int>(
      table.columnHeaders.length,
      (max, row) => row.length > max ? row.length : max,
    );
  }

  List<String> _normalizedHeaders(ProtocolTable table) {
    final count = _tableColumnCount(table);
    return List<String>.generate(
      count,
      (index) => index < table.columnHeaders.length
          ? table.columnHeaders[index]
          : _columnName(index),
    );
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

  String _table(
    List<String> headers,
    List<List<String>> rows, {
    int width = _usableWidth,
    List<List<String>> cellColors = const [],
  }) {
    final columnCount = [
      headers.length,
      ...rows.map((row) => row.length),
    ].fold<int>(0, (max, value) => value > max ? value : max);
    if (columnCount == 0) return '';
    final columnWidths = _wordTableColumnWidths(headers, rows, width);
    final grid = columnWidths
        .map((columnWidth) => '<w:gridCol w:w="$columnWidth"/>')
        .join();
    final xml = StringBuffer()
      ..write(
        '<w:tbl><w:tblPr><w:tblW w:w="$width" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/><w:tblBorders>'
        '<w:top w:val="single" w:sz="4" w:color="$_outlineVariant"/>'
        '<w:left w:val="single" w:sz="4" w:color="$_outlineVariant"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="$_outlineVariant"/>'
        '<w:right w:val="single" w:sz="4" w:color="$_outlineVariant"/>'
        '<w:insideH w:val="single" w:sz="4" w:color="$_outlineVariant"/>'
        '<w:insideV w:val="single" w:sz="4" w:color="$_outlineVariant"/>'
        '</w:tblBorders><w:tblCellMar>'
        '<w:top w:w="90" w:type="dxa"/><w:left w:w="90" w:type="dxa"/>'
        '<w:bottom w:w="90" w:type="dxa"/><w:right w:w="90" w:type="dxa"/>'
        '</w:tblCellMar></w:tblPr><w:tblGrid>$grid</w:tblGrid>',
      );
    if (headers.isNotEmpty) {
      xml.write(_tableRow(headers, columnWidths, header: true));
    }
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      xml.write(
        _tableRow(
          rows[rowIndex],
          columnWidths,
          colors: rowIndex < cellColors.length
              ? cellColors[rowIndex]
              : const <String>[],
        ),
      );
    }
    xml.write('</w:tbl><w:p/>');
    return xml.toString();
  }

  List<int> _wordTableColumnWidths(
    List<String> headers,
    List<List<String>> rows,
    int totalWidth,
  ) {
    final columnCount = [
      headers.length,
      ...rows.map((row) => row.length),
    ].fold<int>(0, (max, value) => value > max ? value : max);
    final weights = <double>[];
    for (var column = 0; column < columnCount; column++) {
      var longest = column < headers.length ? headers[column].length : 1;
      for (final row in rows) {
        if (column >= row.length) continue;
        for (final line in row[column].split('\n')) {
          if (line.length > longest) longest = line.length;
        }
      }
      weights.add(longest.clamp(4, 30).toDouble());
    }
    final weightTotal = weights.fold<double>(0, (sum, value) => sum + value);
    final widths = weights
        .map((weight) => (totalWidth * weight / weightTotal).round())
        .toList();
    final difference =
        totalWidth - widths.fold<int>(0, (sum, value) => sum + value);
    if (widths.isNotEmpty) widths[widths.length - 1] += difference;
    return widths;
  }

  String _tableRow(
    List<String> values,
    List<int> columnWidths, {
    bool header = false,
    List<String> colors = const [],
  }) {
    final xml = StringBuffer()..write('<w:tr><w:trPr><w:cantSplit/></w:trPr>');
    for (var index = 0; index < columnWidths.length; index++) {
      final value = index < values.length ? values[index] : '';
      final rawColor = index < colors.length ? colors[index] : '';
      final cellColor = _wordColor(rawColor);
      final shading = header
          ? '<w:shd w:val="clear" w:color="auto" w:fill="$_primaryContainer"/>'
          : cellColor == null
          ? ''
          : '<w:shd w:val="clear" w:color="auto" w:fill="$cellColor"/>';
      xml.write(
        '<w:tc><w:tcPr><w:tcW w:w="${columnWidths[index]}" w:type="dxa"/>'
        '$shading'
        '<w:vAlign w:val="center"/></w:tcPr>'
        '${_paragraph(value, bold: header, compact: true, fontSize: header ? 16 : 14)}'
        '</w:tc>',
      );
    }
    xml.write('</w:tr>');
    return xml.toString();
  }

  String? _wordColor(String value) {
    final cleaned = value.replaceFirst('#', '').trim().toUpperCase();
    return RegExp(r'^[0-9A-F]{6}$').hasMatch(cleaned) ? cleaned : null;
  }

  String _heading(String text, int level) {
    return _paragraph(text, style: 'Heading$level');
  }

  String _bullet(String text) {
    return '<w:p><w:pPr><w:keepLines/><w:spacing w:after="20"/>'
        '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>'
        '${_isRtl(text) ? '<w:bidi/>' : ''}</w:pPr>${_run(text)}</w:p>';
  }

  String _numbered(String text, {required int numId}) {
    return '<w:p><w:pPr><w:keepLines/><w:spacing w:after="20"/>'
        '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="$numId"/></w:numPr>'
        '${_isRtl(text) ? '<w:bidi/>' : ''}</w:pPr>${_run(text)}</w:p>';
  }

  String _paragraph(
    String text, {
    String? style,
    bool bold = false,
    bool italic = false,
    bool compact = false,
    int? fontSize,
    String? color,
    bool keepNext = false,
    bool keepLines = true,
    int before = 0,
    int? after,
    String? alignment,
  }) {
    final properties = StringBuffer();
    if (style != null) properties.write('<w:pStyle w:val="$style"/>');
    if (keepNext) properties.write('<w:keepNext/>');
    if (keepLines) properties.write('<w:keepLines/>');
    final resolvedAfter = after ?? (compact ? 0 : 100);
    properties.write(
      '<w:spacing w:before="$before" w:after="$resolvedAfter"/>',
    );
    if (alignment != null) properties.write('<w:jc w:val="$alignment"/>');
    if (_isRtl(text)) properties.write('<w:bidi/>');
    final pPr = properties.isEmpty ? '' : '<w:pPr>$properties</w:pPr>';
    return '<w:p>$pPr${_run(text, bold: bold, italic: italic, fontSize: fontSize, color: color)}</w:p>';
  }

  String _run(
    String text, {
    bool bold = false,
    bool italic = false,
    int? fontSize,
    String? color,
  }) {
    final properties = StringBuffer();
    if (bold) properties.write('<w:b/>');
    if (italic) properties.write('<w:i/>');
    if (color != null) properties.write('<w:color w:val="$color"/>');
    if (_isRtl(text)) properties.write('<w:rtl/>');
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

  String _imageParagraph(
    _DocxImage image, {
    int width = 2011680,
    int height = 1508760,
    bool centered = false,
  }) {
    return '<w:p><w:pPr><w:spacing w:before="40" w:after="40"/>'
        '${centered ? '<w:jc w:val="center"/>' : ''}</w:pPr>'
        '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
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

  bool _isRtl(String text) => RegExp(r'[\u0590-\u08FF]').hasMatch(text);

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
        '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
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
        '<Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'
        '<Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>',
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
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:color w:val="$_textPrimary"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="100" w:line="240" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
        '${_paragraphStyle('Normal', 'Normal', 20, _textPrimary, 100)}'
        '${_paragraphStyle('Title', 'Title', 28, _textPrimary, 0, bold: true, keepNext: true)}'
        '${_paragraphStyle('Subtitle', 'Subtitle', 20, _textSecondary, 120, keepNext: true)}'
        '${_paragraphStyle('Heading1', 'Heading 1', 24, _textPrimary, 80, bold: true, before: 120, keepNext: true)}'
        '${_paragraphStyle('Heading2', 'Heading 2', 24, _primary, 60, bold: true, before: 100, keepNext: true)}'
        '${_paragraphStyle('Heading3', 'Heading 3', 20, _textPrimary, 40, bold: true, before: 80, keepNext: true)}'
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

  String _numbering(Protocol protocol) {
    final stepNumbers = List<String>.generate(
      protocol.steps.length,
      (index) =>
          '<w:num w:numId="${100 + index}"><w:abstractNumId w:val="1"/>'
          '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/>'
          '</w:lvlOverride></w:num>',
    ).join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/>'
        '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/>'
        '<w:lvlText w:val="&#x2022;"/><w:lvlJc w:val="left"/>'
        '<w:pPr><w:tabs><w:tab w:val="num" w:pos="540"/></w:tabs>'
        '<w:ind w:left="540" w:hanging="270"/></w:pPr>'
        '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/></w:rPr>'
        '</w:lvl></w:abstractNum>'
        '<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="singleLevel"/>'
        '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/>'
        '<w:lvlText w:val="%1."/><w:lvlJc w:val="left"/>'
        '<w:pPr><w:tabs><w:tab w:val="num" w:pos="540"/></w:tabs>'
        '<w:ind w:left="540" w:hanging="270"/></w:pPr>'
        '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/>'
        '<w:color w:val="$_primary"/></w:rPr></w:lvl></w:abstractNum>'
        '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
        '$stepNumbers'
        '</w:numbering>';
  }

  String _footer() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="0"/></w:pPr>'
        '<w:r><w:rPr><w:color w:val="$_textSecondary"/><w:sz w:val="20"/>'
        '<w:szCs w:val="20"/></w:rPr><w:t xml:space="preserve">Page </w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:ftr>';
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
