import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

abstract final class ProtocolFlowLayout {
  static const double maxContentWidth = 1180;
}

class ProtocolFlowContentBoundary extends StatelessWidget {
  const ProtocolFlowContentBoundary({
    super.key,
    required this.child,
    this.maxWidth = ProtocolFlowLayout.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > maxWidth
            ? maxWidth
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}

class ProtocolFlowScreenHeader extends StatelessWidget {
  const ProtocolFlowScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}

class ProtocolFlowSearchField extends StatelessWidget {
  const ProtocolFlowSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 28),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
                icon: const Icon(Icons.close),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        filled: true,
        fillColor: AppColors.scaffoldBackground,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
      ),
    );
  }
}

class ProtocolFlowFilterPill extends StatelessWidget {
  const ProtocolFlowFilterPill({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = AppColors.textPrimary,
    this.showDropdown = true,
    this.maxWidth = 170,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final bool showDropdown;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      constraints: BoxConstraints(minHeight: 48, maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (showDropdown) ...[
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 20),
          ],
        ],
      ),
    );
  }
}

class ProtocolFlowTabBar extends StatelessWidget {
  const ProtocolFlowTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.scaffoldBackground,
      child: TabBar(
        controller: controller,
        isScrollable: false,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.outlineVariant,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textPrimary,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: tabs,
      ),
    );
  }
}

class ProtocolFlowEmptyState extends StatelessWidget {
  const ProtocolFlowEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.primary, size: 40),
              const SizedBox(height: 12),
            ],
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ProtocolFlowEntityCard extends StatelessWidget {
  const ProtocolFlowEntityCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.child,
    required this.onTap,
    this.trailing,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.badgeKey,
    this.iconKey,
  });

  final IconData icon;
  final Color iconColor;
  final Widget child;
  final VoidCallback onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;
  final Key? badgeKey;
  final Key? iconKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                key: badgeKey,
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, key: iconKey, color: iconColor, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(child: child),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class ProtocolFlowTableCard extends StatelessWidget {
  const ProtocolFlowTableCard({
    super.key,
    required this.child,
    this.title = 'Output Table',
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
        ],
        Card(clipBehavior: Clip.antiAlias, child: child),
      ],
    );
  }
}
