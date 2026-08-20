import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ProtocolExportFormat { pdf, docx, protocolFlow }

class ProtocolExportDialog extends StatelessWidget {
  const ProtocolExportDialog({super.key, this.title = 'Export protocol'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('protocol-export-dialog'),
      title: Row(
        children: [
          const Icon(Icons.ios_share_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExportMenuItem(
                icon: Icons.picture_as_pdf_outlined,
                title: 'PDF',
                subtitle: 'Formatted protocol document',
                onTap: () => Navigator.pop(context, ProtocolExportFormat.pdf),
              ),
              const Divider(height: 1),
              _ExportMenuItem(
                icon: Icons.description_outlined,
                title: 'Word (DOCX)',
                subtitle: 'Editable document',
                onTap: () => Navigator.pop(context, ProtocolExportFormat.docx),
              ),
              const Divider(height: 1),
              _ExportMenuItem(
                icon: Icons.data_object,
                title: 'ProtocolFlow file',
                subtitle: 'Importable ProtocolFlow data',
                onTap: () =>
                    Navigator.pop(context, ProtocolExportFormat.protocolFlow),
              ),
              const Divider(height: 1),
              const _ExportMenuItem(
                icon: Icons.table_view_outlined,
                title: 'Excel (XLSX)',
                subtitle: 'Coming soon',
                enabled: false,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ExportMenuItem extends StatelessWidget {
  const _ExportMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? AppColors.primary : null),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: enabled ? const Icon(Icons.chevron_right) : null,
      onTap: enabled ? onTap : null,
    );
  }
}
