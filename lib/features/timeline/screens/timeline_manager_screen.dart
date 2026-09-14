import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/protocolflow_app_bar.dart';
import '../../../widgets/table_workspace.dart';
import '../models/timeline_model.dart';
import '../services/timeline_image_export_service.dart';
import '../widgets/timeline_figure_dialog.dart';
import '../widgets/timeline_preview.dart';

class TimelineManagerScreen extends StatefulWidget {
  const TimelineManagerScreen({
    super.key,
    this.timeline = const ExperimentTimeline(),
    this.onUpdate,
  });

  final ExperimentTimeline timeline;
  final ValueChanged<ExperimentTimeline>? onUpdate;

  @override
  State<TimelineManagerScreen> createState() => _TimelineManagerScreenState();
}

class _TimelineManagerScreenState extends State<TimelineManagerScreen> {
  static const _colors = <Color>[
    Color(0xFFE53935),
    Color(0xFFF57C00),
    Color(0xFF8E24AA),
    Color(0xFF3949AB),
    Color(0xFF039BE5),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFF546E7A),
  ];

  late ExperimentTimeline _timeline;
  final Set<String> _expanded = {};
  double _zoom = 1;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _timeline = widget.timeline.events.isEmpty
        ? widget.timeline.copyWith(events: [_newEvent(0)])
        : widget.timeline;
    _expanded.add(_timeline.events.first.id);
  }

  TimelineEvent _newEvent(int index) => TimelineEvent(
    id: 'event_${DateTime.now().microsecondsSinceEpoch}_$index',
    name: 'Event ${index + 1}',
    colorValue: _colors[index % _colors.length].toARGB32(),
    repeatStart: _timelineOrDefaultStart,
    repeatEnd: _timelineOrDefaultEnd,
    durationStart: _timelineOrDefaultStart,
    durationEnd: (_timelineOrDefaultStart + 1).clamp(
      _timelineOrDefaultStart,
      _timelineOrDefaultEnd,
    ),
    durationRanges: [
      TimelineDurationRange(
        start: _timelineOrDefaultStart,
        end: (_timelineOrDefaultStart + 1).clamp(
          _timelineOrDefaultStart,
          _timelineOrDefaultEnd,
        ),
      ),
    ],
    selectedTimePoints: [_timelineOrDefaultStart],
  );

  int get _timelineOrDefaultStart {
    try {
      return _timeline.start;
    } catch (_) {
      return widget.timeline.start;
    }
  }

  int get _timelineOrDefaultEnd {
    try {
      return _timeline.end;
    } catch (_) {
      return widget.timeline.end;
    }
  }

  void _setTimeline(ExperimentTimeline value) {
    setState(() => _timeline = value);
    widget.onUpdate?.call(value);
  }

  void _updateEvent(int index, TimelineEvent value) {
    final events = List<TimelineEvent>.from(_timeline.events)..[index] = value;
    _setTimeline(_timeline.copyWith(events: events));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProtocolFlowAppBar(
        title: 'Timeline Builder',
        actions: [
          IconButton(
            key: const ValueKey('save-timeline'),
            onPressed: _save,
            tooltip: 'Save timeline',
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ResponsiveTableManagerLayout(
        independentWideScroll: true,
        controlsKey: const ValueKey('timeline-controls'),
        previewKey: const ValueKey('timeline-preview'),
        controls: _buildControls(context),
        preview: _buildPreview(context),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TableWorkspaceSection(
          title: 'Timeline settings',
          icon: Icons.schedule,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('timeline-title'),
                initialValue: _timeline.title,
                decoration: const InputDecoration(labelText: 'Timeline name'),
                onChanged: (value) =>
                    _setTimeline(_timeline.copyWith(title: value)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      key: const ValueKey('timeline-start'),
                      label: 'Start',
                      value: _timeline.start,
                      onChanged: (value) => _updateRange(start: value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      key: const ValueKey('timeline-end'),
                      label: 'End',
                      value: _timeline.end,
                      onChanged: (value) => _updateRange(end: value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<TimelineUnit>(
                segments: TimelineUnit.values
                    .map(
                      (unit) =>
                          ButtonSegment(value: unit, label: Text(unit.label)),
                    )
                    .toList(),
                selected: {_timeline.unit},
                onSelectionChanged: (selection) =>
                    _setTimeline(_timeline.copyWith(unit: selection.first)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show grid lines'),
                value: _timeline.showGridLines,
                onChanged: (value) =>
                    _setTimeline(_timeline.copyWith(showGridLines: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._timeline.events.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildEventCard(entry.key, entry.value),
          ),
        ),
        FilledButton.tonalIcon(
          key: const ValueKey('add-timeline-event'),
          onPressed: _addEvent,
          icon: const Icon(Icons.add),
          label: const Text('Add event'),
        ),
      ],
    );
  }

  Widget _buildEventCard(int index, TimelineEvent event) {
    final isExpanded = _expanded.contains(event.id);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              isExpanded ? _expanded.remove(event.id) : _expanded.add(event.id);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    key: ValueKey('event-appearance-${event.id}'),
                    onTap: () => _chooseAppearance(index, event),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: TimelineMarkerSwatch(
                        shape: event.markerShape,
                        color: Color(event.colorValue),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      event.name.isEmpty ? 'Untitled event' : event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuButton<_EventAction>(
                    tooltip: 'Event options',
                    onSelected: (action) => _eventAction(index, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _EventAction.duplicate,
                        child: _MenuItem(Icons.copy_outlined, 'Duplicate'),
                      ),
                      PopupMenuItem(
                        value: _EventAction.moveUp,
                        enabled: index > 0,
                        child: const _MenuItem(Icons.arrow_upward, 'Move up'),
                      ),
                      PopupMenuItem(
                        value: _EventAction.moveDown,
                        enabled: index < _timeline.events.length - 1,
                        child: const _MenuItem(
                          Icons.arrow_downward,
                          'Move down',
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _EventAction.delete,
                        child: _MenuItem(Icons.delete_outline, 'Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextFormField(
                    key: ValueKey('event-name-${event.id}'),
                    initialValue: event.name,
                    decoration: const InputDecoration(labelText: 'Event name'),
                    onChanged: (value) =>
                        _updateEvent(index, event.copyWith(name: value)),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: ValueKey('event-description-${event.id}'),
                    initialValue: event.description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Short description (optional)',
                    ),
                    onChanged: (value) =>
                        _updateEvent(index, event.copyWith(description: value)),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<TimelineEventType>(
                    segments: const [
                      ButtonSegment(
                        value: TimelineEventType.timePoint,
                        icon: Icon(Icons.circle_outlined),
                        label: Text('Time point'),
                      ),
                      ButtonSegment(
                        value: TimelineEventType.duration,
                        icon: Icon(Icons.horizontal_rule),
                        label: Text('Duration'),
                      ),
                    ],
                    selected: {event.type},
                    onSelectionChanged: (selection) => _updateEvent(
                      index,
                      event.copyWith(type: selection.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (event.type == TimelineEventType.timePoint)
                    _buildPointSchedule(index, event)
                  else
                    _buildDurationSchedule(index, event),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointSchedule(int index, TimelineEvent event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TimelineScheduleMode>(
          segments: const [
            ButtonSegment(
              value: TimelineScheduleMode.chooseTimePoints,
              label: Text('Choose time points'),
            ),
            ButtonSegment(
              value: TimelineScheduleMode.repeat,
              label: Text('Repeat'),
            ),
          ],
          selected: {event.scheduleMode},
          onSelectionChanged: (selection) => _updateEvent(
            index,
            event.copyWith(scheduleMode: selection.first),
          ),
        ),
        const SizedBox(height: 12),
        if (event.scheduleMode == TimelineScheduleMode.chooseTimePoints)
          _buildTimePointPicker(index, event)
        else
          _buildRepeatFields(index, event),
      ],
    );
  }

  Widget _buildTimePointPicker(int index, TimelineEvent event) {
    final all = [
      for (var value = _timeline.start; value <= _timeline.end; value++) value,
    ];
    final selected = event.selectedTimePoints.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Schedule', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: () => _updateEvent(
                index,
                event.copyWith(
                  selectedTimePoints: selected.length == all.length ? [] : all,
                ),
              ),
              child: Text(
                selected.length == all.length ? 'Clear all' : 'Select all',
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 190),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: all.map((point) {
                final isSelected = selected.contains(point);
                return FilterChip(
                  key: ValueKey('time-point-${event.id}-$point'),
                  label: Text('$point'),
                  selected: isSelected,
                  selectedColor: Color(event.colorValue).withValues(alpha: 0.2),
                  side: BorderSide(
                    color: isSelected
                        ? Color(event.colorValue)
                        : AppColors.outlineVariant,
                  ),
                  onSelected: (value) {
                    final next = Set<int>.from(selected);
                    value ? next.add(point) : next.remove(point);
                    _updateEvent(
                      index,
                      event.copyWith(selectedTimePoints: next.toList()..sort()),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepeatFields(int index, TimelineEvent event) {
    return Row(
      children: [
        Expanded(
          child: _numberField(
            label: 'From',
            value: event.repeatStart,
            onChanged: (value) =>
                _updateEvent(index, event.copyWith(repeatStart: value)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _numberField(
            label: 'Every',
            value: event.repeatEvery,
            onChanged: (value) => _updateEvent(
              index,
              event.copyWith(repeatEvery: value.clamp(1, 366)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _numberField(
            label: 'Until',
            value: event.repeatEnd,
            onChanged: (value) =>
                _updateEvent(index, event.copyWith(repeatEnd: value)),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSchedule(int index, TimelineEvent event) {
    final ranges = event.effectiveDurationRanges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Duration ranges', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        for (var rangeIndex = 0; rangeIndex < ranges.length; rangeIndex++) ...[
          Row(
            children: [
              Expanded(
                child: _numberField(
                  key: ValueKey('duration-start-${event.id}-$rangeIndex'),
                  label: 'Starts at',
                  value: ranges[rangeIndex].start,
                  onChanged: (value) => _updateDurationRange(
                    index,
                    event,
                    rangeIndex,
                    ranges[rangeIndex].copyWith(start: value),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(
                  key: ValueKey('duration-end-${event.id}-$rangeIndex'),
                  label: 'Ends at',
                  value: ranges[rangeIndex].end,
                  onChanged: (value) => _updateDurationRange(
                    index,
                    event,
                    rangeIndex,
                    ranges[rangeIndex].copyWith(end: value),
                  ),
                ),
              ),
              IconButton(
                onPressed: ranges.length == 1
                    ? null
                    : () {
                        final updated = List<TimelineDurationRange>.from(ranges)
                          ..removeAt(rangeIndex);
                        _updateEvent(
                          index,
                          event.copyWith(durationRanges: updated),
                        );
                      },
                tooltip: 'Remove duration',
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          if (rangeIndex < ranges.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('add-duration-${event.id}'),
            onPressed: () {
              final suggestedStart = ranges.last.end < _timeline.end
                  ? ranges.last.end + 1
                  : _timeline.start;
              final suggestedEnd = (suggestedStart + 1).clamp(
                suggestedStart,
                _timeline.end,
              );
              _updateEvent(
                index,
                event.copyWith(
                  durationRanges: [
                    ...ranges,
                    TimelineDurationRange(
                      start: suggestedStart,
                      end: suggestedEnd,
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add duration'),
          ),
        ),
      ],
    );
  }

  void _updateDurationRange(
    int eventIndex,
    TimelineEvent event,
    int rangeIndex,
    TimelineDurationRange range,
  ) {
    final ranges = List<TimelineDurationRange>.from(
      event.effectiveDurationRanges,
    )..[rangeIndex] = range;
    _updateEvent(eventIndex, event.copyWith(durationRanges: ranges));
  }

  Widget _buildPreview(BuildContext context) {
    return TableWorkspaceSection(
      title: 'Timeline',
      icon: Icons.timeline,
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            key: const ValueKey('timeline-figure-layout'),
            onPressed: _exporting ? null : _showFigureLayoutDialog,
            tooltip: 'Figure layout and export',
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image),
          ),
          IconButton(
            onPressed: _zoom > 0.55
                ? () => setState(() => _zoom = (_zoom - 0.15).clamp(0.5, 2))
                : null,
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
          ),
          IconButton(
            onPressed: () => setState(() => _zoom = _fitZoom()),
            tooltip: 'Fit entire timeline',
            icon: const Icon(Icons.fit_screen),
          ),
          IconButton(
            onPressed: _zoom < 1.95
                ? () => setState(() => _zoom = (_zoom + 0.15).clamp(0.5, 2))
                : null,
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
          ),
        ],
      ),
      child: TimelinePreview(
        timeline: _timeline,
        zoom: _zoom,
        viewportHeight: 520,
      ),
    );
  }

  Widget _numberField({
    Key? key,
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      key: key ?? ValueKey('$label-$value'),
      initialValue: '$value',
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) onChanged(parsed);
      },
    );
  }

  void _updateRange({int? start, int? end}) {
    final nextStart = start ?? _timeline.start;
    final nextEnd = end ?? _timeline.end;
    if (nextStart >= nextEnd || nextEnd - nextStart > 365) return;
    _setTimeline(_timeline.copyWith(start: nextStart, end: nextEnd));
  }

  void _addEvent() {
    final event = _newEvent(_timeline.events.length);
    _expanded.add(event.id);
    _setTimeline(_timeline.copyWith(events: [..._timeline.events, event]));
  }

  void _eventAction(int index, _EventAction action) {
    final events = List<TimelineEvent>.from(_timeline.events);
    final event = events[index];
    switch (action) {
      case _EventAction.duplicate:
        final copy = event.copyWith(
          id: 'event_${DateTime.now().microsecondsSinceEpoch}',
          name: '${event.name} (copy)',
        );
        events.insert(index + 1, copy);
        _expanded.add(copy.id);
      case _EventAction.moveUp:
        if (index > 0) {
          final item = events.removeAt(index);
          events.insert(index - 1, item);
        }
      case _EventAction.moveDown:
        if (index < events.length - 1) {
          final item = events.removeAt(index);
          events.insert(index + 1, item);
        }
      case _EventAction.delete:
        events.removeAt(index);
    }
    _setTimeline(_timeline.copyWith(events: events));
  }

  Future<void> _chooseAppearance(int index, TimelineEvent event) async {
    var selectedColor = Color(event.colorValue);
    var selectedShape = event.markerShape;
    final selection = await showDialog<(Color, TimelineMarkerShape)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Event color and shape'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Color', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors
                    .map(
                      (color) => InkWell(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == selectedColor
                                  ? Colors.black87
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              Text('Shape', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: TimelineMarkerShape.values.map((shape) {
                  final selected = shape == selectedShape;
                  return Tooltip(
                    message: _shapeLabel(shape),
                    child: InkWell(
                      onTap: () => setDialogState(() => selectedShape = shape),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : null,
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TimelineMarkerSwatch(
                          shape: shape,
                          color: Colors.black87,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (selectedColor, selectedShape)),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (selection != null && mounted) {
      _updateEvent(
        index,
        event.copyWith(
          colorValue: selection.$1.toARGB32(),
          markerShape: selection.$2,
        ),
      );
    }
  }

  double _fitZoom() =>
      TimelinePreview.fitZoom(_timeline, 620, maximumZoom: 1.25);

  Future<void> _showFigureLayoutDialog() async {
    final result = await showTimelineFigureDialog(context, timeline: _timeline);
    if (result == null || !mounted) return;
    _setTimeline(result.timeline);
    if (result.exportPng) {
      await _exportPng(
        result.timeline,
        transparent: result.transparentBackground,
      );
    }
  }

  void _save() {
    if (_timeline.events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one event before saving.')),
      );
      return;
    }
    Navigator.pop(context, _timeline);
  }

  Future<void> _exportPng(
    ExperimentTimeline timeline, {
    required bool transparent,
  }) async {
    setState(() => _exporting = true);
    try {
      await const TimelineImageExportService().export(
        timeline: timeline,
        preset: TimelineExportPreset.highResolution,
        transparent: transparent,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Timeline image ready')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export image: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _shapeLabel(TimelineMarkerShape shape) => switch (shape) {
    TimelineMarkerShape.circle => 'Circle',
    TimelineMarkerShape.square => 'Square',
    TimelineMarkerShape.diamond => 'Diamond',
    TimelineMarkerShape.triangle => 'Triangle',
  };
}

enum _EventAction { duplicate, moveUp, moveDown, delete }

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 20), const SizedBox(width: 10), Text(label)],
  );
}
