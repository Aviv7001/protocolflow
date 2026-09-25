import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

typedef ActionRowTrailingBuilder =
    Widget? Function(BuildContext context, int index);
typedef ActionRowWrapperBuilder =
    Widget Function(BuildContext context, int index, Widget child);

class ProtocolStepActionsTable extends StatefulWidget {
  final List<String> actions;
  final bool isLocked;
  final ActionRowTrailingBuilder? trailingBuilder;
  final ActionRowWrapperBuilder? rowWrapperBuilder;
  final void Function(int index, String action)? onEdit;
  final bool embedded;

  const ProtocolStepActionsTable({
    super.key,
    required this.actions,
    this.isLocked = false,
    this.trailingBuilder,
    this.rowWrapperBuilder,
    this.onEdit,
    this.embedded = false,
  });

  @override
  State<ProtocolStepActionsTable> createState() =>
      _ProtocolStepActionsTableState();
}

class _ProtocolStepActionsTableState extends State<ProtocolStepActionsTable> {
  bool _isShrunk = false;

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return const SizedBox.shrink();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: const Icon(
            Icons.checklist_outlined,
            color: AppColors.primary,
          ),
          title: Text.rich(
            TextSpan(
              text: 'Actions',
              children: [
                TextSpan(
                  text: '  ·  ${widget.actions.length}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: widget.isLocked ? Colors.grey : null,
            ),
          ),
          trailing: IconButton(
            tooltip: _isShrunk ? 'Expand actions' : 'Shrink actions',
            icon: Icon(
              _isShrunk
                  ? Icons.keyboard_arrow_right
                  : Icons.keyboard_arrow_down,
            ),
            onPressed: () => setState(() => _isShrunk = !_isShrunk),
          ),
        ),
        if (!_isShrunk) ...[
          const Divider(height: 1),
          ...widget.actions.asMap().entries.map((entry) {
            final index = entry.key;
            final trailing = widget.trailingBuilder?.call(context, index);
            Widget row = ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              onTap: !widget.isLocked && widget.onEdit != null
                  ? () => widget.onEdit!(index, entry.value)
                  : null,
              leading: CircleAvatar(
                radius: 14,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              title: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isLocked ? Colors.grey : null,
                ),
              ),
              trailing: trailing,
            );
            row = widget.rowWrapperBuilder?.call(context, index, row) ?? row;

            return Column(
              children: [
                row,
                if (index < widget.actions.length - 1)
                  const Divider(height: 1, indent: 52, endIndent: 12),
              ],
            );
          }),
        ],
      ],
    );

    if (widget.embedded) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(12),
        ),
        child: content,
      );
    }

    return Card(clipBehavior: Clip.antiAlias, child: content);
  }
}
