import 'package:flutter/material.dart';

import '../models/protocol.dart';

class SyncStatusChip extends StatelessWidget {
  final ProtocolSyncStatus status;
  final bool compact;

  const SyncStatusChip({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final config = _configFor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: config.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: compact ? 12 : 14, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _SyncStatusConfig _configFor(ProtocolSyncStatus status) {
    switch (status) {
      case ProtocolSyncStatus.synced:
        return _SyncStatusConfig(
          label: 'Synced',
          icon: Icons.cloud_done_outlined,
          color: Colors.green.shade700,
        );
      case ProtocolSyncStatus.modified:
        return _SyncStatusConfig(
          label: 'Local changes',
          icon: Icons.cloud_upload_outlined,
          color: Colors.orange.shade800,
        );
      case ProtocolSyncStatus.conflict:
        return _SyncStatusConfig(
          label: 'Conflict copy',
          icon: Icons.copy_outlined,
          color: Colors.purple.shade700,
        );
      case ProtocolSyncStatus.error:
        return _SyncStatusConfig(
          label: 'Sync error',
          icon: Icons.cloud_off_outlined,
          color: Colors.red.shade700,
        );
      case ProtocolSyncStatus.localOnly:
        return _SyncStatusConfig(
          label: 'Local only',
          icon: Icons.cloud_off_outlined,
          color: Colors.grey.shade700,
        );
    }
  }
}

class _SyncStatusConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _SyncStatusConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
