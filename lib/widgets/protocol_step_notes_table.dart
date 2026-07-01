import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProtocolStepNotesTable extends StatefulWidget {
  final List<String> notes;
  final bool isLocked;
  final void Function(int index, int direction)? onMove;
  final void Function(int index)? onDelete;

  const ProtocolStepNotesTable({
    super.key,
    required this.notes,
    this.isLocked = false,
    this.onMove,
    this.onDelete,
  });

  @override
  State<ProtocolStepNotesTable> createState() => _ProtocolStepNotesTableState();
}

class _ProtocolStepNotesTableState extends State<ProtocolStepNotesTable> {
  bool _isShrunk = false;

  bool get _canEdit =>
      !widget.isLocked && (widget.onMove != null || widget.onDelete != null);

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
            Table(
              columnWidths: {
                0: const FixedColumnWidth(44),
                1: const FlexColumnWidth(),
                if (_canEdit) 2: const FixedColumnWidth(48),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: AppColors.outlineVariant),
              ),
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                  ),
                  children: [
                    _cell(
                      const Text(
                        '#',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _cell(
                      const Text(
                        'Note',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_canEdit) const SizedBox.shrink(),
                  ],
                ),
                ...widget.notes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final note = entry.value;
                  return TableRow(
                    children: [
                      _cell(Text('${index + 1}')),
                      _cell(Text(note)),
                      if (_canEdit)
                        Center(
                          child: PopupMenuButton<String>(
                            tooltip: 'Note options',
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              switch (value) {
                                case 'moveUp':
                                  widget.onMove?.call(index, -1);
                                  break;
                                case 'moveDown':
                                  widget.onMove?.call(index, 1);
                                  break;
                                case 'delete':
                                  widget.onDelete?.call(index);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'moveUp',
                                enabled: index > 0,
                                child: const ListTile(
                                  leading: Icon(Icons.keyboard_arrow_up),
                                  title: Text('Move Up'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'moveDown',
                                enabled: index < widget.notes.length - 1,
                                child: const ListTile(
                                  leading: Icon(Icons.keyboard_arrow_down),
                                  title: Text('Move Down'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: AppColors.error,
                                  ),
                                  title: Text('Delete Note'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    );
  }
}
