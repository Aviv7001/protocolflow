import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/protocol.dart';
import '../models/active_protocol.dart';
import '../models/project.dart';
import '../models/protocol_additional_data.dart';
import '../models/protocol_step.dart';
import '../models/protocol_table.dart';
import '../models/protocol_publication.dart';
import '../models/protocol_run.dart';
import '../data/completed_protocols_data.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/protocol_publication_service.dart';
import '../services/protocol_run_service.dart';
import '../widgets/local_image.dart';
import '../widgets/sync_status_chip.dart';
import '../services/docx_export_service.dart';
import '../services/pdf_service.dart';
import '../services/export_service.dart';
import '../widgets/protocol_export_dialog.dart';
import '../theme/app_colors.dart';
import '../widgets/protocol_step_actions_table.dart';
import '../widgets/protocol_step_notes_table.dart';
import '../widgets/protocol_table_preview.dart';
import '../widgets/phase_segmented_progress.dart';
import '../widgets/protocolflow_app_bar.dart';
import '../widgets/protocolflow_ui.dart';
import '../widgets/protocol_publication_widgets.dart';
import '../widgets/publication_status_chip.dart';
import '../widgets/responsive_layout.dart';
import '../utils/date_time_format.dart';
import '../utils/protocol_id.dart';
import 'run_protocol_screen.dart';
import 'create_protocol_screen.dart';
import 'completed_protocol_detail_screen.dart';

class ProtocolDetailScreen extends StatefulWidget {
  final Protocol protocol;
  final ActiveProtocol? activeState;

  const ProtocolDetailScreen({
    super.key,
    required this.protocol,
    this.activeState,
  });

  @override
  State<ProtocolDetailScreen> createState() => _ProtocolDetailScreenState();
}

class _ProtocolMetadataItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProtocolMetadataItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
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
              softWrap: true,
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
}

class _ProtocolDetailScreenState extends State<ProtocolDetailScreen> {
  late Protocol protocol;
  ActiveProtocol? activeState;
  List<Project> _projects = [];
  bool _publicationBusy = false;
  bool _duplicateBusy = false;

  @override
  void initState() {
    super.initState();
    protocol = widget.protocol;
    activeState = widget.activeState ?? _runningStateFor(protocol.id);
    _loadProjects();
  }

  ActiveProtocol? _runningStateFor(String protocolId) {
    for (final run in protocolRuns) {
      if (run.protocolId == protocolId &&
          run.status != ProtocolRunStatus.completed) {
        return run.toActiveProtocol();
      }
    }
    return null;
  }

