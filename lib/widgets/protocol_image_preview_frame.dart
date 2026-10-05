import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../services/protocol_image_store.dart';
import 'local_image.dart';

/// Keeps a protocol figure's saved shape in the full-size preview.
class ProtocolImagePreviewFrame extends StatefulWidget {
  const ProtocolImagePreviewFrame({super.key, required this.path});

  final String path;

  @override
  State<ProtocolImagePreviewFrame> createState() =>
      _ProtocolImagePreviewFrameState();
}

class _ProtocolImagePreviewFrameState extends State<ProtocolImagePreviewFrame> {
  late Future<double> _aspectRatio;

  @override
  void initState() {
    super.initState();
    _aspectRatio = _loadAspectRatio();
  }

  @override
  void didUpdateWidget(covariant ProtocolImagePreviewFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _aspectRatio = _loadAspectRatio();
  }

  Future<double> _loadAspectRatio() async {
    final Uint8List? bytes = await ProtocolImageStore.loadBytes(widget.path);
    if (bytes == null) return 3 / 4;
    final decoded = image.decodeImage(bytes);
    if (decoded == null || decoded.height == 0) return 3 / 4;
    return decoded.width / decoded.height;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _aspectRatio,
      builder: (context, snapshot) => AspectRatio(
        aspectRatio: snapshot.data ?? 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Colors.white,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: buildLocalImage(widget.path, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
