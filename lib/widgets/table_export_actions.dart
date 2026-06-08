import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/protocol_table.dart';
import '../services/json_file_saver.dart';
import '../services/table_export_service.dart';

class TableExportActions extends StatefulWidget {
  final ProtocolTable table;
  final Widget child;
  final bool includeRowHeaders;

  const TableExportActions({
    super.key,
    required this.table,
    required this.child,
    this.includeRowHeaders = false,
  });

  @override
  State<TableExportActions> createState() => _TableExportActionsState();
}

class _TableExportActionsState extends State<TableExportActions> {
  final _exportService = const TableExportService();
  bool _isSavingImage = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _copyTable,
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Copy table'),
            ),
            OutlinedButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.grid_on, size: 18),
              label: const Text('Export Excel'),
            ),
            OutlinedButton.icon(
              onPressed: _isSavingImage ? null : _saveAsImage,
              icon: _isSavingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined, size: 18),
              label: const Text('Save image'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        widget.child,
      ],
    );
  }

  Future<void> _copyTable() async {
    await _exportService.copyToClipboard(
      widget.table,
      includeRowHeaders: widget.includeRowHeaders,
    );
    _showSnack('Table copied to clipboard');
  }

  Future<void> _exportToExcel() async {
    await _exportService.exportToExcel(
      widget.table,
      includeRowHeaders: widget.includeRowHeaders,
    );
    _showSnack('Excel export ready');
  }

  Future<void> _saveAsImage() async {
    setState(() => _isSavingImage = true);
    try {
      final bytes = widget.table.type == TableType.plateLayout
          ? await _renderPlatePng()
          : await _renderTablePng();
      await saveBinaryFile(
        bytes,
        '${_safeFileName(widget.table.title)}.png',
        mimeType: 'image/png',
      );
      _showSnack('Image downloaded');
    } finally {
      if (mounted) setState(() => _isSavingImage = false);
    }
  }

  Future<Uint8List> _renderPlatePng() async {
    final rows =
        int.tryParse(widget.table.metadata['rows'] ?? '') ??
        widget.table.data.length;
    final columns =
        int.tryParse(widget.table.metadata['columns'] ?? '') ??
        (widget.table.data.isEmpty ? 0 : widget.table.data.first.length);
    const padding = 24.0;
    const titleHeight = 40.0;
    const headerHeight = 28.0;
    const rowHeaderWidth = 42.0;
    const wellStep = 70.0;
    const wellSize = 62.0;
    final width = padding * 2 + rowHeaderWidth + columns * wellStep;
    final height = padding * 2 + titleHeight + headerHeight + rows * wellStep;

    return _recordPng(width, height, (canvas) {
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);

      _drawText(
        canvas,
        widget.table.title.isEmpty ? 'Plate Layout' : widget.table.title,
        Offset(padding, padding),
        maxWidth: width - padding * 2,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      );

      final originY = padding + titleHeight + headerHeight;
      final originX = padding + rowHeaderWidth;
      for (var col = 0; col < columns; col++) {
        _drawText(
          canvas,
          '${col + 1}',
          Offset(originX + col * wellStep, padding + titleHeight),
          maxWidth: wellStep,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        );
      }

      for (var row = 0; row < rows; row++) {
        _drawText(
          canvas,
          row < widget.table.rowHeaders.length
              ? widget.table.rowHeaders[row]
              : String.fromCharCode(65 + row),
          Offset(padding, originY + row * wellStep + 22),
          maxWidth: rowHeaderWidth,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        );

        for (var col = 0; col < columns; col++) {
          final content = _tableCell(row, col);
          final colorHex = _tableColor(row, col);
          final center = Offset(
            originX + col * wellStep + wellStep / 2,
            originY + row * wellStep + wellStep / 2,
          );
          final fill = colorHex.isEmpty
              ? Colors.grey.shade50
              : _parseHexColor(colorHex).withValues(alpha: 0.85);
          canvas.drawCircle(center, wellSize / 2, Paint()..color = fill);
          canvas.drawCircle(
            center,
            wellSize / 2,
            Paint()
              ..color = content.isEmpty
                  ? Colors.grey.shade200
                  : Colors.grey.shade500
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          if (content.isNotEmpty) {
            final parts = content.split('\n');
            final lines = [
              if (parts.length > 1 && parts[1].isNotEmpty) parts[1],
              parts.first,
              if (parts.length > 2 && parts[2].isNotEmpty) parts[2],
            ];
            final lineHeight = 12.0;
            final startY = center.dy - (lines.length * lineHeight) / 2;
            for (var i = 0; i < lines.length; i++) {
              _drawText(
                canvas,
                lines[i],
                Offset(center.dx - wellSize / 2 + 5, startY + i * lineHeight),
                maxWidth: wellSize - 10,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: i == 0 && lines.length > 1
                      ? Colors.blue.shade900
                      : Colors.black87,
                  fontSize: i == 1 || lines.length == 1 ? 9 : 8,
                  fontWeight: FontWeight.bold,
                ),
              );
            }
          }
        }
      }
    });
  }

  Future<Uint8List> _renderTablePng() async {
    final rows = <List<String>>[
      _headers(),
      ...widget.table.data.asMap().entries.map((entry) {
        final values = entry.value
            .map((value) => value?.toString() ?? '')
            .toList();
        if (!widget.includeRowHeaders) return values;
        final rowHeader = entry.key < widget.table.rowHeaders.length
            ? widget.table.rowHeaders[entry.key]
            : (entry.key + 1).toString();
        return [rowHeader, ...values];
      }),
    ];
    const padding = 24.0;
    const titleHeight = 40.0;
    const cellWidth = 150.0;
    const cellHeight = 54.0;
    final columns = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final width = padding * 2 + columns * cellWidth;
    final height = padding * 2 + titleHeight + rows.length * cellHeight;

    return _recordPng(width, height, (canvas) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.white,
      );
      _drawText(
        canvas,
        widget.table.title.isEmpty ? 'ProtocolFlow Table' : widget.table.title,
        Offset(padding, padding),
        maxWidth: width - padding * 2,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      );

      final gridTop = padding + titleHeight;
      for (var row = 0; row < rows.length; row++) {
        for (var col = 0; col < columns; col++) {
          final left = padding + col * cellWidth;
          final top = gridTop + row * cellHeight;
          final rect = Rect.fromLTWH(left, top, cellWidth, cellHeight);
          final colorHex = row == 0
              ? ''
              : _tableColor(row - 1, widget.includeRowHeaders ? col - 1 : col);
          final fill = row == 0
              ? Colors.blue.shade700
              : colorHex.isEmpty
              ? Colors.white
              : _parseHexColor(colorHex);
          canvas.drawRect(rect, Paint()..color = fill);
          canvas.drawRect(
            rect,
            Paint()
              ..color = Colors.grey.shade400
              ..style = PaintingStyle.stroke,
          );
          final value = col < rows[row].length ? rows[row][col] : '';
          _drawText(
            canvas,
            value,
            Offset(left + 8, top + 8),
            maxWidth: cellWidth - 16,
            maxLines: 2,
            style: TextStyle(
              color: row == 0 ? Colors.white : Colors.black87,
              fontSize: 12,
              fontWeight: row == 0 ? FontWeight.bold : FontWeight.normal,
            ),
          );
        }
      }
    });
  }

  Future<Uint8List> _recordPng(
    double width,
    double height,
    void Function(Canvas canvas) draw,
  ) async {
    const pixelRatio = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..clipRect(Rect.fromLTWH(0, 0, width, height));
    draw(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).ceil(),
      (height * pixelRatio).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double maxWidth,
    required TextStyle style,
    TextAlign textAlign = TextAlign.left,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  List<String> _headers() {
    if (!widget.includeRowHeaders) return widget.table.columnHeaders;
    return ['#', ...widget.table.columnHeaders];
  }

  String _tableCell(int row, int col) {
    if (row < 0 ||
        col < 0 ||
        row >= widget.table.data.length ||
        col >= widget.table.data[row].length) {
      return '';
    }
    return widget.table.data[row][col]?.toString() ?? '';
  }

  String _tableColor(int row, int col) {
    if (row < 0 ||
        col < 0 ||
        row >= widget.table.cellColors.length ||
        col >= widget.table.cellColors[row].length) {
      return '';
    }
    return widget.table.cellColors[row][col];
  }

  Color _parseHexColor(String hex) {
    if (hex.isEmpty) return Colors.transparent;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.transparent;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _safeFileName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'table' : sanitized;
  }
}
