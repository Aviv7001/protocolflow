import 'dart:convert';

import '../../../models/protocol_table.dart';

enum TimelineUnit { hours, days, weeks }

extension TimelineUnitLabel on TimelineUnit {
  String get label => switch (this) {
    TimelineUnit.hours => 'Hours',
    TimelineUnit.days => 'Days',
    TimelineUnit.weeks => 'Weeks',
  };
}

enum TimelineEventType { timePoint, duration }

enum TimelineMarkerShape { circle, square, diamond, triangle }

enum TimelineScheduleMode { chooseTimePoints, repeat }

enum TimelineFigureLayout { compact, medium, wide, manual }

class TimelineDurationRange {
  const TimelineDurationRange({required this.start, required this.end});

  final int start;
  final int end;

  TimelineDurationRange copyWith({int? start, int? end}) =>
      TimelineDurationRange(start: start ?? this.start, end: end ?? this.end);

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  factory TimelineDurationRange.fromJson(Map<String, dynamic> json) =>
      TimelineDurationRange(
        start: (json['start'] as num?)?.toInt() ?? 0,
        end: (json['end'] as num?)?.toInt() ?? 1,
      );
}

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.name,
    this.description = '',
    this.colorValue = 0xFFE53935,
    this.type = TimelineEventType.timePoint,
    this.markerShape = TimelineMarkerShape.circle,
    this.scheduleMode = TimelineScheduleMode.chooseTimePoints,
    this.selectedTimePoints = const [0],
    this.repeatStart = 0,
    this.repeatEnd = 8,
    this.repeatEvery = 1,
    this.durationStart = 0,
    this.durationEnd = 1,
    this.durationRanges = const [],
  });

  final String id;
  final String name;
  final String description;
  final int colorValue;
  final TimelineEventType type;
  final TimelineMarkerShape markerShape;
  final TimelineScheduleMode scheduleMode;
  final List<int> selectedTimePoints;
  final int repeatStart;
  final int repeatEnd;
  final int repeatEvery;
  final int durationStart;
  final int durationEnd;
  final List<TimelineDurationRange> durationRanges;

  List<TimelineDurationRange> get effectiveDurationRanges =>
      durationRanges.isEmpty
      ? [TimelineDurationRange(start: durationStart, end: durationEnd)]
      : durationRanges;

  List<int> scheduledPoints(int timelineStart, int timelineEnd) {
    if (type == TimelineEventType.duration) return const [];
    if (scheduleMode == TimelineScheduleMode.chooseTimePoints) {
      final values =
          selectedTimePoints
              .where((value) => value >= timelineStart && value <= timelineEnd)
              .toSet()
              .toList()
            ..sort();
      return values;
    }
    final repeatFrom = repeatStart.clamp(timelineStart, timelineEnd);
    final repeatTo = repeatEnd.clamp(repeatFrom, timelineEnd);
    final interval = repeatEvery.clamp(1, 366);
    return [
      for (var value = repeatFrom; value <= repeatTo; value += interval) value,
    ];
  }

  TimelineEvent copyWith({
    String? id,
    String? name,
    String? description,
    int? colorValue,
    TimelineEventType? type,
    TimelineMarkerShape? markerShape,
    TimelineScheduleMode? scheduleMode,
    List<int>? selectedTimePoints,
    int? repeatStart,
    int? repeatEnd,
    int? repeatEvery,
    int? durationStart,
    int? durationEnd,
    List<TimelineDurationRange>? durationRanges,
  }) => TimelineEvent(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    colorValue: colorValue ?? this.colorValue,
    type: type ?? this.type,
    markerShape: markerShape ?? this.markerShape,
    scheduleMode: scheduleMode ?? this.scheduleMode,
    selectedTimePoints: List<int>.from(
      selectedTimePoints ?? this.selectedTimePoints,
    ),
    repeatStart: repeatStart ?? this.repeatStart,
    repeatEnd: repeatEnd ?? this.repeatEnd,
    repeatEvery: repeatEvery ?? this.repeatEvery,
    durationStart: durationStart ?? this.durationStart,
    durationEnd: durationEnd ?? this.durationEnd,
    durationRanges: List<TimelineDurationRange>.from(
      durationRanges ?? this.durationRanges,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'colorValue': colorValue,
    'type': type.name,
    'markerShape': markerShape.name,
    'scheduleMode': scheduleMode.name,
    'selectedTimePoints': selectedTimePoints,
    'repeatStart': repeatStart,
    'repeatEnd': repeatEnd,
    'repeatEvery': repeatEvery,
    'durationStart': durationStart,
    'durationEnd': durationEnd,
    'durationRanges': durationRanges.map((range) => range.toJson()).toList(),
  };

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, dynamic value, T fallback) =>
        values.firstWhere((item) => item.name == value, orElse: () => fallback);
    return TimelineEvent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Event',
      description: json['description']?.toString() ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFE53935,
      type: enumValue(
        TimelineEventType.values,
        json['type'],
        TimelineEventType.timePoint,
      ),
      markerShape: enumValue(
        TimelineMarkerShape.values,
        json['markerShape'],
        TimelineMarkerShape.circle,
      ),
      scheduleMode: enumValue(
        TimelineScheduleMode.values,
        json['scheduleMode'],
        TimelineScheduleMode.chooseTimePoints,
      ),
      selectedTimePoints: (json['selectedTimePoints'] as List? ?? const [0])
          .map((value) => (value as num).toInt())
          .toList(),
      repeatStart: (json['repeatStart'] as num?)?.toInt() ?? 0,
      repeatEnd: (json['repeatEnd'] as num?)?.toInt() ?? 8,
      repeatEvery: (json['repeatEvery'] as num?)?.toInt() ?? 1,
      durationStart: (json['durationStart'] as num?)?.toInt() ?? 0,
      durationEnd: (json['durationEnd'] as num?)?.toInt() ?? 1,
      durationRanges: (json['durationRanges'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (range) => TimelineDurationRange.fromJson(
              Map<String, dynamic>.from(range),
            ),
          )
          .toList(),
    );
  }
}

