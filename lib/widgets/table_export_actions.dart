import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/protocol_table.dart';
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
  final _boundaryKey = GlobalKey();
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
        RepaintBoundary(key: _boundaryKey, child: widget.child),
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
      final bytes = await _capturePngBytes();
      if (bytes == null) {
        _showSnack('Could not capture table image');
        return;
      }

      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: '${_safeFileName(widget.table.title)}.png',
        ),
      ], text: 'Exported ${widget.table.title} from ProtocolFlow');
    } finally {
      if (mounted) setState(() => _isSavingImage = false);
    }
  }

  Future<Uint8List?> _capturePngBytes() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
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
