import 'package:flutter/material.dart';

import '../models/active_protocol.dart';
import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_step.dart';
import '../theme/app_colors.dart';
import '../utils/date_time_format.dart';
import 'phase_segmented_progress.dart';
import 'sync_status_chip.dart';

class RunningProtocolSummaryCard extends StatelessWidget {
  const RunningProtocolSummaryCard({
    super.key,
    required this.state,
    required this.detail,
    required this.progressValue,
    required this.onTap,
    this.project,
    this.action,
    this.keyPrefix = 'library',
    this.phaseKeyPrefix,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.compact = false,
    this.compactActionLabel,
    this.onCompactAction,
    this.onTerminate,
    this.dashboardCompact = false,
    this.paused = false,
  });

  final ActiveProtocol state;
  final String detail;
  final String progressValue;
  final Project? project;
  final Widget? action;
  final VoidCallback onTap;
  final String keyPrefix;
  final String? phaseKeyPrefix;
  final EdgeInsetsGeometry margin;
  final bool compact;
  final String? compactActionLabel;
  final VoidCallback? onCompactAction;
  final VoidCallback? onTerminate;
  final bool dashboardCompact;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final protocol = state.protocol;
    final sortedSteps = protocol.sortedSteps;
    final totalSteps = sortedSteps.length;
    final progress = totalSteps == 0
        ? 0.0
        : state.completedStepIds.length / totalSteps;
    final hasPhases = sortedSteps.any(
      (step) => step.phaseName?.trim().isNotEmpty ?? false,
    );
    final resolvedPhaseKeyPrefix = phaseKeyPrefix ?? keyPrefix;

    if (dashboardCompact) {
      return _buildDashboardCard(context, progress: progress);
    }

    if (compact) {
      return _buildCompactCard(
        context,
        sortedSteps: sortedSteps,
        progress: progress,
        hasPhases: hasPhases,
        resolvedPhaseKeyPrefix: resolvedPhaseKeyPrefix,
      );
    }

