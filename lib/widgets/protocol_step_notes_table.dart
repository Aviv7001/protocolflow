import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProtocolStepNotesTable extends StatefulWidget {
  final List<String> notes;
  final bool isLocked;
  final void Function(int index, int direction)? onMove;
  final void Function(int index)? onDelete;
  final void Function(int index, String note)? onEdit;

  const ProtocolStepNotesTable({
    super.key,
    required this.notes,
    this.isLocked = false,
    this.onMove,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<ProtocolStepNotesTable> createState() => _ProtocolStepNotesTableState();
}

class _ProtocolStepNotesTableState extends State<ProtocolStepNotesTable> {
  bool _isShrunk = false;

  bool get _canEdit =>
      !widget.isLocked &&
      (widget.onMove != null ||
          widget.onDelete != null ||
          widget.onEdit != null);

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.info_outline, color: AppColors.info),
            title: Text(
              'Protocol Step Notes',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.isLocked ? Colors.grey : null,
              ),
            ),
            subtitle: Text(
              '${widget.notes.length} ${widget.notes.length == 1 ? 'note' : 'notes'}',
            ),
            trailing: IconButton(
              tooltip: _isShrunk ? 'Expand notes' : 'Shrink notes',
              icon: Icon(_isShrunk ? Icons.unfold_more : Icons.unfold_less),
              onPressed: () => setState(() => _isShrunk = !_isShrunk),
            ),
          ),
          if (!_isShrunk) ...[
            const Divider(height: 1),
            ...widget.notes.asMap().entries.map((entry) {
              final index = entry.key;
              return Column(
                children: [
                  ListTile(
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
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: _canEdit
                        ? PopupMenuButton<String>(
                            tooltip: 'Note options',
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'moveUp') {
                                widget.onMove?.call(index, -1);
                              }
                              if (value == 'moveDown') {
                                widget.onMove?.call(index, 1);
                              }
                              if (value == 'delete') {
                                widget.onDelete?.call(index);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'moveUp',
                                enabled: index > 0,
                                child: const Text('Move up'),
                              ),
                              PopupMenuItem(
                                value: 'moveDown',
                                enabled: index < widget.notes.length - 1,
                                child: const Text('Move down'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete note'),
                              ),
                            ],
                          )
                        : null,
                  ),
                  if (index < widget.notes.length - 1)
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
