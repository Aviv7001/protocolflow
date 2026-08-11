import 'dart:io' show File;
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/plate_wizard.dart';
import 'package:protocolflow/services/protocol_export_filename.dart';
import 'package:protocolflow/services/pdf_platform_stub.dart'
    if (dart.library.ui) 'package:protocolflow/services/pdf_platform_flutter.dart'
    as pdf_platform;

class PdfService {
  static const double _bodyFontSize = 10;
  static const double _titleFontSize = 12;
  static const double _reportTitleFontSize = 14;
  static const double _captionFontSize = 10;
  static const double _tableHeaderFontSize = 8;
  static const double _tableBodyFontSize = 6;
  static const double _pdfPageHeightPoints = 841.8898;
  static const double _pdfVerticalMarginsPoints = 52;
  static const double _pdfFooterReservePoints = 32;
  static const double _pdfPhasePageBudget =
      _pdfPageHeightPoints -
      _pdfVerticalMarginsPoints -
      _pdfFooterReservePoints;

  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF156F7A);
  static const PdfColor _primaryContainerColor = PdfColor.fromInt(0xFFD7F0F3);
  static const PdfColor _onPrimaryContainerColor = PdfColor.fromInt(0xFF0F4D54);
  static const PdfColor _outlineColor = PdfColor.fromInt(0xFFAEBCC1);
  static const PdfColor _outlineVariantColor = PdfColor.fromInt(0xFFD8E1E4);
  static const PdfColor _surfaceContainerColor = PdfColor.fromInt(0xFFEEF4F5);
  static const PdfColor _textPrimaryColor = PdfColor.fromInt(0xFF1F2933);
  static const PdfColor _textSecondaryColor = PdfColor.fromInt(0xFF61717A);

  static Future<void> exportToPdf(CompletedProtocol completed) async {
    await exportProtocolToPdf(
      completed.protocol,
      notes: completed.notes,
      completedAt: completed.completedAt,
    );
  }

  static Future<void> exportProtocolToPdf(
    Protocol protocol, {
    List<StepNote> notes = const [],
    DateTime? completedAt,
  }) async {
    final bytes = await buildProtocolPdf(
      protocol,
      notes: notes,
      completedAt: completedAt,
    );

    await pdf_platform.layoutPdf(
      bytes,
      name: completedAt == null
          ? ProtocolExportFilename.protocol(protocol, 'pdf')
          : ProtocolExportFilename.completed(protocol, completedAt, 'pdf'),
    );
  }

  static Future<Uint8List> buildProtocolPdf(
    Protocol protocol, {
    List<StepNote> notes = const [],
    DateTime? completedAt,
    pw.ThemeData? theme,
  }) async {
    final pdf = pw.Document();

    final resolvedTheme = theme ?? await pdf_platform.loadPdfTheme();
    final availableWidth = PdfPageFormat.a4.width - (26 * 2);
    final tables = _orderedTables(protocol);

    pdf.addPage(
      pw.MultiPage(
        theme: resolvedTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        build: (context) {
          return <pw.Widget>[
            _buildReportHeader(protocol, completedAt),
            pw.SizedBox(height: 12),
            for (final item in _buildFlowItems(
              protocol,
              notes,
              completedAt,
              availableWidth,
            )) ...[item, pw.SizedBox(height: 12)],
          ];
        },
        footer: _buildPageFooter,
      ),
    );

    if (tables.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          theme: resolvedTheme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(26),
          build: (context) => [
            _buildTablesHeader(),
            pw.SizedBox(height: 10),
            ..._buildTableAppendix(tables, availableWidth),
          ],
          footer: _buildPageFooter,
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page ${context.pageNumber}',
        style: const pw.TextStyle(
          fontSize: _captionFontSize,
          color: _textSecondaryColor,
        ),
      ),
    );
  }

  static pw.Widget _buildReportHeader(
    Protocol protocol,
    DateTime? completedAt,
  ) {
    final publication = protocol.publication;
    final shareUri = publication != null && publication.isPublic
        ? publication.shareUri.trim()
        : '';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _rtlText(
                    protocol.title,
                    style: pw.TextStyle(
                      fontSize: _reportTitleFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: _textPrimaryColor,
                    ),
                    isFullWidth: true,
                  ),
                ],
              ),
            ),
            if (shareUri.isNotEmpty) ...[
              pw.SizedBox(width: 14),
              _buildPublishedQr(shareUri),
            ],
          ],
        ),
        pw.Divider(thickness: 0.5, color: _outlineVariantColor),
      ],
    );
  }

  static pw.Widget _buildPublishedQr(String shareUri) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: shareUri,
          width: 54,
          height: 54,
          padding: const pw.EdgeInsets.all(3),
          backgroundColor: PdfColors.white,
          color: _primaryColor,
          drawText: false,
        ),
        pw.SizedBox(height: 2),
        pw.Text('Scan', style: const pw.TextStyle(fontSize: _bodyFontSize)),
      ],
    );
  }

  static List<pw.Widget> _buildFlowItems(
    Protocol protocol,
    List<StepNote> notes,
    DateTime? completedAt,
    double contentWidth,
  ) {
    final items = <pw.Widget>[
      _pwSectionCard('Protocol Information', [
        _pwMetaLine(completedAt == null ? 'Type: Template' : 'Type: Completed'),
        _pwMetaLine(
          'Created on: ${protocol.createdAt.toString().split(' ').first}',
        ),
        _pwMetaLine('Created by: ${protocol.createdByName ?? 'Unknown user'}'),
        if (completedAt != null)
          _pwMetaLine('Completed on: ${completedAt.toString().split('.')[0]}'),
        pw.SizedBox(height: 8),
        _pwField('Objective', protocol.objective),
        pw.SizedBox(height: 8),
        _pwField('Description', protocol.description),
        if (protocol.samples.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Samples',
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          ...protocol.samples.map((sample) => _rtlBullet(sample)),
        ],
        if (notes.any((note) => note.stepId == 'materials')) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Material Notes',
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
        ..._pwNotesForStep(notes, 'materials'),
      ]),
      ..._buildPdfSteps(protocol, notes, contentWidth),
      if (notes.any((n) => n.stepId == 'overview'))
        _pwSectionCard('General Notes', _pwNotesForStep(notes, 'overview')),
      ..._pwSupplementarySections(protocol),
    ];

    return items
        .map((item) => pw.SizedBox(width: contentWidth, child: item))
        .toList();
  }

  static pw.Widget _rtlBullet(
    String text, {
    double fontSize = _bodyFontSize,
    bool isFullWidth = true,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 4, right: 6),
          width: 3,
          height: 3,
          decoration: const pw.BoxDecoration(
            color: _textPrimaryColor,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.Expanded(
          child: _rtlText(
            text,
            style: pw.TextStyle(fontSize: fontSize),
            isFullWidth: isFullWidth,
          ),
        ),
      ],
    );
  }

  static pw.Widget _pwNumberedAction(int number, String text) {
    final isRtl = RegExp(r'[\u0590-\u08FF]').hasMatch(text);
    return pw.Directionality(
      textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 18,
              alignment: pw.Alignment.center,
              child: pw.Text(
                '$number.',
                style: pw.TextStyle(
                  fontSize: _bodyFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: _rtlText(
                text,
                style: const pw.TextStyle(fontSize: _bodyFontSize),
                isFullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<pw.Widget> _buildPdfSteps(
    Protocol protocol,
    List<StepNote> notes,
    double contentWidth,
  ) {
    if (protocol.steps.isEmpty) {
      return [
        _pwSectionCard('Steps', [_pwEmptyState('No steps added.')]),
      ];
    }

    final List<pw.Widget> widgets = <pw.Widget>[];
    final sortedSteps = _sortedProtocolSteps(protocol);

    final bool hasPhases = sortedSteps.any(
      (s) => s.phaseName != null && s.phaseName!.isNotEmpty,
    );
    final groups = <String, List<ProtocolStep>>{};
    final groupOrder = <String>[];

    if (hasPhases) {
      for (final step in sortedSteps) {
        final phase = step.phaseName ?? 'General';
        if (!groups.containsKey(phase)) {
          groupOrder.add(phase);
          groups[phase] = [];
        }
        groups[phase]!.add(step);
      }
    } else {
      for (final step in sortedSteps) {
        final day = 'Day ${step.day}';
        if (!groups.containsKey(day)) {
          groupOrder.add(day);
          groups[day] = [];
        }
        groups[day]!.add(step);
      }
    }

    var globalIndex = 0;
    for (final groupTitle in groupOrder) {
      final groupSteps = groups[groupTitle]!;
      final chunks = _splitPdfPhase(groupSteps, notes, contentWidth);
      for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunk = chunks[chunkIndex];
        widgets.add(
          _buildStepGroupCard(
            chunkIndex == 0 ? groupTitle : '$groupTitle (continued)',
            chunk,
            globalIndex,
            protocol,
            notes,
          ),
        );
        globalIndex += chunk.length;
      }
    }
    return widgets;
  }

  static List<List<ProtocolStep>> _splitPdfPhase(
    List<ProtocolStep> steps,
    List<StepNote> notes,
    double contentWidth,
  ) {
    const cardAndHeadingHeight = 42.0;
    const betweenStepsHeight = 12.0;
    final chunks = <List<ProtocolStep>>[];
    var current = <ProtocolStep>[];
    var currentHeight = cardAndHeadingHeight;

    for (final step in steps) {
      final stepHeight = _estimatePdfStepHeight(step, notes, contentWidth);
      final addedHeight =
          stepHeight + (current.isEmpty ? 0 : betweenStepsHeight);
      if (current.isNotEmpty &&
          currentHeight + addedHeight > _pdfPhasePageBudget) {
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

  static double _estimatePdfStepHeight(
    ProtocolStep step,
    List<StepNote> notes,
    double contentWidth,
  ) {
    final textWidth = (contentWidth - 76).clamp(180, contentWidth).toDouble();
    var height = 14.0;
    height += _estimatePdfTextHeight(
      'Step: ${step.title}',
      textWidth,
      _titleFontSize,
      14,
    );
    height += _estimatePdfTextHeight(
      step.instructions,
      textWidth,
      _bodyFontSize,
      12,
    );
    if (step.timerInSeconds != null) height += 14;
    if (step.materials.isNotEmpty) {
      height += _estimatePdfTextHeight(
        step.materials
            .map((material) => '${material.name} (${material.quantity})')
            .join(', '),
        textWidth,
        _bodyFontSize,
        12,
      );
    }
    for (final action in step.actionItems) {
      height +=
          _estimatePdfTextHeight(action, textWidth - 22, _bodyFontSize, 12) + 2;
    }
    if (step.notes.isNotEmpty) {
      height += 17;
      for (final note in step.notes) {
        height += _estimatePdfTextHeight(
          note,
          textWidth - 12,
          _bodyFontSize,
          12,
        );
      }
    }
    if (step.tableIds.isNotEmpty) height += 22;

    final userNotes = notes.where((note) => note.stepId == step.id).toList();
    if (userNotes.isNotEmpty) {
      height += 17;
      final photoCount = userNotes.fold<int>(
        0,
        (count, note) => count + note.photoPaths.length,
      );
      if (photoCount > 0) {
        final photosPerRow = (textWidth / 130).floor().clamp(1, 4).toInt();
        height += ((photoCount + photosPerRow - 1) ~/ photosPerRow) * 130;
      }
      for (final note in userNotes) {
        height += _estimatePdfTextHeight(note.note, textWidth, 11, 13);
      }
    }
    return height + 12;
  }

  static double _estimatePdfTextHeight(
    String text,
    double width,
    double fontSize,
    double lineHeight,
  ) {
    if (text.trim().isEmpty) return 0;
    final averageCharacterWidth = fontSize * 0.52;
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

  static pw.Widget _buildStepGroupCard(
    String title,
    List<ProtocolStep> steps,
    int startIndex,
    Protocol protocol,
    List<StepNote> notes,
  ) {
    return _pwFlowCard(
      children: [
        _pwGroupHeading(title),
        for (var index = 0; index < steps.length; index++) ...[
          _buildTimelineStepWidget(
            steps[index],
            startIndex + index,
            protocol,
            notes,
            isFirst: index == 0,
            isLast: index == steps.length - 1,
          ),
          if (index < steps.length - 1) pw.SizedBox(height: 12),
        ],
      ],
    );
  }

  static pw.Widget _buildTimelineStepWidget(
    ProtocolStep step,
    int index,
    Protocol protocol,
    List<StepNote> notes, {
    required bool isFirst,
    required bool isLast,
  }) {
    return pw.Stack(
      overflow: pw.Overflow.visible,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [_buildStepWidget(step, index, protocol, notes)],
          ),
        ),
        pw.Positioned(
          left: 8.5,
          top: isFirst ? 9 : -12,
          bottom: isLast ? null : -12,
          child: pw.Container(
            width: 1,
            height: isLast ? (isFirst ? 1 : 21) : null,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(
                  color: _outlineColor,
                  width: 1,
                  style: pw.BorderStyle.dashed,
                ),
              ),
            ),
          ),
        ),
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Container(
            width: 18,
            height: 18,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _primaryContainerColor,
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: _primaryColor, width: 1),
            ),
            child: pw.Text(
              '${index + 1}',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                fontWeight: pw.FontWeight.bold,
                color: _onPrimaryContainerColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _pwGroupHeading(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: _titleFontSize,
          color: _primaryColor,
        ),
      ),
    );
  }

  static pw.Widget _buildStepWidget(
    ProtocolStep step,
    int index,
    Protocol protocol,
    List<StepNote> notes,
  ) {
    final stepNotes = notes.where((n) => n.stepId == step.id).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: _rtlText(
            'Step ${index + 1}: ${step.title}',
            style: pw.TextStyle(
              fontSize: _titleFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
            isFullWidth: true,
          ),
        ),
        _rtlText(
          step.instructions,
          style: const pw.TextStyle(fontSize: _bodyFontSize),
          isFullWidth: true,
        ),
        if (step.timerInSeconds != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Timer: ${_formatSeconds(step.timerInSeconds!)}',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        if (step.materials.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: _rtlText(
              'Step Materials: ${step.materials.map((m) => "${m.name} (${m.quantity})").join(", ")}',
              style: const pw.TextStyle(fontSize: _bodyFontSize),
              isFullWidth: true,
            ),
          ),
        if (step.actionItems.isNotEmpty)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              ...step.actionItems.asMap().entries.map((entry) {
                final aIdx = entry.key;
                final item = entry.value;
                final timer = step.actionTimers[aIdx];
                String timerStr = '';
                if (timer != null) {
                  timerStr = ' (${_formatSeconds(timer)})';
                }
                return _pwNumberedAction(aIdx + 1, '$item$timerStr');
              }),
            ],
          ),
        if (step.notes.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 5),
          pw.Text(
            'Protocol Step Notes:',
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          ...step.notes.map(
            (note) =>
                _rtlBullet(note, fontSize: _bodyFontSize, isFullWidth: false),
          ),
        ],
        if (step.tableIds.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 8),
          _pwTableMention(_tablesForIds(protocol, step.tableIds)),
        ],
        if (stepNotes.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 5),
          pw.Text(
            'User Notes:',
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          ..._pwNotes(stepNotes),
        ],
        pw.Divider(thickness: 0.5, color: _outlineVariantColor),
      ],
    );
  }

  static String _formatSeconds(int seconds) {
    if (seconds >= 3600) {
      return '${seconds ~/ 3600}h';
    } else if (seconds >= 60) {
      return '${seconds ~/ 60}m';
    } else {
      return '${seconds}s';
    }
  }

  static pw.Widget _rtlText(
    String text, {
    pw.TextStyle? style,
    bool isFullWidth = true,
  }) {
    final isRtl = RegExp(r'[\u0590-\u08FF]').hasMatch(text);
    return pw.Directionality(
      textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Container(
        width: isFullWidth ? double.infinity : null,
        alignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: style,
          textAlign: isRtl ? pw.TextAlign.right : pw.TextAlign.left,
          softWrap: true,
        ),
      ),
    );
  }

  static pw.Widget _pwSectionCard(String title, List<pw.Widget> children) {
    return _pwFlowCard(title: title, children: children);
  }

  static pw.Widget _pwFlowCard({
    String? title,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _outlineVariantColor, width: 0.5),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: _titleFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _pwMetaLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: _bodyFontSize,
          color: _textSecondaryColor,
        ),
        softWrap: true,
      ),
    );
  }

  static pw.Widget _pwField(String title, String content) {
    final value = content.trim().isEmpty ? 'Not provided.' : content.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        _rtlText(
          value,
          style: const pw.TextStyle(fontSize: _bodyFontSize),
          isFullWidth: true,
        ),
      ],
    );
  }

  static pw.Widget _pwEmptyState(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: _surfaceContainerColor,
        border: pw.Border.all(color: _outlineVariantColor, width: 0.5),
      ),
      child: pw.Text(
        message,
        style: const pw.TextStyle(
          fontSize: _bodyFontSize,
          color: _textSecondaryColor,
        ),
      ),
    );
  }

  static List<pw.Widget> _pwNotesForStep(List<StepNote> notes, String stepId) {
    return _pwNotes(notes.where((n) => n.stepId == stepId).toList());
  }

  static List<pw.Widget> _pwNotes(List<StepNote> notes) {
    if (notes.isEmpty) return <pw.Widget>[];

    final List<pw.Widget> widgets = <pw.Widget>[];

    final List<pw.Widget> photoWidgets = <pw.Widget>[];
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      for (int j = 0; j < note.photoPaths.length; j++) {
        if (pdf_platform.isWeb) continue;
        final path = note.photoPaths[j];
        final file = File(path);
        if (file.existsSync()) {
          try {
            final image = pw.MemoryImage(file.readAsBytesSync());
            photoWidgets.add(
              pw.Stack(
                children: <pw.Widget>[
                  pw.Container(
                    width: 120,
                    height: 120,
                    child: pw.Image(image, fit: pw.BoxFit.cover),
                  ),
                  pw.Positioned(
                    top: 4,
                    left: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const pw.BoxDecoration(
                        color: _primaryColor,
                        borderRadius: pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Text(
                        '${i + 1}.${j + 1}',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: _bodyFontSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } catch (e) {
            // ignore
          }
        }
      }
    }

    if (photoWidgets.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 8),
          child: pw.Wrap(spacing: 10, runSpacing: 10, children: photoWidgets),
        ),
      );
    }

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (note.note.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Container(
                  width: 12,
                  height: 12,
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(
                    color: _primaryColor,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Text(
                    '${i + 1}',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: _bodyFontSize,
                    ),
                  ),
                ),
                pw.SizedBox(width: 5),
                pw.Expanded(
                  child: _rtlText(
                    note.note,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    isFullWidth: true,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    widgets.add(pw.SizedBox(height: 8));
    return widgets;
  }

  static pw.Widget _pwTableMention(List<ProtocolTable> tables) {
    if (tables.isEmpty) {
      return _pwEmptyState('Referenced table not found.');
    }
    return _rtlText(
      'Tables: ${tables.map((table) => table.title).join(', ')}',
      style: pw.TextStyle(
        fontSize: _bodyFontSize,
        fontWeight: pw.FontWeight.bold,
        color: _primaryColor,
      ),
      isFullWidth: true,
    );
  }

  static List<ProtocolTable> _tablesForIds(
    Protocol protocol,
    Iterable<String> tableIds,
  ) {
    final tablesById = {for (final table in protocol.tables) table.id: table};
    return [
      for (final id in tableIds)
        if (tablesById[id] != null) tablesById[id]!,
    ];
  }

  static List<ProtocolTable> _orderedTables(Protocol protocol) {
    final ordered = <ProtocolTable>[];
    final addedIds = <String>{};

    void addTable(ProtocolTable? table) {
      if (table != null && addedIds.add(table.id)) ordered.add(table);
    }

    addTable(protocol.materialListTable);
    final sortedSteps = _sortedProtocolSteps(protocol);
    for (final step in sortedSteps) {
      for (final table in _tablesForIds(protocol, step.tableIds)) {
        addTable(table);
      }
    }
    for (final table in protocol.tables) {
      addTable(table);
    }
    return ordered;
  }

  static List<ProtocolStep> _sortedProtocolSteps(Protocol protocol) {
    final indexedSteps = protocol.steps.asMap().entries.toList()
      ..sort((a, b) {
        final dayComparison = a.value.day.compareTo(b.value.day);
        return dayComparison != 0 ? dayComparison : a.key.compareTo(b.key);
      });
    return indexedSteps.map((entry) => entry.value).toList();
  }

  static pw.Widget _buildTablesHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Tables',
          style: pw.TextStyle(
            fontSize: _titleFontSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(thickness: 0.5, color: _outlineVariantColor),
      ],
    );
  }

  static List<pw.Widget> _buildTableAppendix(
    List<ProtocolTable> tables,
    double availableWidth,
  ) {
    final widgets = <pw.Widget>[];
    for (final table in tables) {
      if (table.type == TableType.plateLayout || table.data.isEmpty) {
        widgets.add(_pwTable(table, maxWidth: availableWidth));
        widgets.add(pw.SizedBox(height: 14));
        continue;
      }

      final columnCount = _tableColumnCount(table);
      final rowsPerChunk = columnCount >= 8 ? 18 : (columnCount >= 5 ? 24 : 30);
      for (
        var startRow = 0;
        startRow < table.data.length;
        startRow += rowsPerChunk
      ) {
        final endRow = (startRow + rowsPerChunk).clamp(0, table.data.length);
        widgets.add(
          _pwTable(
            table,
            maxWidth: availableWidth,
            startRow: startRow,
            endRow: endRow,
            titleOverride: startRow == 0 ? null : '${table.title} (continued)',
          ),
        );
        widgets.add(pw.SizedBox(height: 14));
      }
    }
    return widgets;
  }

  static pw.Widget _pwTable(
    ProtocolTable table, {
    double? maxWidth,
    int startRow = 0,
    int? endRow,
    String? titleOverride,
  }) {
    if (table.type == TableType.plateLayout) {
      return _pwPlateLayout(table);
    }
    final hasRowHeaders = table.rowHeaders.isNotEmpty;
    final columnCount = _tableColumnCount(table);
    final columnHeaders = _normalizedHeaders(table);
    final columnWidths = _tableColumnWidths(table, hasRowHeaders);
    final firstRow = startRow.clamp(0, table.data.length);
    final lastRow = (endRow ?? table.data.length).clamp(
      firstRow,
      table.data.length,
    );

    return pw.SizedBox(
      width: maxWidth,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              titleOverride ?? table.title,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: _tableHeaderFontSize,
                color: _primaryColor,
              ),
              softWrap: true,
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: _outlineVariantColor, width: 0.5),
            columnWidths: columnWidths,
            children: <pw.TableRow>[
              pw.TableRow(
                children: <pw.Widget>[
                  if (hasRowHeaders)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        '',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: _tableHeaderFontSize,
                        ),
                      ),
                    ),
                  ...columnHeaders.map(
                    (h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: _tableHeaderFontSize,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ),
                ],
              ),
              ...List<pw.TableRow>.generate(lastRow - firstRow, (rowOffset) {
                final rowIndex = firstRow + rowOffset;
                final rowColors = rowIndex < table.cellColors.length
                    ? table.cellColors[rowIndex]
                    : <String>[];
                return pw.TableRow(
                  children: <pw.Widget>[
                    if (hasRowHeaders)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          rowIndex < table.rowHeaders.length
                              ? table.rowHeaders[rowIndex]
                              : (rowIndex + 1).toString(),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: _tableBodyFontSize,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ...List<pw.Widget>.generate(columnCount, (colIndex) {
                      final row = table.data[rowIndex];
                      final cell = colIndex < row.length ? row[colIndex] : '';
                      final colorHex = colIndex < rowColors.length
                          ? rowColors[colIndex]
                          : '';
                      PdfColor? bgColor;
                      if (colorHex.isNotEmpty) {
                        try {
                          final hex = colorHex.replaceFirst('#', '');
                          bgColor = PdfColor.fromInt(
                            int.parse('FF$hex', radix: 16),
                          );
                        } catch (_) {}
                      }

                      String text = cell.toString();
                      if (cell is bool) {
                        text = cell ? '[X]' : '[ ]';
                      }
                      return pw.Container(
                        color: bgColor,
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          text,
                          style: const pw.TextStyle(
                            fontSize: _tableBodyFontSize,
                          ),
                          softWrap: true,
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _pwPlateLayout(ProtocolTable table) {
    final wizardState = table.metadata['wizard_state'];
    if (wizardState != null) {
      try {
        final wizard = PlateLayoutWizard.fromJson(jsonDecode(wizardState));
        final tables = wizard.generateTables();

        if (tables.length > 1) {
          return pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tables.map((t) => _buildSinglePlatePdf(t)).toList(),
          );
        } else if (tables.isNotEmpty) {
          return _buildSinglePlatePdf(tables.first);
        }
      } catch (e) {
        // Fallback to single plate if decoding fails
      }
    }
    return _buildSinglePlatePdf(table);
  }

  static pw.Widget _buildSinglePlatePdf(ProtocolTable table) {
    final int rows = int.tryParse(table.metadata['rows'] ?? '8') ?? 8;
    final int cols = int.tryParse(table.metadata['columns'] ?? '12') ?? 12;
    const double wellSize = 17.5; // Adjusted for side-by-side support
    final double plateWidth = (cols * (wellSize + 1)) + 28;

    return pw.Container(
      width: plateWidth,
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _outlineVariantColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Text(
              table.title,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: _tableHeaderFontSize,
                color: _primaryColor,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: pw.Column(
              children: [
                // Col headers
                pw.Row(
                  children: [
                    pw.SizedBox(width: 12),
                    ...List.generate(
                      cols,
                      (i) => pw.Container(
                        width: wellSize + 1,
                        child: pw.Center(
                          child: pw.Text(
                            '${i + 1}',
                            style: const pw.TextStyle(
                              fontSize: _tableBodyFontSize,
                              color: _textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                ...List.generate(rows, (rIdx) {
                  return pw.Row(
                    children: [
                      pw.Container(
                        width: 12,
                        child: pw.Text(
                          String.fromCharCode(65 + rIdx),
                          style: const pw.TextStyle(
                            fontSize: _tableBodyFontSize,
                            color: _textSecondaryColor,
                          ),
                        ),
                      ),
                      ...List.generate(cols, (cIdx) {
                        final content = _tableCell(table, rIdx, cIdx);
                        final colorHex = _tableColor(table, rIdx, cIdx);
                        PdfColor bgColor = _surfaceContainerColor;
                        if (colorHex.isNotEmpty) {
                          try {
                            final hex = colorHex.replaceFirst('#', '');
                            bgColor = PdfColor.fromInt(
                              int.parse('FF$hex', radix: 16),
                            );
                          } catch (_) {}
                        }

                        final parts = content.split('\n');
                        final String name = parts.isNotEmpty ? parts[0] : '';
                        final String cond = parts.length > 1 ? parts[1] : '';
                        final String dil = parts.length > 2 ? parts[2] : '';

                        return pw.Container(
                          width: wellSize,
                          height: wellSize,
                          margin: const pw.EdgeInsets.all(0.5),
                          decoration: pw.BoxDecoration(
                            color: bgColor,
                            shape: pw.BoxShape.circle,
                            border: pw.Border.all(
                              color: _outlineVariantColor,
                              width: 0.5,
                            ),
                          ),
                          child: content.isEmpty
                              ? null
                              : pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
                                  children: [
                                    if (cond.isNotEmpty)
                                      pw.Text(
                                        cond,
                                        style: pw.TextStyle(
                                          fontSize: 3.5,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                      ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      child: pw.Text(
                                        name,
                                        style: pw.TextStyle(
                                          fontSize: 4,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ),
                                    if (dil.isNotEmpty)
                                      pw.Text(
                                        dil,
                                        style: const pw.TextStyle(
                                          fontSize: 3.5,
                                        ),
                                        maxLines: 1,
                                      ),
                                  ],
                                ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _pwSupplementarySections(Protocol protocol) {
    if (protocol.files.isEmpty && protocol.additionalData.isEmpty) {
      return <pw.Widget>[];
    }

    return <pw.Widget>[
      if (protocol.files.isNotEmpty || protocol.additionalData.isNotEmpty)
        _pwSectionCard('Additional Data', [
          if (protocol.files.isNotEmpty) ...[
            pw.Text(
              'Attached Files',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            ...protocol.files.map(
              (file) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  '- $file',
                  style: const pw.TextStyle(fontSize: _bodyFontSize),
                  softWrap: true,
                ),
              ),
            ),
          ],
          if (protocol.additionalData.isNotEmpty) ...[
            if (protocol.files.isNotEmpty) pw.SizedBox(height: 8),
            ...protocol.additionalData.map(_pwAdditionalData),
          ],
        ]),
    ];
  }

  static pw.Widget _pwAdditionalData(ProtocolAdditionalData data) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            data.title,
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
            softWrap: true,
          ),
          if (data.description.toString().trim().isNotEmpty)
            _rtlText(
              data.description,
              style: const pw.TextStyle(fontSize: _bodyFontSize),
              isFullWidth: true,
            ),
          if (data.link.toString().trim().isNotEmpty)
            pw.Text(
              data.link,
              style: const pw.TextStyle(
                fontSize: _bodyFontSize,
                color: _primaryColor,
              ),
              softWrap: true,
            ),
          if (data.photoPaths.isNotEmpty)
            pw.Text(
              '${data.photoPaths.length} photo(s) attached',
              style: const pw.TextStyle(
                fontSize: _bodyFontSize,
                color: _textSecondaryColor,
              ),
            ),
        ],
      ),
    );
  }

  static int _tableColumnCount(ProtocolTable table) {
    return table.data.fold<int>(
      table.columnHeaders.length,
      (max, row) => row.length > max ? row.length : max,
    );
  }

  static List<String> _normalizedHeaders(ProtocolTable table) {
    final count = _tableColumnCount(table);
    return List<String>.generate(
      count,
      (index) => index < table.columnHeaders.length
          ? table.columnHeaders[index]
          : _columnName(index),
    );
  }

  static Map<int, pw.TableColumnWidth> _tableColumnWidths(
    ProtocolTable table,
    bool hasRowHeaders,
  ) {
    final widths = <int, pw.TableColumnWidth>{};
    var tableIndex = 0;
    if (hasRowHeaders) {
      widths[tableIndex++] = const pw.FlexColumnWidth(0.8);
    }

    final headers = _normalizedHeaders(table);
    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      var longest = headers[columnIndex].length;
      for (final row in table.data) {
        if (columnIndex >= row.length) continue;
        final text = row[columnIndex]?.toString() ?? '';
        for (final line in text.split('\n')) {
          if (line.length > longest) longest = line.length;
        }
      }
      final weight = (longest / 12).clamp(0.9, 2.8).toDouble();
      widths[tableIndex++] = pw.FlexColumnWidth(weight);
    }
    return widths;
  }

  static String _tableCell(ProtocolTable table, int row, int col) {
    if (row < 0 ||
        col < 0 ||
        row >= table.data.length ||
        col >= table.data[row].length) {
      return '';
    }
    return table.data[row][col]?.toString() ?? '';
  }

  static String _tableColor(ProtocolTable table, int row, int col) {
    if (row < 0 ||
        col < 0 ||
        row >= table.cellColors.length ||
        col >= table.cellColors[row].length) {
      return '';
    }
    return table.cellColors[row][col];
  }

  static String _columnName(int index) {
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
