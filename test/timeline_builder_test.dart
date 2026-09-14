import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:protocolflow/features/timeline/models/timeline_model.dart';
import 'package:protocolflow/features/timeline/screens/timeline_manager_screen.dart';
import 'package:protocolflow/features/timeline/screens/timeline_viewer_screen.dart';
import 'package:protocolflow/features/timeline/services/timeline_image_export_service.dart';
import 'package:protocolflow/features/timeline/widgets/timeline_preview.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/theme/app_theme.dart';

void main() {
  test('timeline round trip preserves editable events and table data', () {
    const timeline = ExperimentTimeline(
      title: 'Mouse study',
      start: -2,
      end: 4,
      unit: TimelineUnit.days,
      showGridLines: true,
      pointSpacing: 76,
      eventSpacing: 82,
      figureLayout: TimelineFigureLayout.manual,
      events: [
        TimelineEvent(
          id: 'blood',
          name: 'Take blood',
          markerShape: TimelineMarkerShape.diamond,
          selectedTimePoints: [-2, 0, 4],
        ),
        TimelineEvent(
          id: 'dose',
          name: 'Treatment',
          type: TimelineEventType.duration,
          markerShape: TimelineMarkerShape.square,
          durationRanges: [
            TimelineDurationRange(start: -1, end: 1),
            TimelineDurationRange(start: 3, end: 4),
          ],
        ),
      ],
    );

    final table = timeline.toProtocolTable(id: 'timeline-1');
    final restored = ExperimentTimeline.fromTable(
      ProtocolTable.fromJson(jsonDecode(jsonEncode(table.toJson()))),
    );

    expect(table.type, TableType.timeline);
    expect(table.columnHeaders, ['-2', '-1', '0', '1', '2', '3', '4']);
    expect(restored.title, 'Mouse study');
    expect(restored.showGridLines, isTrue);
    expect(restored.pointSpacing, 76);
    expect(restored.eventSpacing, 82);
    expect(restored.figureLayout, TimelineFigureLayout.manual);
    expect(restored.events[0].markerShape, TimelineMarkerShape.diamond);
    expect(restored.events[0].scheduledPoints(-2, 4), [-2, 0, 4]);
    expect(table.data[1], ['', '—', '—', '—', '', '—', '—']);
    expect(restored.events[1].durationRanges, hasLength(2));
    expect(restored.events[1].markerShape, TimelineMarkerShape.square);

    final renamed = ExperimentTimeline.fromTable(
      table.copyWith(title: 'Renamed saved timeline'),
    );
    expect(renamed.title, 'Renamed saved timeline');
  });

  test('repeat schedule is bounded to the timeline', () {
    const event = TimelineEvent(
      id: 'repeat',
      name: 'Dose',
      scheduleMode: TimelineScheduleMode.repeat,
      repeatStart: -10,
      repeatEnd: 10,
      repeatEvery: 3,
    );

    expect(event.scheduledPoints(-2, 5), [-2, 1, 4]);
  });

  test('legacy single duration remains available after loading', () {
    final event = TimelineEvent.fromJson({
      'id': 'legacy',
      'name': 'Legacy treatment',
      'type': 'duration',
      'durationStart': 2,
      'durationEnd': 5,
    });

    expect(event.effectiveDurationRanges, hasLength(1));
    expect(event.effectiveDurationRanges.single.start, 2);
    expect(event.effectiveDurationRanges.single.end, 5);
  });

  test('high resolution export uses saved manual width and height', () async {
    const timeline = ExperimentTimeline(
      figureLayout: TimelineFigureLayout.manual,
      pointSpacing: 80,
      eventSpacing: 90,
      events: [
        TimelineEvent(id: 'one', name: 'One'),
        TimelineEvent(id: 'two', name: 'Two'),
      ],
    );
    final expectedSize = TimelinePreview.canvasSize(timeline, 1);
    final bytes = await const TimelineImageExportService().buildPng(
      timeline: timeline,
      preset: TimelineExportPreset.highResolution,
    );
    final png = image.decodePng(bytes)!;

    expect(png.width, (expectedSize.width * 3).ceil());
    expect(png.height, (expectedSize.height * 3).ceil());
  });

  test('document export uses fixed A4-width figure dimensions', () async {
    const timeline = ExperimentTimeline(
      figureLayout: TimelineFigureLayout.manual,
      pointSpacing: 100,
      eventSpacing: 100,
      events: [TimelineEvent(id: 'one', name: 'One')],
    );
    final bytes = await const TimelineImageExportService().buildDocumentPng(
      timeline: timeline,
    );
    final png = image.decodePng(bytes)!;
    final documentSize = TimelinePainter.documentCanvasSize(timeline);

    expect(png.width, (documentSize.width * 3).ceil());
    expect(png.height, (documentSize.height * 3).ceil());
    expect(png.width, 1629);
  });

  Future<void> pumpManager(
    WidgetTester tester,
    Size size, {
    ExperimentTimeline timeline = const ExperimentTimeline(),
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: TimelineManagerScreen(timeline: timeline),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('timeline manager uses independently scrolling wide columns', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpManager(tester, const Size(1200, 820));

    expect(
      find.byKey(const ValueKey('controls-column-scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preview-column-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline manager stacks editor and preview on narrow screens', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpManager(tester, const Size(390, 844));

    expect(find.byKey(const ValueKey('controls-column-scroll')), findsNothing);
    expect(find.byKey(const ValueKey('timeline-controls')), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-preview')), findsOneWidget);
    expect(find.text('Add event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event appearance picker combines color and marker shape', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpManager(tester, const Size(1200, 820));

    final appearance = predicateKey(
      (key) => key.toString().contains('event-appearance-'),
    );
    expect(appearance, findsOneWidget);
    await tester.tap(appearance);
    await tester.pumpAndSettle();

    expect(find.text('Event color and shape'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Shape'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duration events support multiple ranges', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const timeline = ExperimentTimeline(
      events: [
        TimelineEvent(
          id: 'duration',
          name: 'Treatment',
          type: TimelineEventType.duration,
          durationRanges: [TimelineDurationRange(start: 0, end: 3)],
        ),
      ],
    );
    await pumpManager(tester, const Size(1200, 820), timeline: timeline);

    final addDuration = find.byKey(const ValueKey('add-duration-duration'));
    await tester.ensureVisible(addDuration);
    await tester.pumpAndSettle();
    await tester.tap(addDuration);
    await tester.pump();

    expect(find.text('Starts at'), findsNWidgets(2));
    expect(find.text('Ends at'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('figure layout and PNG export share one dialog', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpManager(tester, const Size(1200, 820));

    final figureSettings = find.byKey(const ValueKey('timeline-figure-layout'));
    expect(figureSettings, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: figureSettings),
      findsNothing,
    );
    await tester.tap(figureSettings);
    await tester.pumpAndSettle();

    expect(find.text('Figure layout and export'), findsOneWidget);
    expect(find.text('Export as PNG'), findsOneWidget);
    expect(find.text('Export PNG'), findsOneWidget);
    expect(find.text('Image ratio'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline viewer exposes the combined figure dialog', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1000, 820));
    final table = const ExperimentTimeline(
      events: [TimelineEvent(id: 'one', name: 'One')],
    ).toProtocolTable(id: 'viewer-timeline');
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: TimelineViewerScreen(table: table),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('timeline-figure-layout')));
    await tester.pumpAndSettle();

    expect(find.text('Figure layout and export'), findsOneWidget);
    expect(find.text('Export as PNG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('figure layout controls update plot length and event height', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpManager(tester, const Size(1200, 820));

    await tester.tap(find.byKey(const ValueKey('timeline-figure-layout')));
    await tester.pumpAndSettle();
    expect(find.text('Compact'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Wide'), findsOneWidget);
    await tester.tap(find.text('Manual'));
    await tester.pump();

    final plotSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('timeline-plot-length-slider')),
    );
    final heightSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('timeline-event-height-slider')),
    );
    plotSlider.onChanged!(80);
    heightSlider.onChanged!(72);
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final preview = tester.widget<TimelinePreview>(
      find.byType(TimelinePreview),
    );
    expect(preview.timeline.pointSpacing, 80);
    expect(preview.timeline.eventSpacing, 72);
    expect(preview.timeline.figureLayout, TimelineFigureLayout.manual);
    expect(tester.takeException(), isNull);
  });
}

Finder predicateKey(bool Function(Key key) predicate) => find.byWidgetPredicate(
  (widget) => widget.key != null && predicate(widget.key!),
);
