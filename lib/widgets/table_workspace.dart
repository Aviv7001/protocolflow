import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'protocolflow_app_bar.dart';

abstract final class TableWorkspaceDimensions {
  static const double wideBreakpoint = 1040;
  static const double maxContentWidth = 1440;
  static const double controlsFlex = 38;
  static const double previewFlex = 62;
}

class TableWorkspaceSection extends StatelessWidget {
  const TableWorkspaceSection({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || trailing != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                  ],
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class ResponsiveTableManagerLayout extends StatelessWidget {
  const ResponsiveTableManagerLayout({
    super.key,
    required this.controls,
    required this.preview,
    this.controlsKey,
    this.previewKey,
  });

  final Widget controls;
  final Widget preview;
  final Key? controlsKey;
  final Key? previewKey;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardTheme: Theme.of(context).cardTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.outlineVariant),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= TableWorkspaceDimensions.wideBreakpoint;
          final content = isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: TableWorkspaceDimensions.controlsFlex.round(),
                      child: KeyedSubtree(key: controlsKey, child: controls),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: TableWorkspaceDimensions.previewFlex.round(),
                      child: KeyedSubtree(key: previewKey, child: preview),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(key: controlsKey, child: controls),
                    const SizedBox(height: 16),
                    KeyedSubtree(key: previewKey, child: preview),
                  ],
                );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TableWorkspaceDimensions.maxContentWidth,
                ),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }
}

class TableMetadataBadge extends StatelessWidget {
  const TableMetadataBadge({
    super.key,
    required this.label,
    required this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TableViewerScaffold extends StatelessWidget {
  const TableViewerScaffold({
    super.key,
    required this.title,
    required this.table,
    required this.typeLabel,
    required this.typeIcon,
    this.actions = const [],
    this.metadata = const [],
  });

  final String title;
  final Widget table;
  final String typeLabel;
  final IconData typeIcon;
  final List<Widget> actions;
  final List<Widget> metadata;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardTheme: Theme.of(context).cardTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.outlineVariant),
          ),
        ),
      ),
      child: Scaffold(
        appBar: ProtocolFlowAppBar(title: title, actions: actions),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TableMetadataBadge(label: typeLabel, icon: typeIcon),
                  ...metadata,
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: TableWorkspaceDimensions.maxContentWidth,
                    ),
                    child: table,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TableWorkspaceEmptyState extends StatelessWidget {
  const TableWorkspaceEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return TableWorkspaceSection(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
