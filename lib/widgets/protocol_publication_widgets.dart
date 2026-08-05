import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/protocol.dart';
import '../models/protocol_publication.dart';
import '../theme/app_colors.dart';
import '../utils/date_time_format.dart';
import 'publication_status_chip.dart';

class PublishProtocolRequest {
  const PublishProtocolRequest({required this.anonymous});

  final bool anonymous;
}

class PublishProtocolDialog extends StatefulWidget {
  const PublishProtocolDialog({
    super.key,
    required this.protocol,
    required this.defaultAuthorName,
  });

  final Protocol protocol;
  final String? defaultAuthorName;

  @override
  State<PublishProtocolDialog> createState() => _PublishProtocolDialogState();
}

class _PublishProtocolDialogState extends State<PublishProtocolDialog> {
  bool _anonymous = false;

  @override
  Widget build(BuildContext context) {
    final publication = widget.protocol.publication;
    final isUpdate = publication != null;
    final excludedPhotos = widget.protocol.additionalData.fold<int>(
      widget.protocol.files.length,
      (count, item) => count + item.photoPaths.length,
    );
    return AlertDialog(
      title: Text(isUpdate ? 'Publish protocol update' : 'Publish protocol'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUpdate
                    ? 'Version ${publication.version + 1} will be added to the public version history while keeping the same QR link.'
                    : 'A read-only snapshot will be added to My Drive/ProtocolFlow/Shared Protocols.',
              ),
              const SizedBox(height: 16),
              _PreviewRow(
                icon: Icons.description_outlined,
                label: widget.protocol.title,
              ),
              _PreviewRow(
                icon: Icons.format_list_numbered,
                label: '${widget.protocol.steps.length} steps',
              ),
              _PreviewRow(
                icon: Icons.table_chart_outlined,
                label: '${widget.protocol.tables.length} tables',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Text(
                  excludedPhotos == 0
                      ? 'Private account, project, sync, and run information will not be published.'
                      : 'Private account, project, sync, and run information will not be published. $excludedPhotos local attachment(s) will be excluded.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _anonymous,
                onChanged: (value) => setState(() => _anonymous = value),
                title: const Text('Publish anonymously'),
                subtitle: Text(
                  _anonymous
                      ? 'No author name will be included.'
                      : 'Author: ${widget.defaultAuthorName ?? 'Unknown user'}',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            PublishProtocolRequest(anonymous: _anonymous),
          ),
          icon: const Icon(Icons.public),
          label: Text(isUpdate ? 'Publish update' : 'Publish'),
        ),
      ],
    );
  }
}

class PublishedProtocolQrCard extends StatelessWidget {
  const PublishedProtocolQrCard({
    super.key,
    required this.publication,
    this.qrSize = 168,
  });

  final ProtocolPublication publication;
  final double qrSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          key: const Key('published-protocol-qr'),
          label: 'QR code for published protocol',
          child: Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: QrImageView(
              data: publication.shareUri,
              size: qrSize,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.primary,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Copy sharing link',
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: publication.shareUri),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing link copied.')),
                );
              },
              icon: const Icon(Icons.content_copy),
            ),
            IconButton(
              tooltip: 'Share protocol link',
              onPressed: () => Share.share(publication.shareUri),
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class PublicationSummary extends StatelessWidget {
  const PublicationSummary({super.key, required this.publication});

  final ProtocolPublication publication;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PublicationStatusChip(status: publication.status, compact: false),
        Text('Version ${publication.version}'),
        Text('Published ${formatDate(publication.publishedAt)}'),
        Text(
          publication.anonymous ? 'Anonymous' : publication.authorName ?? '',
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
