import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_publication.dart';
import '../theme/app_colors.dart';
import '../utils/date_time_format.dart';

enum ProtocolSummaryType { template, protocol, completed }

class ProtocolSummaryCard extends StatelessWidget {
  const ProtocolSummaryCard({
    super.key,
    required this.protocol,
    required this.type,
    required this.actionLabel,
    required this.onAction,
    required this.onTap,
    this.project,
    this.startedAt,
    this.completedAt,
    this.syncStatus,
    this.publicationStatus,
    this.keyPrefix = 'library',
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final Protocol protocol;
  final ProtocolSummaryType type;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onTap;
  final Project? project;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final ProtocolSyncStatus? syncStatus;
  final ProtocolPublicationStatus? publicationStatus;
  final String keyPrefix;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final typeIcon = switch (type) {
      ProtocolSummaryType.template => Icons.copy_all_outlined,
      ProtocolSummaryType.protocol => Icons.description_outlined,
      ProtocolSummaryType.completed => Icons.check_circle_outline,
    };
    final projectColor = project == null
        ? AppColors.textSecondary
        : Color(project!.colorValue);
    final version =
        protocol.publication?.version ??
        protocol.importSource?.version ??
        protocol.schemaVersion;
    final author = protocol.createdByName?.trim();

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
                  typeIcon,
                  key: Key('$keyPrefix-type-badge-${protocol.id}'),
                  color: project == null
                      ? AppColors.textSecondary
                      : projectColor,
                  size: 30,
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
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        if (syncStatus != null)
                          Text(
                            '• ${_syncLabel(syncStatus!)}',
                            key: Key('$keyPrefix-sync-badge-${protocol.id}'),
                            style: TextStyle(
                              color: _syncColor(syncStatus!),
                              fontSize: 11,
                            ),
                          ),
                        if (publicationStatus != null)
                          Text(
                            '• ${_publicationLabel(publicationStatus!)}',
                            key: Key(
                              '$keyPrefix-publication-badge-${protocol.id}',
                            ),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      completedAt != null
                          ? 'Completed on ${formatDate(completedAt!)}'
                          : author == null || author.isEmpty
                          ? 'Created on ${formatDate(protocol.createdAt)}'
                          : 'Created by $author',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (completedAt != null &&
                        author != null &&
                        author.isNotEmpty)
                      Text(
                        'Created by $author',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: actionLabel,
                onPressed: onAction,
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.outline,
                  size: 30,
                ),
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

  String _publicationLabel(ProtocolPublicationStatus status) =>
      switch (status) {
        ProtocolPublicationStatus.published => 'Published',
        ProtocolPublicationStatus.changesUnpublished => 'Changes unpublished',
        ProtocolPublicationStatus.unpublished => 'Unpublished',
      };
}
