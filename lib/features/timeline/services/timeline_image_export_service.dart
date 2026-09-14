import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../services/json_file_saver.dart';
import '../models/timeline_model.dart';
import '../widgets/timeline_preview.dart';

enum TimelineExportPreset { a4Landscape, presentation, highResolution }

extension TimelineExportPresetLabel on TimelineExportPreset {
  String get label => switch (this) {
    TimelineExportPreset.a4Landscape => 'A4 landscape (297:210)',
    TimelineExportPreset.presentation => 'Presentation (16:9)',
    TimelineExportPreset.highResolution => 'High resolution (content ratio)',
  };
}

class TimelineImageExportService {
  const TimelineImageExportService();

  Future<Uint8List> buildDocumentPng({
    required ExperimentTimeline timeline,
    double pageContentWidth = 543,
  }) async {
    final contentSize = TimelinePainter.documentCanvasSize(
      timeline,
      width: pageContentWidth,
    );
    const scale = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Offset.zero &
            Size(contentSize.width * scale, contentSize.height * scale),
        Paint()..color = Colors.white,
      )
      ..scale(scale);
    TimelinePainter(
      timeline: timeline,
      zoom: 1,
      backgroundColor: Colors.white,
      documentLayout: true,
    ).paint(canvas, contentSize);
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(
      (contentSize.width * scale).ceil(),
      (contentSize.height * scale).ceil(),
    );
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> export({
    required ExperimentTimeline timeline,
    required TimelineExportPreset preset,
    required bool transparent,
  }) async {
    final bytes = await buildPng(
      timeline: timeline,
      preset: preset,
      transparent: transparent,
    );
    await saveBinaryFile(
      bytes,
      '${_safeFileName(timeline.title)}.png',
      mimeType: 'image/png',
    );
  }

  Future<Uint8List> buildPng({
    required ExperimentTimeline timeline,
    TimelineExportPreset preset = TimelineExportPreset.highResolution,
    bool transparent = false,
  }) async {
    const zoom = 1.0;
    final contentSize = TimelinePreview.canvasSize(timeline, zoom);
    final requestedOutputSize = switch (preset) {
      TimelineExportPreset.a4Landscape => const Size(3508, 2480),
      TimelineExportPreset.presentation => const Size(1920, 1080),
      TimelineExportPreset.highResolution => Size(
        contentSize.width * 3,
        contentSize.height * 3,
      ),
    };
    const maximumDimension = 8192.0;
    final outputScale = (maximumDimension / requestedOutputSize.longestSide)
        .clamp(0.0, 1.0);
    final outputSize = Size(
      requestedOutputSize.width * outputScale,
      requestedOutputSize.height * outputScale,
    );
    const padding = 72.0;
    final widthScale = (outputSize.width - padding * 2) / contentSize.width;
    final heightScale = (outputSize.height - padding * 2) / contentSize.height;
    final scale = preset == TimelineExportPreset.highResolution
        ? 3.0 * outputScale
        : widthScale < heightScale
        ? widthScale
        : heightScale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (!transparent) {
      canvas.drawRect(Offset.zero & outputSize, Paint()..color = Colors.white);
    }
    final left = (outputSize.width - contentSize.width * scale) / 2;
    final top = (outputSize.height - contentSize.height * scale) / 2;
    canvas
      ..translate(left, top)
      ..scale(scale);
    TimelinePainter(
      timeline: timeline,
      zoom: zoom,
      backgroundColor: Colors.transparent,
    ).paint(canvas, contentSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      outputSize.width.ceil(),
      outputSize.height.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  String _safeFileName(String value) {
    final name = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return name.isEmpty ? 'experiment_timeline' : name;
  }
}