class ExperimentTimeline {
  const ExperimentTimeline({
    this.title = 'Experiment Timeline',
    this.start = 0,
    this.end = 8,
    this.unit = TimelineUnit.days,
    this.showGridLines = false,
    this.pointSpacing = 52,
    this.eventSpacing = 64,
    this.figureLayout = TimelineFigureLayout.medium,
    this.events = const [],
  });

  final String title;
  final int start;
  final int end;
  final TimelineUnit unit;
  final bool showGridLines;
  final double pointSpacing;
  final double eventSpacing;
  final TimelineFigureLayout figureLayout;
  final List<TimelineEvent> events;

  int get pointCount => end - start + 1;

  ExperimentTimeline copyWith({
    String? title,
    int? start,
    int? end,
    TimelineUnit? unit,
    bool? showGridLines,
    double? pointSpacing,
    double? eventSpacing,
    TimelineFigureLayout? figureLayout,
    List<TimelineEvent>? events,
  }) => ExperimentTimeline(
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
    unit: unit ?? this.unit,
    showGridLines: showGridLines ?? this.showGridLines,
    pointSpacing: pointSpacing ?? this.pointSpacing,
    eventSpacing: eventSpacing ?? this.eventSpacing,
    figureLayout: figureLayout ?? this.figureLayout,
    events: List<TimelineEvent>.from(events ?? this.events),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'start': start,
    'end': end,
    'unit': unit.name,
    'showGridLines': showGridLines,
    'pointSpacing': pointSpacing,
    'eventSpacing': eventSpacing,
    'figureLayout': figureLayout.name,
    'events': events.map((event) => event.toJson()).toList(),
  };

  factory ExperimentTimeline.fromJson(Map<String, dynamic> json) =>
      ExperimentTimeline(
        title: json['title']?.toString() ?? 'Experiment Timeline',
        start: (json['start'] as num?)?.toInt() ?? 0,
        end: (json['end'] as num?)?.toInt() ?? 8,
        unit: TimelineUnit.values.firstWhere(
          (value) => value.name == json['unit'],
          orElse: () => TimelineUnit.days,
        ),
        showGridLines: json['showGridLines'] == true,
        pointSpacing: ((json['pointSpacing'] as num?)?.toDouble() ?? 52)
            .clamp(28, 100)
            .toDouble(),
        eventSpacing: ((json['eventSpacing'] as num?)?.toDouble() ?? 64)
            .clamp(44, 100)
            .toDouble(),
        figureLayout: TimelineFigureLayout.values.firstWhere(
          (value) => value.name == json['figureLayout'],
          orElse: () => TimelineFigureLayout.medium,
        ),
        events: (json['events'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (event) =>
                  TimelineEvent.fromJson(Map<String, dynamic>.from(event)),
            )
            .toList(),
      );

  factory ExperimentTimeline.fromTable(ProtocolTable table) {
    final state = table.metadata['timeline_state'];
    if (state == null || state.isEmpty) {
      return ExperimentTimeline(title: table.title);
    }
    try {
      return ExperimentTimeline.fromJson(
        Map<String, dynamic>.from(jsonDecode(state) as Map),
      ).copyWith(title: table.title);
    } catch (_) {
      return ExperimentTimeline(title: table.title);
    }
  }

  ProtocolTable toProtocolTable({String? id, String? projectId}) {
    final points = [for (var value = start; value <= end; value++) value];
    final rows = events.map((event) {
      final scheduled = event.scheduledPoints(start, end).toSet();
      return points.map<dynamic>((point) {
        if (event.type == TimelineEventType.duration) {
          final inDuration = event.effectiveDurationRanges.any((range) {
            final from = range.start.clamp(start, end);
            final to = range.end.clamp(from, end);
            return point >= from && point <= to;
          });
          return inDuration ? '—' : '';
        }
        return scheduled.contains(point) ? '●' : '';
      }).toList();
    }).toList();
    return ProtocolTable(
      id: id ?? 'timeline_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Experiment Timeline' : title.trim(),
      type: TableType.timeline,
      columnHeaders: points.map((point) => point.toString()).toList(),
      rowHeaders: events.map((event) => event.name).toList(),
      data: rows,
      cellColors: events
          .map(
            (event) => List.generate(
              points.length,
              (_) => event.colorValue.toRadixString(16).padLeft(8, '0'),
            ),
          )
          .toList(),
      metadata: {
        'timeline_state': jsonEncode(toJson()),
        'timeline_unit': unit.name,
        'timeline_start': '$start',
        'timeline_end': '$end',
        'typeColor': 'FF7B1FA2',
      },
      projectId: projectId,
      createdAt: DateTime.now(),
    );
  }
}
