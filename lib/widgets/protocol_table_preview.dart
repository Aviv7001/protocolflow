import 'dart:convert';

import 'package:flutter/material.dart';

import '../features/plate_wizard/widgets/plate_result_preview.dart';
import '../features/staining_table/models/staining_wizard.dart';
import '../features/staining_table/services/staining_table_generator_service.dart';
import '../features/staining_table/widgets/staining_result_table.dart';
import '../models/plate_wizard.dart';
import '../models/protocol_table.dart';
import '../theme/app_colors.dart';
import 'horizontal_table_scroll.dart';
import 'protocol_table_widget.dart';

class ProtocolTablePreview extends StatelessWidget {
  const ProtocolTablePreview({
    super.key,
    required this.table,
    this.isReadOnly = true,
    this.onSave,
    this.onMoveUp,
    this.onMoveDown,
    this.onUnlink,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.showOrderControls = false,
    this.isCollapsed = false,
    this.onCollapsedChanged,
  });

  final ProtocolTable table;
  final bool isReadOnly;
  final ValueChanged<ProtocolTable>? onSave;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onUnlink;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool showOrderControls;
  final bool isCollapsed;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    final title = table.title.isEmpty ? 'Untitled Table' : table.title;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Open table',
                  onPressed: () => _openTable(context),
                  icon: Icon(
                    _typeIcon(table.type),
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _typeLabel(table.type),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showOrderControls) ...[
                  IconButton(
                    tooltip: 'Move table up',
                    onPressed: canMoveUp ? onMoveUp : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: 'Move table down',
                    onPressed: canMoveDown ? onMoveDown : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
                IconButton(
                  tooltip: isCollapsed ? 'Expand table' : 'Shrink table',
                  onPressed: onCollapsedChanged == null
                      ? null
                      : () => onCollapsedChanged!(!isCollapsed),
                  icon: Icon(
                    isCollapsed ? Icons.unfold_more : Icons.unfold_less,
                  ),
                ),
                if (onUnlink != null)
                  IconButton(
                    tooltip: 'Unlink from step',
                    onPressed: onUnlink,
                    color: AppColors.error,
                    icon: const Icon(Icons.link_off),
                  ),
              ],
            ),
          ),
          if (!isCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: _buildInlineTable(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineTable(BuildContext context) {
    final widget = _buildSpecializedTable();
    if (widget != null) return HorizontalTableScroll(child: widget);
    if (_hasTableData(table)) return _InlineTableData(table: table);
    return Center(
      child: ProtocolTableWidget(
        table: table,
        isReadOnly: isReadOnly,
        onSave: onSave,
      ),
    );
  }

  bool _hasTableData(ProtocolTable table) {
    return table.data.isNotEmpty &&
        table.data.any((row) => row.any((cell) => cell.toString().isNotEmpty));
  }

  void _openTable(BuildContext context) {
    ProtocolTableWidget.openTableViewer(
      context,
      table: table,
      isReadOnly: isReadOnly,
      onSave: onSave,
    );
  }

  Widget? _buildSpecializedTable() {
    final wizardState = table.metadata['wizard_state'];
    if (wizardState == null) return null;

    try {
      switch (table.type) {
        case TableType.staining:
          return StainingResultTable(
            wizard: StainingWizard.fromJson(jsonDecode(wizardState)),
            generator: StainingTableGeneratorService(),
          );
        case TableType.plateLayout:
          return PlateResultPreview(
            wizard: PlateLayoutWizard.fromJson(jsonDecode(wizardState)),
          );
        case TableType.masterMix:
        case TableType.reagentMix:
        case TableType.serialDilution:
        case TableType.reagentMatrix:
        case TableType.checklist:
        case TableType.generic:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  IconData _typeIcon(TableType type) {
    switch (type) {
      case TableType.plateLayout:
        return Icons.grid_on;
      case TableType.reagentMatrix:
        return Icons.biotech;
      case TableType.masterMix:
        return Icons.calculate;
      case TableType.checklist:
        return Icons.fact_check;
      case TableType.staining:
        return Icons.color_lens;
      case TableType.reagentMix:
        return Icons.science;
      case TableType.serialDilution:
        return Icons.water_drop;
      case TableType.generic:
        return Icons.table_chart;
    }
  }

  String _typeLabel(TableType type) {
    switch (type) {
      case TableType.masterMix:
        return 'Master mix';
      case TableType.staining:
        return 'Staining table';
      case TableType.reagentMix:
      case TableType.reagentMatrix:
        return 'C1V1 = C2V2';
      case TableType.serialDilution:
        return 'Serial dilution';
      case TableType.plateLayout:
        return 'Plate layout';
      case TableType.checklist:
        return 'Checklist';
      case TableType.generic:
        return 'Generic table';
    }
  }
}

class LinkedProtocolTablesSection extends StatefulWidget {
  const LinkedProtocolTablesSection({
    super.key,
    required this.tables,
    this.isReadOnly = true,
    this.onSave,
    this.showOrderControls = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onUnlink,
  });

  final List<ProtocolTable> tables;
  final bool isReadOnly;
  final ValueChanged<ProtocolTable>? onSave;
  final bool showOrderControls;
  final void Function(int index)? onMoveUp;
  final void Function(int index)? onMoveDown;
  final void Function(ProtocolTable table)? onUnlink;

  @override
  State<LinkedProtocolTablesSection> createState() =>
      _LinkedProtocolTablesSectionState();
}

class _LinkedProtocolTablesSectionState
    extends State<LinkedProtocolTablesSection> {
  final Set<String> _collapsedTableIds = {};

  @override
  void didUpdateWidget(covariant LinkedProtocolTablesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.tables.map((table) => table.id).toSet();
    _collapsedTableIds.removeWhere((id) => !currentIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tables.isEmpty) return const SizedBox.shrink();

    final allCollapsed = widget.tables.every(
      (table) => _collapsedTableIds.contains(table.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                if (allCollapsed) {
                  _collapsedTableIds.clear();
                } else {
                  _collapsedTableIds
                    ..clear()
                    ..addAll(widget.tables.map((table) => table.id));
                }
              });
            },
            icon: Icon(allCollapsed ? Icons.unfold_more : Icons.unfold_less),
            label: Text(
              allCollapsed ? 'Expand all tables' : 'Shrink all tables',
            ),
          ),
        ),
        ...widget.tables.asMap().entries.map((entry) {
          final index = entry.key;
          final table = entry.value;
          return ProtocolTablePreview(
            table: table,
            isReadOnly: widget.isReadOnly,
            onSave: widget.onSave,
            showOrderControls: widget.showOrderControls,
            canMoveUp: index > 0,
            canMoveDown: index < widget.tables.length - 1,
            onMoveUp: widget.onMoveUp == null
                ? null
                : () => widget.onMoveUp!(index),
            onMoveDown: widget.onMoveDown == null
                ? null
                : () => widget.onMoveDown!(index),
            onUnlink: widget.onUnlink == null
                ? null
                : () => widget.onUnlink!(table),
            isCollapsed: _collapsedTableIds.contains(table.id),
            onCollapsedChanged: (collapsed) {
              setState(() {
                if (collapsed) {
                  _collapsedTableIds.add(table.id);
                } else {
                  _collapsedTableIds.remove(table.id);
                }
              });
            },
          );
        }),
      ],
    );
  }
}