    return Card(
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              SizedBox(
                key: Key('$keyPrefix-tags-placeholder-${protocol.id}'),
                height: 24,
              ),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              if (hasPhases)
                PhaseSegmentedProgress(
                  key: Key(
                    '$resolvedPhaseKeyPrefix-phase-progress-${protocol.id}',
                  ),
                  steps: sortedSteps,
                  currentStepIndex: state.currentStepIndex,
                  completedStepIds: state.completedStepIds,
                  segmentKeyPrefix:
                      '$resolvedPhaseKeyPrefix-phase-progress-${protocol.id}',
                )
              else
                LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final progressMetadata = _RunningMetadata(
                    label: 'Progress',
                    value: progressValue,
                    icon: Icons.donut_large_outlined,
                  );
                  final startedMetadata = _RunningMetadata(
                    label: 'Started on',
                    value: formatDate(state.startedAt),
                    icon: Icons.calendar_today_outlined,
                    alignEnd: constraints.maxWidth >= 520,
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        progressMetadata,
                        const SizedBox(height: 14),
                        startedMetadata,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: progressMetadata),
                      const SizedBox(width: 24),
                      Expanded(child: startedMetadata),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'PROJECT',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  key: Key('$keyPrefix-project-badge-${protocol.id}'),
                  child: _RunningBadge(
                    label: project?.name ?? 'Unassigned',
                    icon: project == null
                        ? Icons.folder_off_outlined
                        : Icons.folder_outlined,
                    color: project == null
                        ? AppColors.textSecondary
                        : Color(project!.colorValue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required double progress}) {
    final protocol = state.protocol;
    final statusColor = paused ? AppColors.textSecondary : AppColors.info;
    return Card(
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      protocol.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: paused ? 'Paused' : 'Running',
                    child: Icon(
                      paused
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Started on ${formatDate(state.startedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    progressValue,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(
    BuildContext context, {
    required List<ProtocolStep> sortedSteps,
    required double progress,
    required bool hasPhases,
    required String resolvedPhaseKeyPrefix,
  }) {
    final protocol = state.protocol;
    final projectColor = project == null
        ? AppColors.textSecondary
        : Color(project!.colorValue);
    final version =
        protocol.publication?.version ??
        protocol.importSource?.version ??
        protocol.schemaVersion;
    final currentIndex = state.currentStepIndex
        .clamp(0, sortedSteps.length)
        .toInt();
    final currentStep = currentIndex < sortedSteps.length
        ? sortedSteps[currentIndex]
        : null;
    final phaseNames = <String>[];
    for (final step in sortedSteps) {
      final phase = step.phaseName?.trim();
      if (phase != null && phase.isNotEmpty && !phaseNames.contains(phase)) {
        phaseNames.add(phase);
      }
    }
    final phase = currentStep?.phaseName?.trim();
    final phaseIndex = phase == null || phase.isEmpty
        ? null
        : phaseNames.indexOf(phase) + 1;
    final percent = (progress.clamp(0, 1) * 100).round();

    return Card(
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                key: Key('$keyPrefix-project-badge-${protocol.id}'),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: projectColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  paused
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  key: Key('$keyPrefix-type-badge-${protocol.id}'),
                  color: project == null
                      ? AppColors.textSecondary
                      : projectColor,
                  size: 36,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          protocol.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'v$version.0',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          '• ${_syncLabel(protocol.syncStatus)}',
                          key: Key('$keyPrefix-sync-badge-${protocol.id}'),
                          style: TextStyle(
                            color: _syncColor(protocol.syncStatus),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Created by ${protocol.createdByName?.trim().isNotEmpty == true ? protocol.createdByName!.trim() : 'Unknown user'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            key: Key(
                              '$resolvedPhaseKeyPrefix-phase-progress-${protocol.id}',
                            ),
                            value: progress.clamp(0, 1),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            phaseIndex == null || phaseNames.isEmpty
                                ? 'Started ${formatDate(state.startedAt)}'
                                : 'Phase $phaseIndex/${phaseNames.length}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          sortedSteps.isEmpty
                              ? 'No steps'
                              : 'Step ${(currentIndex + 1).clamp(1, sortedSteps.length)}/${sortedSteps.length}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onTerminate != null)
                    IconButton(
                      tooltip: 'Terminate run',
                      onPressed: onTerminate,
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        color: AppColors.error,
                        size: 22,
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.outline,
                    size: 30,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _syncLabel(ProtocolSyncStatus status) => switch (status) {
    ProtocolSyncStatus.synced => 'Synced',
    ProtocolSyncStatus.modified => 'Local changes',
    ProtocolSyncStatus.conflict => 'Conflict copy',
    ProtocolSyncStatus.error => 'Sync error',
    ProtocolSyncStatus.localOnly => 'Local only',
  };

  Color _syncColor(ProtocolSyncStatus status) => switch (status) {
    ProtocolSyncStatus.synced => AppColors.primary,
    ProtocolSyncStatus.modified => AppColors.warning,
    ProtocolSyncStatus.conflict => AppColors.aiPrimary,
    ProtocolSyncStatus.error => AppColors.error,
    ProtocolSyncStatus.localOnly => AppColors.textSecondary,
  };

  Widget _buildHeader(BuildContext context) {
    final protocol = state.protocol;
    final badges = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _RunningBadge(
          key: Key('$keyPrefix-type-badge-${protocol.id}'),
          label: 'RUNNING',
          icon: Icons.play_circle_outline,
          color: AppColors.info,
        ),
        SyncStatusChip(
          key: Key('$keyPrefix-sync-badge-${protocol.id}'),
          status: protocol.syncStatus,
          compact: true,
        ),
        ?action,
      ],
    );
    final heading = Text(
      protocol.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: badges),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 16),
            Flexible(child: badges),
          ],
        );
      },
    );
  }
}

class _RunningMetadata extends StatelessWidget {
  const _RunningMetadata({
    required this.label,
    required this.value,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RunningBadge extends StatelessWidget {
  const _RunningBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
