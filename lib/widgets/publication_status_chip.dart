import 'package:flutter/material.dart';

import '../models/protocol_publication.dart';
import '../theme/app_colors.dart';

class PublicationStatusChip extends StatelessWidget {
  const PublicationStatusChip({
    super.key,
    required this.status,
    this.compact = true,
  });

  final ProtocolPublicationStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      ProtocolPublicationStatus.published => (
        'PUBLISHED',
        Icons.public,
        AppColors.success,
      ),
      ProtocolPublicationStatus.changesUnpublished => (
        'CHANGES UNPUBLISHED',
        Icons.cloud_upload_outlined,
        AppColors.warning,
      ),
      ProtocolPublicationStatus.unpublished => (
        'UNPUBLISHED',
        Icons.public_off_outlined,
        AppColors.textSecondary,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
