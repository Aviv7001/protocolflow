import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/timeline_model.dart';

class TimelineFigureDialogResult {
  const TimelineFigureDialogResult({
    required this.timeline,
    required this.exportPng,
    required this.transparentBackground,
  });

  final ExperimentTimeline timeline;
  final bool exportPng;
  final bool transparentBackground;
}

Future<TimelineFigureDialogResult?> showTimelineFigureDialog(
  BuildContext context, {
  required ExperimentTimeline timeline,
}) {
  var layout = timeline.figureLayout;
  var pointSpacing = timeline.pointSpacing;
  var eventSpacing = timeline.eventSpacing;
  var transparent = false;

  ExperimentTimeline updatedTimeline() => timeline.copyWith(
    figureLayout: layout,
    pointSpacing: pointSpacing,
    eventSpacing: eventSpacing,
  );

  return showDialog<TimelineFigureDialogResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Figure layout and export'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Figure layout',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                SegmentedButton<TimelineFigureLayout>(
                  key: const ValueKey('timeline-layout-presets'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: TimelineFigureLayout.compact,
                      label: Text('Compact'),
                    ),
                    ButtonSegment(
                      value: TimelineFigureLayout.medium,
                      label: Text('Medium'),
                    ),
                    ButtonSegment(
                      value: TimelineFigureLayout.wide,
                      label: Text('Wide'),
                    ),
                    ButtonSegment(
                      value: TimelineFigureLayout.manual,
                      label: Text('Manual'),
                    ),
                  ],
                  selected: {layout},
                  onSelectionChanged: (selection) {
                    setDialogState(() {
                      layout = selection.first;
                      switch (layout) {
                        case TimelineFigureLayout.compact:
                          pointSpacing = 36;
                          eventSpacing = 64;
                        case TimelineFigureLayout.medium:
                          pointSpacing = 52;
                          eventSpacing = 64;
                        case TimelineFigureLayout.wide:
                          pointSpacing = 76;
                          eventSpacing = 64;
                        case TimelineFigureLayout.manual:
                          break;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (layout == TimelineFigureLayout.manual) ...[
                  Text(
                    'Plot length',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    key: const ValueKey('timeline-plot-length-slider'),
                    min: 28,
                    max: 100,
                    divisions: 72,
                    value: pointSpacing,
                    label: '${pointSpacing.round()} px per interval',
                    onChanged: (value) =>
                        setDialogState(() => pointSpacing = value),
                  ),
                  Text(
                    'Figure height',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    key: const ValueKey('timeline-event-height-slider'),
                    min: 44,
                    max: 100,
                    divisions: 56,
                    value: eventSpacing,
                    label: '${eventSpacing.round()} px between events',
                    onChanged: (value) =>
                        setDialogState(() => eventSpacing = value),
                  ),
                ] else
                  Text(
                    'Plot: ${pointSpacing.round()} px per interval',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),
                Text(
                  'Export as PNG',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Exports the current layout as a high-resolution image.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Transparent background'),
                  value: transparent,
                  onChanged: (value) =>
                      setDialogState(() => transparent = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              TimelineFigureDialogResult(
                timeline: updatedTimeline(),
                exportPng: false,
                transparentBackground: transparent,
              ),
            ),
            child: const Text('Apply'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              dialogContext,
              TimelineFigureDialogResult(
                timeline: updatedTimeline(),
                exportPng: true,
                transparentBackground: transparent,
              ),
            ),
            icon: const Icon(Icons.download),
            label: const Text('Export PNG'),
          ),
        ],
      ),
    ),
  );
}
