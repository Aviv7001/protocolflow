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

  const ProtocolStepActionsTable({
    super.key,
    required this.actions,
    this.isLocked = false,
    this.trailingBuilder,
    this.rowWrapperBuilder,
    this.onEdit,
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.checklist_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              'Actions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.isLocked ? Colors.grey : null,
              ),
            ),
            subtitle: Text(
              '${widget.actions.length} '
              '${widget.actions.length == 1 ? 'action' : 'actions'}',
            ),
            trailing: IconButton(
              tooltip: _isShrunk ? 'Expand actions' : 'Shrink actions',
              icon: Icon(_isShrunk ? Icons.unfold_more : Icons.unfold_less),
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
                    const Divider(height: 1, indent: 54),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
