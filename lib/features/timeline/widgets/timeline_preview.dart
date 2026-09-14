import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/timeline_model.dart';

class TimelineMarkerSwatch extends StatelessWidget {
  const TimelineMarkerSwatch({
    super.key,
    required this.shape,
    required this.color,
    this.size = 28,
  });

  final TimelineMarkerShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _MarkerSwatchPainter(shape: shape, color: color),
    ),
  );
}

class _MarkerSwatchPainter extends CustomPainter {
  const _MarkerSwatchPainter({required this.shape, required this.color});

  final TimelineMarkerShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawTimelineMarker(
      canvas,
      size.center(Offset.zero),
      color,
      shape,
      radius: size.shortestSide * 0.34,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkerSwatchPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}

class TimelinePreview extends StatefulWidget {
  const TimelinePreview({
    super.key,
    required this.timeline,
    this.zoom = 1,
    this.transparentBackground = false,
    this.viewportHeight,
    this.fitToWidth = false,
  });

  final ExperimentTimeline timeline;
  final double zoom;
  final bool transparentBackground;
  final double? viewportHeight;
  final bool fitToWidth;

  static const double eventLabelWidth = 150;
  static const double labelPlotGap = 16;

  static double axisStart(ExperimentTimeline timeline) =>
      eventLabelWidth + labelPlotGap;

  static double pointStep(ExperimentTimeline timeline, double zoom) =>
      (timeline.pointSpacing * zoom).clamp(2, 160).toDouble();

  static Size canvasSize(ExperimentTimeline timeline, double zoom) {
    final step = pointStep(timeline, zoom);
    return Size(
      axisStart(timeline) + (timeline.pointCount - 1).clamp(1, 366) * step + 44,
      106 + timeline.events.length * timeline.eventSpacing + 58,
    );
  }

  static double fitZoom(
    ExperimentTimeline timeline,
    double availableWidth, {
    double maximumZoom = 1,
  }) {
    final intervals = (timeline.pointCount - 1).clamp(1, 366);
    final availablePlotWidth = (availableWidth - axisStart(timeline) - 44)
        .clamp(2, double.infinity);
    return (availablePlotWidth / (intervals * timeline.pointSpacing))
        .clamp(0.02, maximumZoom)
        .toDouble();
  }

