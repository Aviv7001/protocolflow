import 'dart:io' show File;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/plate_wizard.dart';

class PdfService {
  static Future<void> exportToPdf(CompletedProtocol completed) async {
    await exportProtocolToPdf(
      completed.protocol,
      notes: completed.notes,
      completedAt: completed.completedAt,
    );
  }

  static Future<void> exportProtocolToPdf(Protocol protocol, {List<StepNote> notes = const [], DateTime? completedAt}) async {
    final pdf = pw.Document();
    
    final font = await PdfGoogleFonts.arimoRegular();
    final boldFont = await PdfGoogleFonts.arimoBold();
    final italicFont = await PdfGoogleFonts.arimoItalic();

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: boldFont,
      italic: italicFont,
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return <pw.Widget>[
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: <pw.Widget>[
                      pw.Text(completedAt != null ? 'Protocol Run Report' : 'Protocol Template', style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                      if (completedAt != null)
                        pw.Text(completedAt.toString().split('.')[0], style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                _rtlText(protocol.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold), isFullWidth: true),
                pw.SizedBox(height: 20),
                
                _pwSection('Objective', protocol.objective),
                _pwSection('Description', protocol.description),

                pw.Header(level: 1, text: 'Material List'),
                if (protocol.materials.isEmpty)
                  pw.Text('No materials listed.')
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    children: <pw.TableRow>[
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: <pw.Widget>[
                          ...['Name', 'Quantity', 'Catalog #', 'Manufacturer', 'Location', 'Stock Conc.'].map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          )),
                        ],
                      ),
                      ...protocol.materials.map((m) => pw.TableRow(
                        children: <pw.Widget>[
                          ...[m.name, m.quantity, m.catalogNumber, m.manufacturer, m.location, m.stockConcentration].map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8)),
                          )),
                        ],
                      )),
                    ],
                  ),
                
                ..._pwNotesForStep(notes, 'materials'),

                pw.SizedBox(height: 20),
                pw.Header(level: 1, text: 'Steps'),
                ..._buildPdfSteps(protocol, notes),

                if (notes.any((n) => n.stepId == 'overview')) ...<pw.Widget>[
                  pw.Header(level: 1, text: 'General Notes'),
                  ..._pwNotesForStep(notes, 'overview'),
                ],

                ..._pwSupplementarySection(protocol),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${protocol.title.replaceAll(' ', '_')}${completedAt != null ? '_${completedAt.millisecondsSinceEpoch}' : ''}.pdf',
      format: PdfPageFormat.a4,
    );
  }

  static pw.Widget _rtlBullet(String text, {double fontSize = 12, bool isFullWidth = true}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 4, right: 6),
          width: 3,
          height: 3,
          decoration: const pw.BoxDecoration(
            color: PdfColors.black,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.Expanded(
          child: _rtlText(text, style: pw.TextStyle(fontSize: fontSize), isFullWidth: isFullWidth),
        ),
      ],
    );
  }

  static List<pw.Widget> _buildPdfSteps(Protocol protocol, List<StepNote> notes) {
    final List<pw.Widget> widgets = <pw.Widget>[];
    final List<ProtocolStep> sortedSteps = List<ProtocolStep>.from(protocol.steps)
      ..sort((a, b) => a.day.compareTo(b.day));

    final bool hasPhases = sortedSteps.any((s) => s.phaseName != null && s.phaseName!.isNotEmpty);

    if (hasPhases) {
      final Map<String, List<ProtocolStep>> phases = {};
      final List<String> phaseOrder = [];
      for (var step in sortedSteps) {
        final phase = step.phaseName ?? 'General';
        if (!phases.containsKey(phase)) {
          phaseOrder.add(phase);
          phases[phase] = [];
        }
        phases[phase]!.add(step);
      }

      int globalIdx = 0;
      for (var phase in phaseOrder) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(phase, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue)),
        ));
        for (var step in phases[phase]!) {
          widgets.add(_buildStepWidget(step, globalIdx++, protocol, notes));
        }
      }
    } else {
      final Map<int, List<ProtocolStep>> days = {};
      for (var step in sortedSteps) {
        days.putIfAbsent(step.day, () => <ProtocolStep>[]).add(step);
      }
      final sortedDays = days.keys.toList()..sort();

      int globalIdx = 0;
      for (var day in sortedDays) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text('Day $day', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue)),
        ));
        for (var step in days[day]!) {
          widgets.add(_buildStepWidget(step, globalIdx++, protocol, notes));
        }
      }
    }
    return widgets;
  }

  static pw.Widget _buildStepWidget(ProtocolStep step, int index, Protocol protocol, List<StepNote> notes) {
    final stepNotes = notes.where((n) => n.stepId == step.id).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: _rtlText('Step ${index + 1}: ${step.title}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), isFullWidth: true),
        ),
        _rtlText(step.instructions, style: const pw.TextStyle(fontSize: 12), isFullWidth: true),
        if (step.timerInSeconds != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text('Timer: ${_formatSeconds(step.timerInSeconds!)}',
                style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
          ),
        if (step.materials.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: _rtlText(
                'Step Materials: ${step.materials.map((m) => "${m.name} (${m.quantity})").join(", ")}',
                style: const pw.TextStyle(fontSize: 11), isFullWidth: true),
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
                return _rtlBullet('$item$timerStr', fontSize: 11, isFullWidth: false);
              }),
            ],
          ),
        if (step.tableIds.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: step.tableIds.map((id) {
              final table = protocol.tables.firstWhere(
                (t) => t.id == id,
                orElse: () => ProtocolTable(id: 'err', title: 'Table Not Found'),
              );
              if (table.id == 'err') return pw.SizedBox.shrink();
              return _pwTable(table);
            }).toList(),
          ),
        ],
        if (stepNotes.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 5),
          pw.Text('Notes:',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
          ..._pwNotes(stepNotes),
        ],
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
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

  static pw.Widget _rtlText(String text, {pw.TextStyle? style, bool isFullWidth = true}) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        width: isFullWidth ? double.infinity : null,
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: style,
          textAlign: pw.TextAlign.left,
        ),
      ),
    );
  }

  static pw.Widget _pwSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        _rtlText(content, style: const pw.TextStyle(fontSize: 12), isFullWidth: true),
        pw.SizedBox(height: 16),
      ],
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
        if (kIsWeb) continue;
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
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        '${i + 1}.${j + 1}',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 7,
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
          child: pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: photoWidgets,
          ),
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
                    color: PdfColors.blue,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Text(
                    '${i + 1}',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 7,
                    ),
                  ),
                ),
                pw.SizedBox(width: 5),
                pw.Expanded(
                  child: _rtlText(note.note,
                      style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic), isFullWidth: true),
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

  static pw.Widget _pwTable(ProtocolTable table) {
    if (table.type == TableType.plateLayout) {
      return _pwPlateLayout(table);
    }

    return pw.Container(
      width: 250, // Default width for standard tables
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(table.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue900)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                  children: <pw.Widget>[
                    if (table.rowHeaders.isNotEmpty)
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    ...table.columnHeaders.map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(h,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      ),
                    ),
                  ],
                ),
                ...List<pw.TableRow>.generate(table.data.length, (rowIndex) {
                  final rowColors =
                      rowIndex < table.cellColors.length ? table.cellColors[rowIndex] : <String>[];
                  return pw.TableRow(
                    children: <pw.Widget>[
                      if (table.rowHeaders.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(table.rowHeaders[rowIndex],
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                      ...List<pw.Widget>.generate(table.data[rowIndex].length, (colIndex) {
                        final cell = table.data[rowIndex][colIndex];
                        final colorHex = colIndex < rowColors.length ? rowColors[colIndex] : '';
                        PdfColor? bgColor;
                        if (colorHex.isNotEmpty) {
                          try {
                            final hex = colorHex.replaceFirst('#', '');
                            bgColor = PdfColor.fromInt(int.parse('FF$hex', radix: 16));
                          } catch (_) {}
                        }

                        String text = cell.toString();
                        if (cell is bool) {
                          text = cell ? '[X]' : '[ ]';
                        }
                        return pw.Container(
                          color: bgColor,
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
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
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(table.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.green900)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: pw.Column(
              children: [
                // Col headers
                pw.Row(
                  children: [
                    pw.SizedBox(width: 12),
                    ...List.generate(cols, (i) => pw.Container(
                      width: wellSize + 1,
                      child: pw.Center(child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600))),
                    )),
                  ],
                ),
                pw.SizedBox(height: 4),
                ...List.generate(rows, (rIdx) {
                  return pw.Row(
                    children: [
                      pw.Container(
                        width: 12,
                        child: pw.Text(String.fromCharCode(65 + rIdx), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                      ),
                      ...List.generate(cols, (cIdx) {
                        final content = table.data[rIdx][cIdx].toString();
                        final colorHex = table.cellColors[rIdx][cIdx];
                        PdfColor bgColor = PdfColors.grey100;
                        if (colorHex.isNotEmpty) {
                          try {
                            final hex = colorHex.replaceFirst('#', '');
                            bgColor = PdfColor.fromInt(int.parse('FF$hex', radix: 16));
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
                            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                          ),
                          child: content.isEmpty ? null : pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              if (cond.isNotEmpty)
                                pw.Text(cond, style: pw.TextStyle(fontSize: 3.5, fontWeight: pw.FontWeight.bold), maxLines: 1),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                                child: pw.Text(name, style: pw.TextStyle(fontSize: 4, fontWeight: pw.FontWeight.bold), maxLines: 1, textAlign: pw.TextAlign.center),
                              ),
                              if (dil.isNotEmpty)
                                pw.Text(dil, style: const pw.TextStyle(fontSize: 3.5), maxLines: 1),
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

  static List<pw.Widget> _pwSupplementarySection(Protocol protocol) {
    final assignedTableIds = protocol.steps.expand((s) => s.tableIds).toSet();
    final unassignedTables = protocol.tables.where((t) => !assignedTableIds.contains(t.id)).toList();

    if (protocol.files.isEmpty && unassignedTables.isEmpty) return <pw.Widget>[];

    return <pw.Widget>[
      pw.SizedBox(height: 20),
      pw.Header(level: 1, text: 'Supplementary'),
      if (protocol.files.isNotEmpty) ...<pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('Attached Files:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.grey700)),
        ),
        ...protocol.files.map((file) => pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
          child: pw.Text('- $file', style: const pw.TextStyle(fontSize: 11)),
        )),
        pw.SizedBox(height: 12),
      ],
      if (unassignedTables.isNotEmpty) ...<pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('Reference Tables:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.grey700)),
        ),
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: unassignedTables.map((table) => _pwTable(table)).toList(),
        ),
      ],
    ];
  }
}
