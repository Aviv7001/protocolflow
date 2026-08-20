import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  const canvasSize = 1024;
  final background = image.ColorRgba8(0xF7, 0xF9, 0xFA, 0xFF);
  const sourcePath = 'assets/App_icons/082026_ProtocolFlow_logo_teal.png';
  const squareOutputPath = 'assets/App_icons/PF_logo_teal_square_light.png';
  const foregroundOutputPath =
      'assets/App_icons/PF_logo_teal_adaptive_foreground.png';

  final source = image.decodePng(File(sourcePath).readAsBytesSync());
  if (source == null) {
    throw StateError('Could not decode the launcher logo source image.');
  }

  // Matches the visible bounds of the previous 1024px launcher foreground.
  const target = _Bounds(154, 154, 869, 870);
  final sourceBounds = _alphaBounds(source);
  final cropped = image.copyCrop(
    source,
    x: sourceBounds.left,
    y: sourceBounds.top,
    width: sourceBounds.width,
    height: sourceBounds.height,
  );
  final scale = [
    target.width / cropped.width,
    target.height / cropped.height,
  ].reduce((a, b) => a < b ? a : b);
  final width = (cropped.width * scale).round();
  final height = (cropped.height * scale).round();
  final resized = image.copyResize(
    cropped,
    width: width,
    height: height,
    interpolation: image.Interpolation.cubic,
  );
  final x = target.left + ((target.width - width) ~/ 2);
  final y = target.top + ((target.height - height) ~/ 2);

  final foreground = image.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  image.compositeImage(foreground, resized, dstX: x, dstY: y);

  final square = image.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  image.fill(square, color: background);
  image.compositeImage(square, foreground);

  File(foregroundOutputPath).writeAsBytesSync(image.encodePng(foreground));
  File(squareOutputPath).writeAsBytesSync(image.encodePng(square));

  stdout.writeln(
    'Target visible bounds: '
    '${target.left},${target.top} ${target.width}x${target.height}',
  );
  stdout.writeln('New mark placed at: $x,$y ${width}x$height');
}

_Bounds _alphaBounds(image.Image source) {
  var left = source.width;
  var top = source.height;
  var right = -1;
  var bottom = -1;

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (source.getPixel(x, y).a == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }

  if (right < left || bottom < top) {
    throw StateError('Logo source contains no visible pixels.');
  }
  return _Bounds(left, top, right, bottom);
}

class _Bounds {
  const _Bounds(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;
}
