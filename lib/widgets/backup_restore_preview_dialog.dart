import 'package:flutter/material.dart';

import '../services/import_service.dart';
import '../theme/app_colors.dart';

class BackupRestorePreviewDialog extends StatelessWidget {
  const BackupRestorePreviewDialog({super.key, required this.preview});

  final BackupRestorePreview preview;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<BackupRestorePreviewItem>>{};
    for (final item in preview.items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final isLocal = preview.target == BackupRestoreTarget.local;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  Icon(
                    isLocal
                        ? Icons.phone_android_outlined
                        : Icons.cloud_download_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup restore preview',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Review the backup before replacing current data.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BackupMetadata(preview: preview),
                  const SizedBox(height: 12),
                  if (preview.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text('This backup contains no data.'),
                      ),
                    )
                  else
                    for (final entry in grouped.entries)
                      _BackupCategory(entry: entry),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_outlined,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isLocal
                                ? 'Restoring replaces local ProtocolFlow data and settings. Google sign-in and Drive data remain unchanged.'
                                : 'Restoring replaces ProtocolFlow private Drive sync files. Local data and published protocol shares remain unchanged.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore and replace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupMetadata extends StatelessWidget {
  const _BackupMetadata({required this.preview});

  final BackupRestorePreview preview;

  @override
  Widget build(BuildContext context) {
    final exportedAt = preview.exportedAt;
    final date = exportedAt == null
        ? 'Unknown'
        : '${exportedAt.year}-${exportedAt.month.toString().padLeft(2, '0')}-${exportedAt.day.toString().padLeft(2, '0')} '
              '${exportedAt.hour.toString().padLeft(2, '0')}:${exportedAt.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _MetadataRow(label: 'File', value: preview.sourceFileName),
          _MetadataRow(
            label: 'Destination',
            value: preview.target == BackupRestoreTarget.local
                ? 'Local app data'
                : 'Private Google Drive sync data',
          ),
          _MetadataRow(label: 'Exported', value: date),
          if (preview.exportedByInitials?.isNotEmpty == true)
            _MetadataRow(
              label: 'Exported by',
              value: preview.exportedByInitials!,
            ),
          _MetadataRow(
            label: 'Contents',
            value: '${preview.items.length} item(s)',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _BackupCategory extends StatelessWidget {
  const _BackupCategory({required this.entry});

  final MapEntry<String, List<BackupRestorePreviewItem>> entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          entry.key,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Text('${entry.value.length}'),
        children: [
          for (final item in entry.value)
            ListTile(
              dense: true,
              leading: const Icon(Icons.insert_drive_file_outlined, size: 19),
              title: Text(item.title),
              subtitle: item.detail == null ? null : Text(item.detail!),
            ),
        ],
      ),
    );
  }
}
