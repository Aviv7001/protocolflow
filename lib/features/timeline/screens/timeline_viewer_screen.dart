import 'package:flutter/material.dart';

import '../../../models/protocol_table.dart';
import '../../../widgets/save_table_action.dart';
import '../../../widgets/table_workspace.dart';
import '../models/timeline_model.dart';
import '../services/timeline_image_export_service.dart';
import '../widgets/timeline_figure_dialog.dart';
import '../widgets/timeline_preview.dart';
import 'timeline_manager_screen.dart';

class TimelineViewerScreen extends StatefulWidget {
  const TimelineViewerScreen({
    super.key,
    required this.table,
    this.isReadOnly = true,
    this.onUpdate,
  });

  final ProtocolTable table;
  final bool isReadOnly;
  final ValueChanged<ProtocolTable>? onUpdate;

  @override
  State<TimelineViewerScreen> createState() => _TimelineViewerScreenState();
}

class _TimelineViewerScreenState extends State<TimelineViewerScreen> {
  late ProtocolTable _table;
  late ExperimentTimeline _timeline;
  double _zoom = 1;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _table = widget.table;
    _timeline = ExperimentTimeline.fromTable(_table);
  }

  @override
  Widget build(BuildContext context) {
    return TableViewerScaffold(
      title: _table.title,
      typeLabel: 'Experiment timeline',
      typeIcon: Icons.timeline,
      actions: [
        SaveTableAction(table: _table),
        if (!widget.isReadOnly)
          IconButton(
            onPressed: _edit,
            tooltip: 'Edit timeline',
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
      metadata: [
        TableMetadataBadge(
          label: '${_timeline.unit.label} ${_timeline.start}–${_timeline.end}',
          icon: Icons.schedule,
        ),
        TableMetadataBadge(
          label: '${_timeline.events.length} events',
          icon: Icons.event_note_outlined,
        ),
      ],
      table: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: TableWorkspaceSection(
              title: 'Timeline',
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    key: const ValueKey('timeline-figure-layout'),
                    onPressed: _exporting ? null : _showFigureDialog,
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
                        ? () => setState(
                            () => _zoom = (_zoom - 0.15).clamp(0.5, 2),
                          )
                        : null,
                    tooltip: 'Zoom out',
                    icon: const Icon(Icons.zoom_out),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => _zoom = TimelinePreview.fitZoom(
                        _timeline,
                        900,
                        maximumZoom: 1.25,
                      ),
                    ),
                    tooltip: 'Fit entire timeline',
                    icon: const Icon(Icons.fit_screen),
                  ),
                  IconButton(
                    onPressed: _zoom < 1.95
                        ? () => setState(
                            () => _zoom = (_zoom + 0.15).clamp(0.5, 2),
                          )
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
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<ExperimentTimeline>(
      context,
      MaterialPageRoute(
        builder: (context) => TimelineManagerScreen(timeline: _timeline),
      ),
    );
    if (updated == null || !mounted) return;
    final table = updated
        .toProtocolTable(id: _table.id, projectId: _table.projectId)
        .copyWith(createdAt: _table.createdAt);
    setState(() {
      _timeline = updated;
      _table = table;
    });
    widget.onUpdate?.call(table);
  }

  Future<void> _showFigureDialog() async {
    final result = await showTimelineFigureDialog(context, timeline: _timeline);
    if (result == null || !mounted) return;
    _applyTimeline(result.timeline);
    if (result.exportPng) {
      await _exportPng(
        result.timeline,
        transparent: result.transparentBackground,
      );
    }
  }

  void _applyTimeline(ExperimentTimeline timeline) {
    final table = timeline
        .toProtocolTable(id: _table.id, projectId: _table.projectId)
        .copyWith(createdAt: _table.createdAt);
    setState(() {
      _timeline = timeline;
      _table = table;
    });
    widget.onUpdate?.call(table);
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
}
