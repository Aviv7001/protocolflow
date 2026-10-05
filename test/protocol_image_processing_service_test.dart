import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:protocolflow/services/protocol_image_processing_service.dart';
import 'package:protocolflow/widgets/protocol_image_editor_dialog.dart';
import 'package:protocolflow/widgets/protocol_image_preview_frame.dart';

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

  test('fit creates a centered 6:4 image with white padding', () {
    final source = image.Image(width: 100, height: 400);
    image.fill(source, color: image.ColorRgb8(20, 80, 120));

    final result = ProtocolImageProcessingService.createImage(
      image.encodePng(source),
      aspectRatio: ProtocolImageAspectRatio.wide,
      mode: ProtocolImageLayoutMode.fit,
    );
    final decoded = image.decodeImage(result)!;

    expect(decoded.width, 1200);
    expect(decoded.height, 800);
    expect(decoded.getPixel(0, 0).r.toInt(), greaterThan(245));
    final center = decoded.getPixel(600, 400);
    expect(center.b.toInt(), greaterThan(center.r.toInt()));
  });

  test('crop creates an exact 6:4 image', () {
    final source = image.Image(width: 500, height: 500);
    image.fill(source, color: image.ColorRgb8(120, 40, 20));

    final result = ProtocolImageProcessingService.createImage(
      image.encodePng(source),
      aspectRatio: ProtocolImageAspectRatio.wide,
      mode: ProtocolImageLayoutMode.crop,
      focusX: 0.25,
      focusY: 0.75,
      zoom: 1.5,
    );
    final decoded = image.decodeImage(result)!;

    expect(decoded.width, 1200);
    expect(decoded.height, 800);
  });

  testWidgets('image editor saves the selected wide format', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = image.Image(width: 400, height: 400);
    image.fill(source, color: image.ColorRgb8(20, 80, 120));
    ProtocolImageEditResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<ProtocolImageEditResult>(
                  context: context,
                  builder: (context) => ProtocolImageEditorDialog(
                    imageBytes: image.encodePng(source),
                    initialName: 'Wide figure',
                  ),
                );
              },
              child: const Text('Edit image'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit image'));
    await tester.pumpAndSettle();
    expect(find.text('3:4 Tall'), findsOneWidget);
    expect(find.text('6:4 Wide'), findsOneWidget);

    await tester.ensureVisible(find.text('6:4 Wide'));
    await tester.tap(find.text('6:4 Wide'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Wide figure');
    final saved = image.decodeImage(result!.bytes)!;
    expect(saved.width, 1200);
    expect(saved.height, 800);
  });

  testWidgets('full-size preview follows a wide image ratio', (tester) async {
    final wide = image.Image(width: 600, height: 400);
    final path = 'data:image/png;base64,${base64Encode(image.encodePng(wide))}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: ProtocolImagePreviewFrame(
                key: const Key('wide-preview'),
                path: path,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final aspect = tester.widget<AspectRatio>(
      find.descendant(
        of: find.byKey(const Key('wide-preview')),
        matching: find.byType(AspectRatio),
      ),
    );
    expect(aspect.aspectRatio, 1.5);
  });
}
