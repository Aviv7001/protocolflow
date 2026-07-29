import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/widgets/local_image.dart';
import 'package:protocolflow/widgets/protocol_step_actions_table.dart';
import 'package:protocolflow/widgets/protocol_step_notes_table.dart';
import 'package:protocolflow/widgets/protocol_table_preview.dart';
import 'package:protocolflow/widgets/protocolflow_app_bar.dart';
import 'package:protocolflow/widgets/responsive_layout.dart';
import 'package:protocolflow/widgets/sync_status_chip.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/services/docx_export_service.dart';
import 'package:protocolflow/services/pdf_service.dart';
import 'package:protocolflow/services/export_service.dart';
import 'package:protocolflow/services/storage_service.dart';
import 'package:protocolflow/theme/app_colors.dart';
import 'package:protocolflow/utils/date_time_format.dart';

class CompletedProtocolDetailScreen extends StatefulWidget {
  final CompletedProtocol completedProtocol;

  const CompletedProtocolDetailScreen({
    super.key,
    required this.completedProtocol,
  });

  @override
  State<CompletedProtocolDetailScreen> createState() =>
      _CompletedProtocolDetailScreenState();
}

class _CompletedProtocolDetailScreenState
    extends State<CompletedProtocolDetailScreen> {
  CompletedProtocol get completedProtocol => widget.completedProtocol;
  List<Project> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await StorageService().loadProjects();
    if (mounted) setState(() => _projects = projects);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Protocol?'),
        content: const Text(
          'Are you sure you want to delete this completed protocol record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              completedProtocols.removeWhere(
                (p) => p.id == completedProtocol.id,
              );
              await savePersistentProtocols();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Go back to list
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportProtocol(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                PdfService.exportToPdf(completedProtocol);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Export as Word (DOCX)'),
              onTap: () {
                Navigator.pop(context);
                const DocxExportService().exportCompletedProtocol(
                  completedProtocol,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export as ProtocolFlow file'),
              onTap: () {
                Navigator.pop(context);
                ExportService().exportSingleCompletedProtocol(
                  completedProtocol,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_view),
              title: const Text('Export as Excel (XLSX) (Coming Soon)'),
              enabled: false,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = formatDateTime(completedProtocol.completedAt);

    return Scaffold(
      appBar: ProtocolFlowAppBar(
        title: 'Completed Protocol Detail',
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _exportProtocol(context),
            tooltip: 'Export',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _buildDetailBody(context, dateStr),
    );
  }

  Widget _buildDetailBody(BuildContext context, String completedDate) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= ProtocolFlowBreakpoints.desktop;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            desktop ? 24 : 12,
            desktop ? 24 : 16,
            desktop ? 24 : 12,
            48,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1800),
              child: _buildDetailWorkspace(
                context,
                completedDate: completedDate,
                desktop: desktop,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailWorkspace(
    BuildContext context, {
    required String completedDate,
    required bool desktop,
  }) {
    final protocol = completedProtocol.protocol;
    final regularTables = protocol.tables
        .where((table) => table.type != TableType.materialList)
        .toList();
    final overviewNotes = completedProtocol.notes
        .where((note) => note.stepId == 'overview')
        .toList();
    final hasAdditionalData =
        protocol.files.isNotEmpty || protocol.additionalData.isNotEmpty;

    final information = _buildProtocolInformationSection(
      context,
      completedDate,
    );
    final samples = protocol.samples.isEmpty
        ? null
        : _buildSamplesSection(context);
    final materials = _buildMaterialListSection(context);
    final steps = _buildStepsSurface(context);
    final generalNotes = overviewNotes.isEmpty
        ? null
        : _buildGeneralNotesSurface(context, overviewNotes);
    final tables = regularTables.isEmpty
        ? null
        : _buildTablesSurface(context, regularTables);
    final additionalData = hasAdditionalData
        ? _buildAdditionalDataSurface(context)
        : null;

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          information,
          if (samples != null) ...[const SizedBox(height: 24), samples],
          const SizedBox(height: 24),
          materials,
          const SizedBox(height: 24),
          steps,
          if (generalNotes != null) ...[
            const SizedBox(height: 24),
            generalNotes,
          ],
          if (tables != null) ...[const SizedBox(height: 24), tables],
          if (additionalData != null) ...[
            const SizedBox(height: 24),
            additionalData,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              information,
              if (generalNotes != null) ...[
                const SizedBox(height: 24),
                generalNotes,
              ],
              if (tables != null) ...[const SizedBox(height: 24), tables],
              if (additionalData != null) ...[
                const SizedBox(height: 24),
                additionalData,
              ],
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (samples != null) ...[samples, const SizedBox(height: 24)],
              materials,
              const SizedBox(height: 24),
              steps,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolInformationSection(
    BuildContext context,
    String completedDate,
  ) {
    final protocol = completedProtocol.protocol;
    return _buildSectionSurface(
      context,
      key: const Key('completed-detail-protocol-information'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(context, 'Protocol Information'),
          const SizedBox(height: 16),
          Text(
            protocol.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDetailBadge(
                icon: Icons.check_circle_outline,
                label: 'COMPLETED',
                color: AppColors.success,
              ),
              SyncStatusChip(status: protocol.syncStatus, compact: true),
              _buildDetailBadge(
                icon: Icons.folder_outlined,
                label: 'Project: ${_projectNameFor(protocol.projectId)}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _buildMetadataItem(
                context,
                icon: Icons.calendar_today_outlined,
                text: 'Created on: ${formatDate(protocol.createdAt)}',
              ),
              _buildMetadataItem(
                context,
                icon: Icons.person_outline,
                text:
                    'Created by: '
                    '${protocol.createdByName ?? 'Unknown user'}',
              ),
              _buildMetadataItem(
                context,
                icon: Icons.event_available_outlined,
                text: 'Completed on: $completedDate',
              ),
              _buildMetadataItem(
                context,
                icon: Icons.person_pin_outlined,
                text:
                    'Completed by: '
                    '${completedProtocol.completedByName ?? 'Unknown user'}',
              ),
            ],
          ),
          const Divider(height: 32),
          _buildReadOnlyField('Objective', protocol.objective),
          const SizedBox(height: 18),
          _buildReadOnlyField('Description', protocol.description),
        ],
      ),
    );
  }

  Widget _buildDetailBadge({
    required IconData icon,
    required String label,
    Color color = AppColors.primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final maxWidth = (MediaQuery.sizeOf(context).width - 32)
        .clamp(0.0, 360.0)
        .toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _projectNameFor(String? projectId) {
    if (projectId == null || projectId.isEmpty) return 'Unassigned';
    for (final project in _projects) {
      if (project.id == projectId) return project.name;
    }
    return 'Unassigned';
  }

  Widget _buildReadOnlyField(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          content.trim().isEmpty ? 'Not provided.' : content,
          style: TextStyle(
            color: content.trim().isEmpty
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSamplesSection(BuildContext context) {
    return _buildSectionSurface(
      context,
      key: const Key('completed-detail-samples'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(context, 'Samples'),
          const SizedBox(height: 12),
          ...completedProtocol.protocol.samples.map(
            (sample) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.biotech_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(sample)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialListSection(BuildContext context) {
    final protocol = completedProtocol.protocol;
    final materialNotes = completedProtocol.notes
        .where((note) => note.stepId == 'materials')
        .toList();
    return _buildSectionSurface(
      context,
      key: const Key('completed-detail-materials'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(context, 'Material List'),
          const SizedBox(height: 10),
          if (protocol.materialListTable != null)
            LinkedProtocolTablesSection(tables: [protocol.materialListTable!])
          else
            _buildEmptyState('No material list table linked.'),
          if (materialNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Recorded notes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            ..._buildNotesSection(materialNotes),
          ],
        ],
      ),
    );
  }

  Widget _buildStepsSurface(BuildContext context) {
    return _buildSectionSurface(
      context,
      key: const Key('completed-detail-steps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(context, 'Steps'),
          const SizedBox(height: 8),
          if (completedProtocol.protocol.steps.isEmpty)
            _buildEmptyState('No steps recorded.')
          else
            ..._buildGroupedSteps(context),
        ],
      ),
    );
  }

  Widget _buildGeneralNotesSurface(BuildContext context, List<StepNote> notes) {
    return _buildSectionSurface(
      context,
      key: const Key('completed-detail-general-notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(context, 'General Notes'),
          const SizedBox(height: 8),
          ..._buildNotesSection(notes),
        ],
      ),
    );
  }

  Widget _buildTablesSurface(BuildContext context, List<ProtocolTable> tables) {
    return _buildSectionSurface(
      context,
      key: const Key('completed-detail-tables'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(context, 'Tables'),
          const SizedBox(height: 10),
          LinkedProtocolTablesSection(tables: tables, initiallyCollapsed: true),
        ],
      ),
    );
  }

  Widget _buildAdditionalDataSurface(BuildContext context) {
    final protocol = completedProtocol.protocol;
    return _buildSectionSurface(
      context,
      key: const Key('completed-detail-additional-data'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(context, 'Additional Data'),
          if (protocol.files.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Attached Files',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...protocol.files.map(
              (file) => ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(file),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          if (protocol.additionalData.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...protocol.additionalData.map(
              (data) => _buildAdditionalDataCard(context, data),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionSurface(
    BuildContext context, {
    Key? key,
    required Widget child,
  }) {
    final expanded = MediaQuery.sizeOf(context).width >= 1000;
    return Card(
      key: key,
      margin: EdgeInsets.zero,
      child: Padding(padding: EdgeInsets.all(expanded ? 24 : 16), child: child),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  List<Widget> _buildGroupedSteps(BuildContext context) {
    final protocol = completedProtocol.protocol;
    final Map<String, List<ProtocolStep>> stepsByPhase = {};
    final sortedSteps = List<ProtocolStep>.from(protocol.steps)
      ..sort((a, b) => a.day.compareTo(b.day));

    bool hasPhases = sortedSteps.any(
      (s) => s.phaseName != null && s.phaseName!.isNotEmpty,
    );

    if (hasPhases) {
      final List<String> phaseOrder = [];
      for (var step in sortedSteps) {
        final phase = step.phaseName ?? 'General';
        if (!stepsByPhase.containsKey(phase)) {
          phaseOrder.add(phase);
          stepsByPhase[phase] = [];
        }
        stepsByPhase[phase]!.add(step);
      }

      List<Widget> widgets = [];
      int globalStepIdx = 0;
      for (var phase in phaseOrder) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              phase,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
          ),
        );

        for (var step in stepsByPhase[phase]!) {
          widgets.add(_buildTimelineStepCard(context, step, globalStepIdx));
          globalStepIdx++;
        }
      }
      return widgets;
    } else {
      final Map<int, List<ProtocolStep>> stepsByDay = {};
      for (var step in sortedSteps) {
        stepsByDay.putIfAbsent(step.day, () => []).add(step);
      }
      final sortedDays = stepsByDay.keys.toList()..sort();

      List<Widget> widgets = [];
      int globalStepIdx = 0;

      for (var day in sortedDays) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Day $day',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
          ),
        );

        for (var step in stepsByDay[day]!) {
          widgets.add(_buildTimelineStepCard(context, step, globalStepIdx));
          globalStepIdx++;
        }
      }
      return widgets;
    }
  }

  Widget _buildTimelineStepCard(
    BuildContext context,
    ProtocolStep step,
    int index,
  ) {
    final stepNotes = completedProtocol.notes
        .where((n) => n.stepId == step.id)
        .toList();
    return CustomPaint(
      key: Key('completed-detail-step-connector-${index + 1}'),
      painter: _CompletedStepTimelinePainter(
        drawAbove: index > 0,
        drawBelow: index < completedProtocol.protocol.steps.length - 1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  key: Key('completed-detail-step-number-${index + 1}'),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success, width: 2),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              key: Key('completed-detail-step-card-${index + 1}'),
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: AppColors.success.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title.isEmpty ? 'Untitled step' : step.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 18,
                        ),
                      ],
                    ),
                    if (step.instructions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        step.instructions,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    if (step.actionItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ProtocolStepActionsTable(
                        actions: step.actionItems,
                        trailingBuilder: (context, actionIndex) {
                          final timer = step.actionTimers[actionIndex];
                          if (timer == null) return null;
                          final timerLabel = timer >= 3600
                              ? '${timer ~/ 3600}h'
                              : timer >= 60
                              ? '${timer ~/ 60}m'
                              : '${timer}s';
                          return Chip(
                            avatar: const Icon(Icons.timer_outlined, size: 16),
                            label: Text(timerLabel),
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    ],
                    if (step.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ProtocolStepNotesTable(notes: step.notes),
                    ],
                    if (step.tableIds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(Icons.link, size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Linked tables',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinkedProtocolTablesSection(
                        tables: _linkedTablesForStep(step),
                      ),
                    ],
                    if (stepNotes.isNotEmpty) ...[
                      const Divider(height: 28),
                      const Text(
                        'Recorded notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      ..._buildNotesSection(stepNotes),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDataCard(
    BuildContext context,
    ProtocolAdditionalData data,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (data.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(data.description),
            ],
            if (data.link.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: data.link));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Link copied')));
                },
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18, color: AppColors.info),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.link,
                        style: const TextStyle(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (data.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildPhotoGrid(data.photoPaths),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> photoPaths) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photoPaths.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: buildLocalImage(photoPaths[index]),
      ),
    );
  }

  List<Widget> _buildNotesSection(List<StepNote> notes) {
    if (notes.isEmpty) return [];

    return [
      if (notes.any((n) => n.photoPaths.isNotEmpty))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            itemCount: notes.fold<int>(
              0,
              (sum, n) => sum + n.photoPaths.length,
            ),
            itemBuilder: (context, globalIdx) {
              int count = 0;
              int noteIdx = -1;
              int photoInNoteIdx = -1;
              String? path;

              for (int i = 0; i < notes.length; i++) {
                final n = notes[i];
                if (globalIdx < count + n.photoPaths.length) {
                  noteIdx = i + 1;
                  photoInNoteIdx = globalIdx - count + 1;
                  path = n.photoPaths[photoInNoteIdx - 1];
                  break;
                }
                count += n.photoPaths.length;
              }

              if (path == null) return const SizedBox.shrink();

              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: buildLocalImage(path),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$noteIdx.$photoInNoteIdx',
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ...notes.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final note = entry.value;
        if (note.note.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.note,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      }),
    ];
  }

  List<ProtocolTable> _linkedTablesForStep(ProtocolStep step) {
    final linkedTables = <ProtocolTable>[];
    for (final id in step.tableIds) {
      for (final table in completedProtocol.protocol.tables) {
        if (table.id == id) {
          linkedTables.add(table);
          break;
        }
      }
    }
    return linkedTables;
  }
}

class _CompletedStepTimelinePainter extends CustomPainter {
  const _CompletedStepTimelinePainter({
    required this.drawAbove,
    required this.drawBelow,
  });

  final bool drawAbove;
  final bool drawBelow;

  static const double _markerCenterX = 22;
  static const double _markerCenterY = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    if (drawAbove) {
      _drawDottedLine(
        canvas,
        paint,
        const Offset(_markerCenterX, 0),
        const Offset(_markerCenterX, _markerCenterY),
      );
    }
    if (drawBelow) {
      _drawDottedLine(
        canvas,
        paint,
        const Offset(_markerCenterX, _markerCenterY),
        Offset(_markerCenterX, size.height),
      );
    }
  }

  void _drawDottedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    const dashLength = 3.0;
    const gapLength = 4.0;
    var y = start.dy;
    while (y < end.dy) {
      final dashEnd = (y + dashLength).clamp(start.dy, end.dy);
      canvas.drawLine(Offset(start.dx, y), Offset(end.dx, dashEnd), paint);
      y += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _CompletedStepTimelinePainter oldDelegate) {
    return drawAbove != oldDelegate.drawAbove ||
        drawBelow != oldDelegate.drawBelow;
  }
}
