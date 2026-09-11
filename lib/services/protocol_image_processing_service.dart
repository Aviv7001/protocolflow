import 'dart:typed_data';

import 'package:image/image.dart' as image;

enum ProtocolImageLayoutMode { fit, crop }

class ProtocolImageProcessingService {
  const ProtocolImageProcessingService._();

  static const int outputWidth = 900;
  static const int outputHeight = 1200;

  static Uint8List createThreeByFourImage(
    Uint8List bytes, {
    required ProtocolImageLayoutMode mode,
    double focusX = 0.5,
    double focusY = 0.5,
    double zoom = 1,
  }) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('The selected file is not a valid image.');
    }
    final source = image.bakeOrientation(decoded);
    final safeFocusX = focusX.clamp(0.0, 1.0);
    final safeFocusY = focusY.clamp(0.0, 1.0);
    final safeZoom = zoom.clamp(1.0, 3.0);

    late image.Image output;
    if (mode == ProtocolImageLayoutMode.fit) {
      final scale = [
        outputWidth / source.width,
        outputHeight / source.height,
      ].reduce((a, b) => a < b ? a : b);
      final width = (source.width * scale).round().clamp(1, outputWidth);
      final height = (source.height * scale).round().clamp(1, outputHeight);
      final resized = image.copyResize(source, width: width, height: height);
      output = image.Image(width: outputWidth, height: outputHeight);
      image.fill(output, color: image.ColorRgb8(255, 255, 255));
      image.compositeImage(
        output,
        resized,
        dstX: (outputWidth - width) ~/ 2,
        dstY: (outputHeight - height) ~/ 2,
      );
    } else {
      final baseScale = [
        outputWidth / source.width,
        outputHeight / source.height,
      ].reduce((a, b) => a > b ? a : b);
      final width = (source.width * baseScale * safeZoom).ceil();
      final height = (source.height * baseScale * safeZoom).ceil();
      final resized = image.copyResize(source, width: width, height: height);
      final maxX = width - outputWidth;
      final maxY = height - outputHeight;
      output = image.copyCrop(
        resized,
        x: (maxX * safeFocusX).round().clamp(0, maxX),
        y: (maxY * safeFocusY).round().clamp(0, maxY),
        width: outputWidth,
        height: outputHeight,
      );
    }

    return Uint8List.fromList(image.encodeJpg(output, quality: 92));
  }
}
