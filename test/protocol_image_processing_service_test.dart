import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:protocolflow/services/protocol_image_processing_service.dart';

void main() {
  test('fit creates a centered 3:4 image with white padding', () {
    final source = image.Image(width: 400, height: 100);
    image.fill(source, color: image.ColorRgb8(20, 80, 120));

    final result = ProtocolImageProcessingService.createThreeByFourImage(
      image.encodePng(source),
      mode: ProtocolImageLayoutMode.fit,
    );
    final decoded = image.decodeImage(result)!;

    expect(decoded.width, 900);
    expect(decoded.height, 1200);
    final corner = decoded.getPixel(0, 0);
    expect(corner.r.toInt(), greaterThan(245));
    expect(corner.g.toInt(), greaterThan(245));
    expect(corner.b.toInt(), greaterThan(245));
    final center = decoded.getPixel(450, 600);
    expect(center.b.toInt(), greaterThan(center.r.toInt()));
  });

  test('crop creates an exact 3:4 image', () {
    final source = image.Image(width: 500, height: 500);
    image.fill(source, color: image.ColorRgb8(120, 40, 20));

    final result = ProtocolImageProcessingService.createThreeByFourImage(
      image.encodePng(source),
      mode: ProtocolImageLayoutMode.crop,
      focusX: 0.25,
      focusY: 0.75,
      zoom: 1.5,
    );
    final decoded = image.decodeImage(result)!;

    expect(decoded.width, 900);
    expect(decoded.height, 1200);
  });
}
