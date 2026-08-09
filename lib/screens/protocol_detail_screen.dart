import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/protocol.dart';
import '../models/active_protocol.dart';
import '../models/project.dart';
import '../models/protocol_additional_data.dart';
import '../models/protocol_step.dart';
import '../models/protocol_table.dart';
import '../models/protocol_publication.dart';
import '../data/completed_protocols_data.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/protocol_publication_service.dart';
import '../widgets/local_image.dart';
import '../widgets/sync_status_chip.dart';
import '../services/docx_export_service.dart';
import '../services/pdf_service.dart';
import '../services/export_service.dart';
import '../theme/app_colors.dart';
import '../widgets/protocol_step_actions_table.dart';
import '../widgets/protocol_step_notes_table.dart';
import '../widgets/protocol_table_preview.dart';
import '../widgets/phase_segmented_progress.dart';
import '../widgets/protocolflow_app_bar.dart';
import '../widgets/protocol_publication_widgets.dart';
import '../widgets/publication_status_chip.dart';
import '../widgets/responsive_layout.dart';
import '../utils/date_time_format.dart';
import 'run_protocol_screen.dart';
import 'create_protocol_screen.dart';

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

  @override
  void initState() {
    super.initState();
    protocol = widget.protocol;
    activeState = widget.activeState;
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
          ActiveProtocol? refreshed;
          if (activeProtocol?.protocol.id == protocol.id) {
            refreshed = activeProtocol;
          } else {
            for (final running in runningProtocols) {
              if (running.protocol.id == protocol.id) {
                refreshed = running;
                break;
              }
            }
          }
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

  void _editProtocol(
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
          // Sync with global state
          int idx = runningProtocols.indexWhere(
            (p) => p.protocol.id == protocol.id,
          );
          if (idx != -1) {
            runningProtocols[idx] = activeState!;
            savePersistentProtocols();
          }
        }
      });
    }
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
                PdfService.exportProtocolToPdf(protocol);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Export as Word (DOCX)'),
              onTap: () {
                Navigator.pop(context);
                const DocxExportService().exportProtocol(protocol);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export as ProtocolFlow file'),
              onTap: () {
                Navigator.pop(context);
                ExportService().exportSingleTemplate(protocol);
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

  void _refreshActiveState() {
    final updatedState = activeProtocol?.protocol.id == protocol.id
        ? activeProtocol
        : runningProtocols
              .where((p) => p.protocol.id == protocol.id)
              .cast<ActiveProtocol?>()
              .firstWhere((p) => p != null, orElse: () => activeState);
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
          if (!protocol.isTemplate)
            IconButton(
              icon: _publicationBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      protocol.publication?.status ==
                              ProtocolPublicationStatus.published
                          ? Icons.qr_code_2
                          : Icons.public,
                    ),
              onPressed: _publicationBusy ? null : _handlePublicationAction,
              tooltip:
                  protocol.publication?.status ==
                      ProtocolPublicationStatus.published
                  ? 'Share published protocol'
                  : 'Publish protocol',
            ),
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
      body: _buildDetailBody(),
      floatingActionButton:
          (fabLabel == 'Protocol Completed' || protocol.isTemplate)
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RunProtocolScreen(
                      protocol: protocol,
                      initialStepIndex: nextPhaseStartIdx,
                      finalStepIndex: nextPhaseEndIdx,
                    ),
                  ),
                ).then((_) => _refreshActiveState());
              },
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
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            desktop ? 24 : 12,
            desktop ? 24 : 16,
            desktop ? 24 : 12,
            96,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1800),
              child: _buildDetailWorkspace(desktop: desktop),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailWorkspace({required bool desktop}) {
    final regularTables = protocol.tables
        .where((table) => table.type != TableType.materialList)
        .toList();
    final hasAdditionalData =
        protocol.files.isNotEmpty || protocol.additionalData.isNotEmpty;

    final information = _buildProtocolInformationSection();
    final samples = protocol.samples.isEmpty ? null : _buildSamplesSection();
    final materials = _buildMaterialListSection();
    final steps = _buildStepsSurface();
    final tables = regularTables.isEmpty
        ? null
        : _buildTablesSurface(regularTables);
    final additionalData = hasAdditionalData
        ? _buildAdditionalDataSurface()
        : null;
    final phaseProgress = protocol.isTemplate
        ? null
        : _buildPhaseProgressSection();
    final publication = protocol.publication == null
        ? null
        : _buildPublicationSection();

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (publication != null) ...[publication, const SizedBox(height: 24)],
          if (phaseProgress != null) ...[
            phaseProgress,
            const SizedBox(height: 24),
          ],
          information,
          if (samples != null) ...[const SizedBox(height: 24), samples],
          const SizedBox(height: 24),
          materials,
          const SizedBox(height: 24),
          steps,
          if (tables != null) ...[const SizedBox(height: 24), tables],
          if (additionalData != null) ...[
            const SizedBox(height: 24),
            additionalData,
          ],
        ],
      );
    }

    final desktopColumns = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              information,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (publication != null) ...[publication, const SizedBox(height: 24)],
        if (phaseProgress != null) ...[
          phaseProgress,
          const SizedBox(height: 24),
        ],
        desktopColumns,
      ],
    );
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
        ],
      ),
    );
  }

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

  Widget _buildSamplesSection() {
    return _buildSectionSurface(
      key: const Key('detail-samples'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Samples'),
          const SizedBox(height: 12),
          ...protocol.samples.map(
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

  Widget _buildMaterialListSection() {
    return _buildSectionSurface(
      key: const Key('detail-materials'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Material List'),
          const SizedBox(height: 10),
          if (protocol.materialListTable != null)
            LinkedProtocolTablesSection(tables: [protocol.materialListTable!])
          else
            _buildEmptyState('No material list table linked.'),
        ],
      ),
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
          if (protocol.files.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Attached Files',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _buildFileGrid(protocol.files),
          ],
          if (protocol.additionalData.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...protocol.additionalData.map(_buildAdditionalDataCard),
          ],
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

  Widget _buildFileGrid(List<String> files) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final fileName = files[index];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 32),
              const SizedBox(height: 8),
              Text(
                fileName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
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