class _InlineTableData extends StatelessWidget {
  const _InlineTableData({required this.table});

  final ProtocolTable table;

  @override
  Widget build(BuildContext context) {
    final maxColumns = table.data.fold<int>(
      table.columnHeaders.length,
      (max, row) => row.length > max ? row.length : max,
    );
    final hasRowHeaders = table.rowHeaders.isNotEmpty;

    return HorizontalTableScroll(
      minWidth: 360,
      child: DataTable(
        border: TableBorder.all(color: AppColors.outlineVariant),
        columnSpacing: 18,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 48,
        headingRowColor: const WidgetStatePropertyAll(
          AppColors.surfaceContainer,
        ),
        columns: [
          if (hasRowHeaders)
            const DataColumn(
              label: Text(
                '#',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          for (var i = 0; i < maxColumns; i++)
            DataColumn(
              label: Text(
                i < table.columnHeaders.length ? table.columnHeaders[i] : '',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
        rows: table.data.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;
          return DataRow(
            cells: [
              if (hasRowHeaders)
                DataCell(
                  Text(
                    rowIndex < table.rowHeaders.length
                        ? table.rowHeaders[rowIndex]
                        : '',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              for (var i = 0; i < maxColumns; i++)
                DataCell(
                  _isStatusColumn(i)
                      ? _statusIcons(i < row.length ? row[i].toString() : '')
                      : Text(
                          i < row.length ? row[i].toString() : '',
                          style: const TextStyle(fontSize: 11),
                        ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  bool _isStatusColumn(int index) {
    return index < table.columnHeaders.length &&
        table.columnHeaders[index] == 'Status';
  }

  Widget _statusIcons(String status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status.contains('Warning'))
          const Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
        if (status.contains('Warning') && status.contains('Suggestion'))
          const SizedBox(width: 4),
        if (status.contains('Suggestion'))
          const Icon(Icons.tips_and_updates, size: 16, color: AppColors.info),
      ],
    );
  }
}
