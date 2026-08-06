import 'package:flutter/material.dart';

import '../services/drive_sync_service.dart';
import '../theme/app_colors.dart';

class SyncPreviewDialog extends StatefulWidget {
  const SyncPreviewDialog({
    super.key,
    required this.syncService,
    required this.promptIfNecessary,
    this.preparePreview,
    this.applyPreview,
  });

  final DriveSyncService syncService;
  final bool promptIfNecessary;
  final Future<DriveSyncPreview> Function(bool promptIfNecessary)?
  preparePreview;
  final Future<DriveSyncSummary> Function(
    DriveSyncPreview preview,
    Map<String, DriveDeletionDecision> deletionDecisions,
  )?
  applyPreview;

  @override
  State<SyncPreviewDialog> createState() => _SyncPreviewDialogState();
}

class _SyncPreviewDialogState extends State<SyncPreviewDialog> {
  DriveSyncPreview? _preview;
  final Map<String, DriveDeletionDecision> _deletionDecisions = {};
  bool _preparing = true;
  bool _applying = false;
  String? _notice;

  bool get _busy => _preparing || _applying;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _preparing = true;
      _notice = null;
    });
    final preview = widget.preparePreview == null
        ? await widget.syncService.prepareSyncPreview(
            promptIfNecessary: widget.promptIfNecessary,
          )
        : await widget.preparePreview!(widget.promptIfNecessary);
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _preparing = false;
      _deletionDecisions
        ..clear()
        ..addEntries(
          preview.items
              .where(
                (item) =>
                    item.action == DriveSyncActionType.delete ||
                    item.action == DriveSyncActionType.invalid,
              )
              .map(
                (item) => MapEntry(
                  item.key,
                  item.action == DriveSyncActionType.invalid
                      ? DriveDeletionDecision.keepEverywhere
                      : DriveDeletionDecision.deleteEverywhere,
                ),
              ),
        );
    });
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || !preview.canApply) return;
    setState(() {
      _applying = true;
      _notice = null;
    });
    final summary = widget.applyPreview == null
        ? await widget.syncService.applySyncPreview(
            preview,
            deletionDecisions: _deletionDecisions,
          )
        : await widget.applyPreview!(preview, _deletionDecisions);
    if (!mounted) return;
    if (summary.previewExpired) {
      setState(() {
        _applying = false;
        _notice = summary.details;
      });
      await _prepare();
      if (mounted) {
        setState(() {
          _notice = 'The preview was refreshed because sync data changed.';
        });
      }
      return;
    }
    Navigator.of(context).pop(summary);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const Divider(),
              Flexible(child: _buildBody()),
              const Divider(),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      child: Row(
        children: [
          const Icon(Icons.cloud_sync_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _applying ? 'Applying sync' : 'Sync preview',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _busy
                      ? 'ProtocolFlow is locked while sync data is processed.'
                      : 'Review the changes before they are applied.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_busy) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              Text(
                _applying
                    ? 'Applying approved changes...'
                    : 'Comparing devices...',
              ),
            ],
          ),
        ),
      );
    }
    final preview = _preview;
    if (preview == null || preview.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.error,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                preview?.error ?? 'The sync preview could not be prepared.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final grouped = <String, List<DriveSyncPreviewItem>>{};
    for (final item in preview.items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (_notice != null) _buildNotice(_notice!),
        _buildSummary(preview),
        const SizedBox(height: 12),
        if (!preview.hasChanges)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  color: AppColors.success,
                  size: 38,
                ),
                SizedBox(height: 12),
                Text('Everything is already synchronized.'),
              ],
            ),
          )
        else
          ...grouped.entries.map(_buildCategory),
      ],
    );
  }

  Widget _buildNotice(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildSummary(DriveSyncPreview preview) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DriveSyncActionType.values
          .map(
            (action) =>
                _SummaryChip(action: action, count: preview.count(action)),
          )
          .toList(),
    );
  }

  Widget _buildCategory(MapEntry<String, List<DriveSyncPreviewItem>> entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        initiallyExpanded: entry.value.any(
          (item) =>
              item.action == DriveSyncActionType.delete ||
              item.action == DriveSyncActionType.invalid ||
              item.action == DriveSyncActionType.conflict,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          entry.key,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Text('${entry.value.length}'),
        children: entry.value.map(_buildChangeRow).toList(),
      ),
    );
  }

  Widget _buildChangeRow(DriveSyncPreviewItem item) {
    final details = _actionDetails(item.action);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasDecision =
              (item.action == DriveSyncActionType.delete ||
                  item.action == DriveSyncActionType.invalid) &&
              item.canKeep;
          final description = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(details.icon, color: details.color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.note ?? details.label,
                      style: TextStyle(color: details.color, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
          if (hasDecision && constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                description,
                const SizedBox(height: 8),
                _buildDeletionDecision(item, expanded: true),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: description),
              if (hasDecision) ...[
                const SizedBox(width: 12),
                _buildDeletionDecision(item),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeletionDecision(
    DriveSyncPreviewItem item, {
    bool expanded = false,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<DriveDeletionDecision>(
        value: _deletionDecisions[item.key],
        isExpanded: expanded,
        borderRadius: BorderRadius.circular(6),
        items: item.action == DriveSyncActionType.invalid
            ? const [
                DropdownMenuItem(
                  value: DriveDeletionDecision.keepEverywhere,
                  child: Text('Keep in cloud'),
                ),
                DropdownMenuItem(
                  value: DriveDeletionDecision.deleteEverywhere,
                  child: Text('Delete everywhere'),
                ),
              ]
            : const [
                DropdownMenuItem(
                  value: DriveDeletionDecision.deleteEverywhere,
                  child: Text('Delete everywhere'),
                ),
                DropdownMenuItem(
                  value: DriveDeletionDecision.keepEverywhere,
                  child: Text('Keep everywhere'),
                ),
              ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _deletionDecisions[item.key] = value);
        },
      ),
    );
  }

  Widget _buildActions() {
    final preview = _preview;
    final actions = <Widget>[
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: Text(preview?.error == null ? 'Cancel' : 'Close'),
      ),
      if (preview?.error != null)
        OutlinedButton.icon(
          onPressed: _busy ? null : _prepare,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      if (preview?.canApply ?? false)
        ElevatedButton.icon(
          key: const Key('approve-sync-preview'),
          onPressed: _busy ? null : _apply,
          icon: Icon(preview!.hasChanges ? Icons.sync : Icons.check),
          label: Text(preview.hasChanges ? 'Approve sync' : 'Finish'),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: 8,
        overflowSpacing: 8,
        children: actions,
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.action, required this.count});

  final DriveSyncActionType action;
  final int count;

  @override
  Widget build(BuildContext context) {
    final details = _actionDetails(action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: details.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(details.icon, color: details.color, size: 16),
          const SizedBox(width: 6),
          Text('${details.shortLabel} $count'),
        ],
      ),
    );
  }
}

({IconData icon, Color color, String label, String shortLabel}) _actionDetails(
  DriveSyncActionType action,
) {
  return switch (action) {
    DriveSyncActionType.upload => (
      icon: Icons.cloud_upload_outlined,
      color: AppColors.primary,
      label: 'Upload from this device',
      shortLabel: 'Upload',
    ),
    DriveSyncActionType.download => (
      icon: Icons.cloud_download_outlined,
      color: AppColors.info,
      label: 'Download to this device',
      shortLabel: 'Download',
    ),
    DriveSyncActionType.delete => (
      icon: Icons.delete_outline,
      color: AppColors.error,
      label: 'Deletion requested',
      shortLabel: 'Delete',
    ),
    DriveSyncActionType.conflict => (
      icon: Icons.call_split,
      color: AppColors.warning,
      label: 'Preserve a conflict copy',
      shortLabel: 'Conflict',
    ),
    DriveSyncActionType.invalid => (
      icon: Icons.cloud_off_outlined,
      color: AppColors.error,
      label: 'Unreadable cloud item',
      shortLabel: 'Unreadable',
    ),
  };
}