  ProtocolRun? _runForId(String runId) {
    for (final run in protocolRuns) {
      if (run.id == runId) return run;
    }
    return null;
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
        content: Text(
          protocol.publication?.isPublic == true
              ? 'Delete this protocol from your library? Its published copy will remain available until you unpublish or delete it separately.'
              : 'Are you sure you want to delete this protocol from your library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldNavigator = Navigator.of(context);
              final dialogNavigator = Navigator.of(dialogContext);

              await StorageService().deleteProtocol(protocol);

              if (mounted) {
                if (dialogContext.mounted) {
                  dialogNavigator.pop(); // Close dialog
                }
                scaffoldNavigator.pop(); // Go back to list
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePublicationAction() async {
    final publication = protocol.publication;
    if (publication?.status == ProtocolPublicationStatus.published) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share published protocol'),
          content: SingleChildScrollView(
            child: PublishedProtocolQrCard(publication: publication!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    await _publishProtocol();
  }

  Future<void> _publishProtocol() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _showPublicationMessage(
        'Sign in with Google before publishing a protocol.',
      );
      return;
    }
    final request = await showDialog<PublishProtocolRequest>(
      context: context,
      builder: (context) => PublishProtocolDialog(
        protocol: protocol,
        defaultAuthorName: user.displayName ?? user.email,
      ),
    );
    if (request == null || !mounted) return;
    setState(() => _publicationBusy = true);
    try {
      final publication = await ProtocolPublicationService.instance.publish(
        protocol: protocol,
        ownerGoogleUserId: user.googleUserId,
        authorName: user.displayName ?? user.email,
        anonymous: request.anonymous,
      );
      var updated = protocol.copyWith(
        publication: publication,
        syncStatus: ProtocolSyncStatus.modified,
      );
      updated = await DriveSyncService.instance.syncProtocolAfterLocalSave(
        updated,
      );
      if (!mounted) return;
      setState(() {
        protocol = updated;
        _publicationBusy = false;
      });
      _showPublicationMessage(
        publication.version == 1
            ? 'Protocol published. Its QR code is ready to share.'
            : 'Published version ${publication.version}. The existing QR code still works.',
      );
    } on PublicationException catch (error) {
      if (!mounted) return;
      setState(() => _publicationBusy = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            error.sharingBlocked
                ? 'Public sharing unavailable'
                : 'Could not publish',
          ),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _unpublishProtocol() async {
    final publication = protocol.publication;
    if (publication == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpublish protocol?'),
        content: const Text(
          'The QR code and sharing link will stop working. The Drive file will remain private so it can be published again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpublish'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _publicationBusy = true);
    try {
      final unpublished = await ProtocolPublicationService.instance.unpublish(
        publication,
      );
      var updated = protocol.copyWith(
        publication: unpublished,
        syncStatus: ProtocolSyncStatus.modified,
      );
      updated = await DriveSyncService.instance.syncProtocolAfterLocalSave(
        updated,
      );
      if (!mounted) return;
      setState(() {
        protocol = updated;
        _publicationBusy = false;
      });
      _showPublicationMessage('Public access was removed.');
    } on PublicationException catch (error) {
      if (!mounted) return;
      setState(() => _publicationBusy = false);
      _showPublicationMessage(error.message);
    }
  }

  Future<void> _deletePublishedCopy() async {
    final publication = protocol.publication;
    if (publication == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete published copy?'),
        content: const Text(
          'This permanently deletes the shared Drive file. Its QR code cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete copy'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _publicationBusy = true);
    try {
      await ProtocolPublicationService.instance.deletePublishedCopy(
        publication,
      );
      await StorageService().clearPublicationReferences(
        publication.publicationId,
      );
      await loadPersistentProtocols();
      final updated = protocol.copyWith(
        clearPublication: true,
        syncStatus: ProtocolSyncStatus.modified,
      );
      if (!mounted) return;
      setState(() {
        protocol = updated;
        if (activeState != null) {
          final refreshed = _runningStateFor(protocol.id);
          activeState = refreshed ?? activeState!.copyWith(protocol: updated);
        }
        _publicationBusy = false;
      });
      _showPublicationMessage(
        'Published Drive copy and attached QR links deleted.',
      );
    } on PublicationException catch (error) {
      if (!mounted) return;
      setState(() => _publicationBusy = false);
      _showPublicationMessage(error.message);
    }
  }

  void _showPublicationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editProtocol(
    BuildContext context, {
    String? targetPhase,
    bool isAddingPhase = false,
  }) async {
    final updatedProtocol = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProtocolScreen(
          initialProtocol: protocol,
          lockedStepIds: activeState?.completedStepIds.toList(),
          targetPhase: targetPhase,
          isAddingPhase: isAddingPhase,
        ),
      ),
    );

    if (updatedProtocol != null && updatedProtocol is Protocol) {
      setState(() {
        protocol = updatedProtocol;
        if (activeState != null) {
          activeState = activeState!.copyWith(protocol: updatedProtocol);
          final runId = activeState!.runId;
          final run = runId == null ? null : _runForId(runId);
          if (run != null) {
            ProtocolRunService.instance
                .updateRun(run.copyWith(protocolSnapshot: updatedProtocol))
                .then((_) => loadPersistentProtocols());
          }
        }
      });
    }
  }

  Future<void> _editCopy() async {
    if (_duplicateBusy) return;

    final shouldDuplicate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Duplicate Protocol?'),
        content: Text(
          'This will create a separate copy named "${protocol.title} (copy)". '
          'The original protocol will not be changed, and the copy will open '
          'in Protocol Detail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
    if (shouldDuplicate != true || !mounted) return;

    setState(() => _duplicateBusy = true);

    try {
      final now = DateTime.now();
      final signedInUser = AuthService.instance.currentUser;
      final storageService = StorageService();
      final protocols = await storageService.loadProtocols();

      var copyId = generateProtocolId(
        date: now,
        initials: signedInUser?.initials,
      );
      while (protocols.any((saved) => saved.id == copyId)) {
        copyId = generateProtocolId(
          date: now,
          initials: signedInUser?.initials,
        );
      }

      final copy = Protocol(
        id: copyId,
        title: '${protocol.title} (copy)',
        objective: protocol.objective,
        description: protocol.description,
        ownerId: signedInUser?.googleUserId ?? protocol.ownerId,
        projectId: protocol.projectId,
        createdByName:
            signedInUser?.displayName ??
            signedInUser?.email ??
            protocol.createdByName,
        createdAt: now,
        updatedAt: now,
        schemaVersion: Protocol.currentSchemaVersion,
        syncStatus: signedInUser == null
            ? ProtocolSyncStatus.localOnly
            : ProtocolSyncStatus.modified,
        materials: protocol.materials.map((item) => item.copyWith()).toList(),
        materialListTableId: protocol.materialListTableId,
        samples: List<String>.from(protocol.samples),
        files: List<String>.from(protocol.files),
        imageNames: List<String>.from(protocol.imageNames),
        informationTableIds: List<String>.from(protocol.informationTableIds),
        informationImagePaths: List<String>.from(
          protocol.informationImagePaths,
        ),
        steps: protocol.steps.map((step) => step.deepCopy()).toList(),
        tables: protocol.tables.map((table) => table.deepCopy()).toList(),
        additionalData: protocol.additionalData
            .map((data) => data.deepCopy())
            .toList(),
        isTemplate: false,
      );

      protocols.add(copy);
      await storageService.saveProtocols(protocols);
      if (!mounted) return;

      setState(() {
        protocol = copy;
        activeState = null;
        _duplicateBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _duplicateBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create protocol copy: $error')),
      );
    }
  }

  Future<void> _useTemplate(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProtocolScreen(initialProtocol: protocol),
      ),
    );
  }

  Future<void> _exportProtocol(BuildContext context) async {
    final format = await showDialog<ProtocolExportFormat>(
      context: context,
      builder: (_) => const ProtocolExportDialog(),
    );
    if (!context.mounted || format == null) return;
    switch (format) {
      case ProtocolExportFormat.pdf:
        await PdfService.exportProtocolToPdf(protocol);
      case ProtocolExportFormat.docx:
        await const DocxExportService().exportProtocol(protocol);
      case ProtocolExportFormat.protocolFlow:
        await ExportService().exportSingleTemplate(protocol);
    }
  }

  void _refreshActiveState() {
    final updatedState = _runningStateFor(protocol.id) ?? activeState;
    setState(() => activeState = updatedState);
  }

  @override
  Widget build(BuildContext context) {
    final sortedSteps = protocol.sortedSteps;

    final bool hasPhases = sortedSteps.any(
      (s) => s.phaseName != null && s.phaseName!.isNotEmpty,
    );
    String fabLabel = 'Run Protocol';
    int? nextPhaseStartIdx;
    int? nextPhaseEndIdx;

    if (hasPhases) {
      final Map<String, List<ProtocolStep>> stepsByPhase = {};
      final List<String> phaseOrder = [];
      for (var step in sortedSteps) {
        final phase = step.phaseName ?? 'General';
        if (!stepsByPhase.containsKey(phase)) {
          phaseOrder.add(phase);
          stepsByPhase[phase] = [];
        }
        stepsByPhase[phase]!.add(step);
      }

      int currentGlobalIdx = 0;
      bool foundNext = false;
      for (var phase in phaseOrder) {
        final phaseSteps = stepsByPhase[phase]!;
        final bool isPhaseDone =
            activeState != null &&
            phaseSteps.every(
              (s) => activeState!.completedStepIds.contains(s.id),
            );

        if (!isPhaseDone) {
          fabLabel = 'Run $phase';
          nextPhaseStartIdx = currentGlobalIdx;
          nextPhaseEndIdx = currentGlobalIdx + phaseSteps.length - 1;
          foundNext = true;
          break;
        }
        currentGlobalIdx += phaseSteps.length;
      }

      if (!foundNext) {
        fabLabel = 'Protocol Completed';
      }
    } else {
      // Handle Day grouping if no phases but multiple days
      final Map<int, List<ProtocolStep>> stepsByDay = {};
      for (var step in sortedSteps) {
        stepsByDay.putIfAbsent(step.day, () => []).add(step);
      }
      final sortedDays = stepsByDay.keys.toList()..sort();

      if (sortedDays.length > 1) {
        int currentGlobalIdx = 0;
        bool foundNext = false;
        for (var day in sortedDays) {
          final daySteps = stepsByDay[day]!;
          final bool isDayDone =
              activeState != null &&
              daySteps.every(
                (s) => activeState!.completedStepIds.contains(s.id),
              );

          if (!isDayDone) {
            fabLabel = 'Run Day $day';
            nextPhaseStartIdx = currentGlobalIdx;
            nextPhaseEndIdx = currentGlobalIdx + daySteps.length - 1;
            foundNext = true;
            break;
          }
          currentGlobalIdx += daySteps.length;
        }
        if (!foundNext) fabLabel = 'Protocol Completed';
      }
    }

    if (activeState != null) {
      fabLabel = 'Resume';
      nextPhaseStartIdx = null;
      nextPhaseEndIdx = null;
    }

    return Scaffold(
      appBar: ProtocolFlowAppBar(
        title: 'Protocol Detail',
        actions: [
          if (activeState == null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editProtocol(context),
              tooltip: 'Edit',
            ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            onPressed: _duplicateBusy ? null : _editCopy,
            tooltip: 'Duplicate protocol',
          ),
          if (!protocol.isTemplate)
            IconButton(
              icon: const Icon(Icons.public_outlined),
              onPressed: _publicationBusy ? null : _handlePublicationAction,
              tooltip:
                  protocol.publication?.status ==
                      ProtocolPublicationStatus.published
                  ? 'Share published protocol'
                  : 'Publish protocol',
            ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _publicationBusy ? null : () => _exportProtocol(context),
            tooltip: 'Export',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _publicationBusy ? null : () => _confirmDelete(context),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _buildDetailBody(),
      floatingActionButton: protocol.isTemplate
          ? FloatingActionButton.extended(
              onPressed: () => _useTemplate(context),
              label: const Text('Use template'),
              icon: const Icon(Icons.copy_all_outlined),
            )
          : (fabLabel == 'Protocol Completed' || activeState != null)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openRun(
                initialStepIndex: nextPhaseStartIdx,
                finalStepIndex: nextPhaseEndIdx,
              ),
              label: Text(fabLabel),
              icon: const Icon(Icons.play_arrow),
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

  Widget _buildDetailBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= ProtocolFlowBreakpoints.desktop;
        if (desktop) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: SizedBox(
              height: constraints.maxHeight - 48,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: _buildDetailWorkspace(desktop: true),
                ),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 96),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: _buildDetailWorkspace(desktop: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailWorkspace({required bool desktop}) {
    final protocolTables = <ProtocolTable>[
      if (protocol.materialListTable != null) protocol.materialListTable!,
      if (protocol.sampleListTable != null) protocol.sampleListTable!,
      ...protocol.tables.where(
        (table) =>
            table.type != TableType.materialList && !isSampleListTable(table),
      ),
    ];
    final hasAdditionalData = protocol.additionalData.isNotEmpty;

    final information = _buildProtocolInformationSection();
    final steps = _buildStepsSurface();
    final tables = protocolTables.isEmpty
        ? null
        : _buildTablesSurface(protocolTables);
    final images = protocol.files.isEmpty ? null : _buildImagesSurface();
    final additionalData = hasAdditionalData
        ? _buildAdditionalDataSurface()
        : null;
    final phaseProgress = protocol.isTemplate
        ? null
        : _buildPhaseProgressSection();
    final publication = protocol.publication == null
        ? null
        : _buildPublicationSection();
    final currentRun = activeState == null ? null : _buildCurrentRunSection();
    final previousRuns =
        protocolRuns
            .where(
              (run) =>
                  run.protocolId == protocol.id &&
                  run.status == ProtocolRunStatus.completed,
            )
            .toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
              a.completedAt ?? a.updatedAt,
            ),
          );
    final previousRunsSection = previousRuns.isEmpty
        ? null
        : _buildPreviousRunsSection(previousRuns);

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (currentRun != null) ...[currentRun, const SizedBox(height: 24)],
          if (publication != null) ...[publication, const SizedBox(height: 24)],
          if (phaseProgress != null) ...[
            phaseProgress,
            const SizedBox(height: 24),
          ],
          information,
          const SizedBox(height: 24),
          if (tables != null) ...[tables, const SizedBox(height: 24)],
          if (images != null) ...[images, const SizedBox(height: 24)],
          steps,
          if (additionalData != null) ...[
            const SizedBox(height: 24),
            additionalData,
          ],
          if (previousRunsSection != null) ...[
            const SizedBox(height: 24),
            previousRunsSection,
          ],
        ],
      );
    }

    final desktopColumns = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            key: const Key('detail-left-scroll'),
            primary: false,
            padding: const EdgeInsets.only(right: 8, bottom: 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (currentRun != null) ...[
                  currentRun,
                  const SizedBox(height: 24),
                ],
                if (publication != null) ...[
                  publication,
                  const SizedBox(height: 24),
                ],
                if (phaseProgress != null) ...[
                  phaseProgress,
                  const SizedBox(height: 24),
                ],
                information,
                if (tables != null) ...[const SizedBox(height: 24), tables],
                if (images != null) ...[const SizedBox(height: 24), images],
                if (additionalData != null) ...[
                  const SizedBox(height: 24),
                  additionalData,
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            key: const Key('detail-right-scroll'),
            primary: false,
            padding: const EdgeInsets.only(left: 8, bottom: 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                steps,
                if (previousRunsSection != null) ...[
                  const SizedBox(height: 24),
                  previousRunsSection,
                ],
              ],
            ),
          ),
        ),
      ],
    );

    return desktopColumns;
  }

  Widget _buildCurrentRunSection() {
    final state = activeState!;
    final steps = protocol.sortedSteps;
    final completed = state.completedStepIds.length;
    final total = steps.length;
    final currentIndex = state.currentStepIndex;
    final current = currentIndex >= 0 && currentIndex < steps.length
        ? steps[currentIndex]
        : null;
    final run = state.runId == null ? null : _runForId(state.runId!);
    final isPaused =
        run?.status == ProtocolRunStatus.paused ||
        (run == null && activeProtocol?.protocol.id != protocol.id);
    final status = isPaused ? 'Paused' : 'Running';
    return _buildSectionSurface(
      key: const Key('detail-current-run'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Current Run'),
          const SizedBox(height: 10),
          Text(
            current == null
                ? '$status | Ready to continue'
                : '$status | Step ${currentIndex + 1}: ${current.title}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: total == 0 ? 0 : (completed / total).clamp(0, 1),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Text(
            '$completed of $total steps completed',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _openRun(),
              icon: const Icon(Icons.play_arrow),
              label: Text(status == 'Paused' ? 'Resume' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousRunsSection(List<ProtocolRun> runs) {
    return _buildSectionSurface(
      key: const Key('detail-previous-runs'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Previous Runs'),
          const SizedBox(height: 8),
          for (final run in runs.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
              title: Text(
                run.protocolSnapshot.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Completed ${formatDate(run.completedAt ?? run.updatedAt)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CompletedProtocolDetailScreen.fromRun(run: run),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openRun({int? initialStepIndex, int? finalStepIndex}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RunProtocolScreen(
          protocol: protocol,
          initialStepIndex: activeState == null ? initialStepIndex : null,
          finalStepIndex: activeState == null ? finalStepIndex : null,
        ),
      ),
    );
    _refreshActiveState();
  }

  Widget _buildPublicationSection() {
    final publication = protocol.publication!;
    final user = AuthService.instance.currentUser;
    final canManage = user?.googleUserId == publication.ownerGoogleUserId;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Publication'),
        const SizedBox(height: 12),
        PublicationSummary(publication: publication),
        const SizedBox(height: 12),
        Text(
          publication.status == ProtocolPublicationStatus.changesUnpublished
              ? 'The public QR still opens version ${publication.version}. Publish the update when the current edits are ready.'
              : publication.status == ProtocolPublicationStatus.unpublished
              ? 'Public access is disabled. The Drive copy is private.'
              : 'Anyone with this link can preview and import a read-only snapshot.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (canManage) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (publication.status != ProtocolPublicationStatus.published)
                FilledButton.icon(
                  onPressed: _publicationBusy ? null : _publishProtocol,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    publication.status == ProtocolPublicationStatus.unpublished
                        ? 'Publish again'
                        : 'Publish update',
                  ),
                ),
              if (publication.isPublic)
                OutlinedButton.icon(
                  onPressed: _publicationBusy ? null : _unpublishProtocol,
                  icon: const Icon(Icons.public_off_outlined),
                  label: const Text('Unpublish'),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: _publicationBusy ? null : _deletePublishedCopy,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete published copy'),
              ),
            ],
          ),
        ],
      ],
    );
    return _buildSectionSurface(
      key: const Key('detail-publication'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!publication.isPublic || constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                if (publication.isPublic) ...[
                  const SizedBox(height: 18),
                  PublishedProtocolQrCard(publication: publication),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 24),
              PublishedProtocolQrCard(publication: publication, qrSize: 150),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhaseProgressSection() {
    return _buildSectionSurface(
      key: const Key('detail-phase-progress-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Phase Progress'),
          const SizedBox(height: 14),
          PhaseSegmentedProgress(
            key: const Key('detail-phase-progress'),
            steps: protocol.sortedSteps,
            currentStepIndex: activeState?.currentStepIndex ?? -1,
            completedStepIds: activeState?.completedStepIds ?? const <String>{},
            segmentKeyPrefix: 'detail-phase-progress',
            onAddPhase: () => _editProtocol(context, isAddingPhase: true),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolInformationSection() {
    return _buildSectionSurface(
      key: const Key('detail-protocol-information'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Protocol Information'),
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
                icon: protocol.isTemplate
                    ? Icons.copy_all_outlined
                    : Icons.description_outlined,
                label: protocol.isTemplate ? 'TEMPLATE' : 'PROTOCOL',
              ),
              SyncStatusChip(status: protocol.syncStatus, compact: true),
              if (protocol.publication != null)
                PublicationStatusChip(
                  status: protocol.publication!.status,
                  compact: true,
                ),
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
              _ProtocolMetadataItem(
                icon: Icons.calendar_today_outlined,
                text: 'Created on: ${formatDate(protocol.createdAt)}',
              ),
              _ProtocolMetadataItem(
                icon: Icons.person_outline,
                text:
                    'Created by: '
                    '${protocol.createdByName ?? 'Unknown user'}',
              ),
            ],
          ),
          const Divider(height: 32),
          _buildReadOnlyField('Objective', protocol.objective),
          const SizedBox(height: 18),
          _buildReadOnlyField('Description', protocol.description),
          if (_informationTables.isNotEmpty ||
              _informationImages.isNotEmpty) ...[
            const Divider(height: 32),
            if (_informationTables.isNotEmpty) ...[
              const Text(
                'Linked tables',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              LinkedProtocolTablesSection(tables: _informationTables),
            ],
            if (_informationImages.isNotEmpty) ...[
              if (_informationTables.isNotEmpty) const SizedBox(height: 18),
              const Text(
                'Linked images',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _buildProtocolImageGrid(_informationImages),
            ],
          ],
        ],
      ),
    );
  }

  List<ProtocolTable> get _informationTables => protocol.informationTableIds
      .map((id) => protocol.tables.where((table) => table.id == id).firstOrNull)
      .whereType<ProtocolTable>()
      .toList();

  List<String> get _informationImages =>
      protocol.informationImagePaths.where(protocol.files.contains).toList();

  Widget _buildDetailBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildStepsSurface() {
    return _buildSectionSurface(
      key: const Key('detail-steps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Steps'),
          const SizedBox(height: 8),
          if (protocol.steps.isEmpty)
            _buildEmptyState('No steps added.')
          else
            ..._buildGroupedSteps(context),
        ],
      ),
    );
  }

  Widget _buildTablesSurface(List<ProtocolTable> tables) {
    return _buildSectionSurface(
      key: const Key('detail-tables'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Tables'),
          const SizedBox(height: 10),
          LinkedProtocolTablesSection(tables: tables, initiallyCollapsed: true),
        ],
      ),
    );
  }

  Widget _buildAdditionalDataSurface() {
    return _buildSectionSurface(
      key: const Key('detail-additional-data'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Additional Data'),
          if (protocol.additionalData.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...protocol.additionalData.map(_buildAdditionalDataCard),
          ],
        ],
      ),
    );
  }

  Widget _buildImagesSurface() {
    return _buildSectionSurface(
      key: const Key('detail-images'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Images / Figures'),
          const SizedBox(height: 12),
          _buildProtocolImageGrid(protocol.files),
        ],
      ),
    );
  }

  Widget _buildSectionSurface({Key? key, required Widget child}) {
    final expanded = MediaQuery.sizeOf(context).width >= 1000;
    return Card(
      key: key,
      margin: EdgeInsets.zero,
      child: Padding(padding: EdgeInsets.all(expanded ? 24 : 16), child: child),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildEmptyState(String message) {
    return ProtocolFlowEmptyState(message: message);
  }

  List<Widget> _buildGroupedSteps(BuildContext context) {
    final Map<String, List<ProtocolStep>> stepsByPhase = {};
    final sortedSteps = protocol.sortedSteps;

    bool hasPhases = sortedSteps.any(
      (s) => s.phaseName != null && s.phaseName!.isNotEmpty,
    );

    if (hasPhases) {
      // Group by phase name in order of appearance
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
      int currentGlobalIdx = 0;
      for (var phase in phaseOrder) {
        final phaseSteps = stepsByPhase[phase]!;
        final startIdx = currentGlobalIdx;
        final endIdx = currentGlobalIdx + phaseSteps.length - 1;

        final bool isPhaseDone =
            activeState != null &&
            phaseSteps.every(
              (s) => activeState!.completedStepIds.contains(s.id),
            );

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: isPhaseDone
                  ? BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            phase,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (isPhaseDone) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isPhaseDone && !protocol.isTemplate)
                    Row(
                      children: [
                        if (activeState != null)
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            onPressed: () =>
                                _editProtocol(context, targetPhase: phase),
                            tooltip: 'Edit Phase',
                          ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RunProtocolScreen(
                                  protocol: protocol,
                                  initialStepIndex: startIdx,
                                  finalStepIndex: endIdx,
                                ),
                              ),
                            ).then((_) => _refreshActiveState());
                          },
                          icon: const Icon(Icons.play_circle_outline, size: 20),
                          label: Text(
                            MediaQuery.sizeOf(context).width < 600
                                ? 'Run'
                                : 'Run $phase',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );

        for (var step in phaseSteps) {
          widgets.add(_buildTimelineStepCard(context, step, currentGlobalIdx));
          currentGlobalIdx++;
        }
      }
      return widgets;
    } else {
      // Fallback to Day grouping
      final Map<int, List<ProtocolStep>> stepsByDay = {};
      for (var step in sortedSteps) {
        stepsByDay.putIfAbsent(step.day, () => []).add(step);
      }
      final sortedDays = stepsByDay.keys.toList()..sort();

      List<Widget> widgets = [];
      int currentGlobalIdx = 0;

      for (var day in sortedDays) {
        final daySteps = stepsByDay[day]!;
        final startIdx = currentGlobalIdx;
        final endIdx = currentGlobalIdx + daySteps.length - 1;

        final bool isDayDone =
            activeState != null &&
            daySteps.every((s) => activeState!.completedStepIds.contains(s.id));

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Day $day',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    if (isDayDone) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 18,
                      ),
                    ],
                  ],
                ),
                if (!protocol.isTemplate)
                  Row(
                    children: [
                      if (activeState != null && !isDayDone)
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onPressed: () => _editProtocol(context),
                          tooltip: 'Edit Protocol',
                        ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RunProtocolScreen(
                                protocol: protocol,
                                initialStepIndex: startIdx,
                                finalStepIndex: endIdx,
                              ),
                            ),
                          ).then((_) => _refreshActiveState());
                        },
                        icon: const Icon(Icons.play_circle_outline, size: 20),
                        label: Text(
                          'Run Day $day',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );

        for (var step in daySteps) {
          widgets.add(_buildTimelineStepCard(context, step, currentGlobalIdx));
          currentGlobalIdx++;
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
    final bool isDone =
        activeState != null && activeState!.completedStepIds.contains(step.id);

    return CustomPaint(
      key: Key('detail-step-connector-${index + 1}'),
      painter: _DetailStepTimelinePainter(
        drawAbove: index > 0,
        drawBelow: index < protocol.sortedSteps.length - 1,
        completed: isDone,
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
                  key: Key('detail-step-number-${index + 1}'),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.success.withValues(alpha: 0.14)
                        : AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? AppColors.success : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(
                          Icons.check,
                          size: 17,
                          color: AppColors.success,
                        )
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.onPrimaryContainer,
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
              key: Key('detail-step-card-${index + 1}'),
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: isDone ? AppColors.success.withValues(alpha: 0.08) : null,
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDone ? AppColors.success : null,
                            ),
                          ),
                        ),
                        if (isDone)
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
                        style: TextStyle(
                          color: isDone ? AppColors.textSecondary : null,
                        ),
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
                    if (_linkedImagesForStep(step).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Linked images',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildProtocolImageGrid(_linkedImagesForStep(step)),
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

  List<ProtocolTable> _linkedTablesForStep(ProtocolStep step) {
    final linkedTables = <ProtocolTable>[];
    for (final id in step.tableIds) {
      for (final table in protocol.tables) {
        if (table.id == id) {
          linkedTables.add(table);
          break;
        }
      }
    }
    return linkedTables;
  }

  List<String> _linkedImagesForStep(ProtocolStep step) {
    return step.attachedFiles.where(protocol.files.contains).toList();
  }

  String _protocolImageName(String path) {
    final index = protocol.files.indexOf(path);
    return index >= 0 &&
            index < protocol.imageNames.length &&
            protocol.imageNames[index].trim().isNotEmpty
        ? protocol.imageNames[index].trim()
        : index == -1
        ? 'Image'
        : 'Image ${index + 1}';
  }

  Future<void> _showProtocolImagePreview(String path) async {
    final index = protocol.files.indexOf(path);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${index + 1}. ${_protocolImageName(path)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColoredBox(
                          color: Colors.white,
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            child: buildLocalImage(path, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolImageGrid(List<String> paths) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 112.0;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: paths.map((path) {
            final index = protocol.files.indexOf(path);
            return SizedBox(
              width: itemWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: Key('preview-protocol-image-${index + 1}'),
                        onTap: () => _showProtocolImagePreview(path),
                        child: ColoredBox(
                          color: Colors.white,
                          child: buildLocalImage(path, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${index + 1}. ${_protocolImageName(path)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAdditionalDataCard(ProtocolAdditionalData data) {
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
                    const Icon(Icons.link, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.link,
                        style: const TextStyle(color: Colors.blue),
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
}

class _DetailStepTimelinePainter extends CustomPainter {
  const _DetailStepTimelinePainter({
    required this.drawAbove,
    required this.drawBelow,
    required this.completed,
  });

  final bool drawAbove;
  final bool drawBelow;
  final bool completed;

  static const double _markerCenterX = 22;
  static const double _markerCenterY = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (completed ? AppColors.success : AppColors.primary).withValues(
        alpha: 0.55,
      )
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
  bool shouldRepaint(covariant _DetailStepTimelinePainter oldDelegate) {
    return drawAbove != oldDelegate.drawAbove ||
        drawBelow != oldDelegate.drawBelow ||
        completed != oldDelegate.completed;
  }
}