  @override
  State<TimelinePreview> createState() => _TimelinePreviewState();
}

class _TimelinePreviewState extends State<TimelinePreview> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveZoom = widget.fitToWidth && constraints.maxWidth.isFinite
            ? TimelinePreview.fitZoom(
                widget.timeline,
                constraints.maxWidth,
                maximumZoom: widget.zoom,
              )
            : widget.zoom;
        return _buildScrollableCanvas(effectiveZoom);
      },
    );
  }

  Widget _buildScrollableCanvas(double effectiveZoom) {
    final size = TimelinePreview.canvasSize(widget.timeline, effectiveZoom);
    final canvas = Semantics(
      label:
          '${widget.timeline.title}, ${widget.timeline.events.length} events, '
          '${widget.timeline.unit.label} ${widget.timeline.start} to ${widget.timeline.end}',
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        child: SingleChildScrollView(
          key: const ValueKey('timeline-vertical-scroll'),
          controller: _verticalController,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              key: const ValueKey('timeline-horizontal-scroll'),
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: CustomPaint(
                key: const ValueKey('timeline-canvas'),
                size: size,
                painter: TimelinePainter(
                  timeline: widget.timeline,
                  zoom: effectiveZoom,
                  backgroundColor: widget.transparentBackground
                      ? Colors.transparent
                      : AppColors.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final viewportHeight = widget.viewportHeight;
    return viewportHeight == null
        ? canvas
        : SizedBox(
            height: size.height.clamp(120, viewportHeight),
            child: canvas,
          );
  }
}

class TimelinePainter extends CustomPainter {
  const TimelinePainter({
    required this.timeline,
    required this.zoom,
    required this.backgroundColor,
    this.documentLayout = false,
  });

  final ExperimentTimeline timeline;
  final double zoom;
  final Color backgroundColor;
  final bool documentLayout;

  static const _top = 78.0;

  static Size documentCanvasSize(
    ExperimentTimeline timeline, {
    double width = 543,
  }) => Size(width, 38 + timeline.events.length * 38 + 40);

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor.a > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    }
    final top = documentLayout ? 38.0 : _top;
    final rowHeight = documentLayout ? 38.0 : timeline.eventSpacing;
    final axisStart = documentLayout
        ? 142.0
        : TimelinePreview.axisStart(timeline);
    final axisRightPadding = documentLayout ? 18.0 : 44.0;
    final step = documentLayout
        ? (size.width - axisStart - axisRightPadding) /
              (timeline.pointCount - 1).clamp(1, 366)
        : TimelinePreview.pointStep(timeline, zoom);
    final titleFontSize = documentLayout ? 12.0 : 20.0;
    final eventFontSize = documentLayout ? 10.0 : 14.0;
    final descriptionFontSize = documentLayout ? 8.0 : 10.0;
    final timeFontSize = documentLayout ? 8.0 : 11.0;
    _text(
      canvas,
      timeline.title.isEmpty ? 'Experiment Timeline' : timeline.title,
      Offset(documentLayout ? 10 : 16, documentLayout ? 10 : 18),
      width: size.width - 32,
      style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w700),
    );

    final axisEnd = axisStart + (timeline.pointCount - 1) * step;
    final gridPaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = Colors.blueGrey.shade600
      ..strokeWidth = 1.6;

    for (var row = 0; row < timeline.events.length; row++) {
      final event = timeline.events[row];
      final centerY = top + row * rowHeight + rowHeight / 2;
      if (row.isOdd) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              documentLayout ? 4 : 8,
              centerY - (rowHeight - 6) / 2,
              size.width - (documentLayout ? 8 : 16),
              rowHeight - 6,
            ),
            Radius.circular(documentLayout ? 6 : 12),
          ),
          Paint()..color = AppColors.outlineVariant.withValues(alpha: 0.32),
        );
      }
      _text(
        canvas,
        event.name.isEmpty ? 'Untitled event' : event.name,
        Offset(
          documentLayout ? 8 : 16,
          centerY -
              (event.description.isEmpty
                  ? eventFontSize * 0.65
                  : eventFontSize + 4),
        ),
        width: (documentLayout ? 126 : TimelinePreview.eventLabelWidth - 32),
        maxLines: 1,
        style: TextStyle(fontSize: eventFontSize, fontWeight: FontWeight.w600),
      );
      if (event.description.isNotEmpty) {
        _text(
          canvas,
          event.description,
          Offset(documentLayout ? 8 : 16, centerY + 2),
          width: (documentLayout ? 126 : TimelinePreview.eventLabelWidth - 32),
          maxLines: 1,
          style: TextStyle(
            fontSize: descriptionFontSize,
            color: Colors.blueGrey.shade600,
          ),
        );
      }
      canvas.drawLine(
        Offset(axisStart, centerY),
        Offset(axisEnd, centerY),
        linePaint,
      );

      final color = Color(event.colorValue);
      if (event.type == TimelineEventType.duration) {
        for (final range in event.effectiveDurationRanges) {
          final from = range.start.clamp(timeline.start, timeline.end);
          final to = range.end.clamp(from, timeline.end);
          final left = axisStart + (from - timeline.start) * step;
          final right = axisStart + (to - timeline.start) * step;
          canvas.drawLine(
            Offset(left, centerY),
            Offset(right, centerY),
            Paint()
              ..color = Color.lerp(color, Colors.white, 0.35)!
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round,
          );
          drawTimelineMarker(
            canvas,
            Offset(left, centerY),
            color,
            event.markerShape,
            radius: documentLayout ? 5 : 8,
          );
          if (right != left) {
            drawTimelineMarker(
              canvas,
              Offset(right, centerY),
              color,
              event.markerShape,
              radius: documentLayout ? 5 : 8,
            );
          }
        }
      } else {
        for (final point in event.scheduledPoints(
          timeline.start,
          timeline.end,
        )) {
          drawTimelineMarker(
            canvas,
            Offset(axisStart + (point - timeline.start) * step, centerY),
            color,
            event.markerShape,
            radius: documentLayout ? 5 : 8,
          );
        }
      }
    }

    final axisY = top + timeline.events.length * rowHeight + 12;
    canvas.drawLine(
      Offset(axisStart, axisY),
      Offset(axisEnd, axisY),
      linePaint,
    );
    for (var index = 0; index < timeline.pointCount; index++) {
      final x = axisStart + index * step;
      if (timeline.showGridLines) {
        canvas.drawLine(Offset(x, top), Offset(x, axisY), gridPaint);
      }
      canvas.drawLine(Offset(x, axisY), Offset(x, axisY + 8), linePaint);
      _text(
        canvas,
        '${timeline.start + index}',
        Offset(x - step / 2, axisY + 11),
        width: step,
        align: TextAlign.center,
        style: TextStyle(fontSize: timeFontSize),
      );
    }
    _text(
      canvas,
      timeline.unit.label,
      Offset(documentLayout ? 8 : 16, axisY - 7),
      width: documentLayout ? 126 : TimelinePreview.eventLabelWidth - 32,
      style: TextStyle(
        fontSize: documentLayout ? 8 : 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset, {
    required double width,
    required TextStyle style,
    TextAlign align = TextAlign.left,
    int maxLines = 2,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: style.copyWith(color: style.color ?? Colors.black87),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) =>
      oldDelegate.timeline != timeline ||
      oldDelegate.zoom != zoom ||
      oldDelegate.documentLayout != documentLayout ||
      oldDelegate.backgroundColor != backgroundColor;
}

void drawTimelineMarker(
  Canvas canvas,
  Offset center,
  Color color,
  TimelineMarkerShape shape, {
  double radius = 8,
}) {
  final paint = Paint()..color = color;
  switch (shape) {
    case TimelineMarkerShape.circle:
      canvas.drawCircle(center, radius, paint);
    case TimelineMarkerShape.square:
      canvas.drawRect(
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
        paint,
      );
    case TimelineMarkerShape.diamond:
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - radius - 1)
          ..lineTo(center.dx + radius + 1, center.dy)
          ..lineTo(center.dx, center.dy + radius + 1)
          ..lineTo(center.dx - radius - 1, center.dy)
          ..close(),
        paint,
      );
    case TimelineMarkerShape.triangle:
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - radius - 2)
          ..lineTo(center.dx + radius + 1, center.dy + radius)
          ..lineTo(center.dx - radius - 1, center.dy + radius)
          ..close(),
        paint,
      );
  }
}
