import 'package:flutter/material.dart';

import '../features/measuring_tools/services/transfer_optimizer_service.dart';
import '../theme/app_colors.dart';

class TransferStatusIcons extends StatelessWidget {
  final TransferEvaluationResult? evaluation;
  final List<dynamic> warnings;
  final List<dynamic> suggestions;
  final String? statusText;
  final bool showOk;

  const TransferStatusIcons({
    super.key,
    this.evaluation,
    this.warnings = const [],
    this.suggestions = const [],
    this.statusText,
    this.showOk = true,
  });

  @override
  Widget build(BuildContext context) {
    final icons = _icons();
    if (icons.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < icons.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Icon(icons[i].icon, size: 16, color: icons[i].color),
        ],
      ],
    );
  }

  List<_StatusIconSpec> _icons() {
    final status = evaluation?.status;
    final normalizedText = statusText?.toLowerCase() ?? '';
    final hasWarnings = warnings.isNotEmpty;
    final hasSuggestions =
        suggestions.isNotEmpty || evaluation?.suggestionMessage != null;
    final icons = <_StatusIconSpec>[];

    if (status == TransferStatus.ok || normalizedText.contains('ok')) {
      if (showOk && !hasWarnings && !hasSuggestions) {
        icons.add(
          const _StatusIconSpec(Icons.check_circle_outline, AppColors.success),
        );
      }
    } else if (status == TransferStatus.warningNoCompatibleTool ||
        normalizedText.contains('no compatible')) {
      icons.add(const _StatusIconSpec(Icons.block, AppColors.error));
    } else if (status == TransferStatus.cautionLowRange ||
        normalizedText.contains('low range')) {
      icons.add(
        const _StatusIconSpec(Icons.vertical_align_bottom, AppColors.warning),
      );
    } else if (status == TransferStatus.cautionRepeatedTransfer ||
        normalizedText.contains('repeated transfer')) {
      icons.add(const _StatusIconSpec(Icons.repeat, AppColors.warning));
    } else if (status == TransferStatus.suggestAutoExtraVolume ||
        normalizedText.contains('auto extra')) {
      icons.add(const _StatusIconSpec(Icons.auto_fix_high, AppColors.info));
    } else if (status == TransferStatus.suggestIntermediateDilution ||
        normalizedText.contains('intermediate')) {
      icons.add(const _StatusIconSpec(Icons.science_outlined, AppColors.info));
    } else if (hasWarnings || normalizedText.contains('warning')) {
      icons.add(const _StatusIconSpec(Icons.warning_amber, AppColors.warning));
    }

    if (hasSuggestions || normalizedText.contains('suggestion')) {
      final suggestionIcon = _suggestionIcon();
      if (!icons.any((icon) => icon.icon == suggestionIcon.icon)) {
        icons.add(suggestionIcon);
      }
    }

    return icons;
  }

  _StatusIconSpec _suggestionIcon() {
    final message = evaluation?.suggestionMessage?.toLowerCase() ?? '';
    final normalizedText = statusText?.toLowerCase() ?? '';
    if (message.contains('intermediate') ||
        normalizedText.contains('intermediate')) {
      return const _StatusIconSpec(Icons.science_outlined, AppColors.info);
    }
    if (message.contains('extra volume') ||
        normalizedText.contains('auto extra')) {
      return const _StatusIconSpec(Icons.auto_fix_high, AppColors.info);
    }
    return const _StatusIconSpec(
      Icons.tips_and_updates_outlined,
      AppColors.info,
    );
  }
}

class _StatusIconSpec {
  final IconData icon;
  final Color color;

  const _StatusIconSpec(this.icon, this.color);
}
