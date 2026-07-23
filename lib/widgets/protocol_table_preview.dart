import 'dart:convert';

import 'package:flutter/material.dart';

import '../features/staining_table/models/staining_wizard.dart';
import '../features/staining_table/services/staining_table_generator_service.dart';
import '../features/staining_table/widgets/staining_result_table.dart';
import '../models/plate_wizard.dart';
import '../models/protocol_table.dart';
import '../theme/app_colors.dart';
import 'horizontal_table_scroll.dart';
import 'protocol_table_widget.dart';
import 'transfer_status_icons.dart';

class ProtocolTablePreview extends StatelessWidget {
  const ProtocolTablePreview({
    super.key,
    required this.table,
    this.isReadOnly = true,
    this.onSave,
    this.onMoveUp,
    this.onMoveDown,
    this.onUnlink,
    this.onDelete,
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
  final VoidCallback? onDelete;
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
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete table',
                    onPressed: onDelete,
                    color: AppColors.error,
                    icon: const Icon(Icons.delete_outline),
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
    if (table.type == TableType.plateLayout) {
      final plateTables = _platePreviewTables();
      if (plateTables.any(_hasTableData)) {
        return _CompactPlateTablePreview(tables: plateTables);
      }
    }
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

  List<ProtocolTable> _platePreviewTables() {
    final wizardState = table.metadata['wizard_state'];
    if (wizardState != null) {
      try {
        final wizard = PlateLayoutWizard.fromJson(jsonDecode(wizardState));
        final tables = wizard.generateTables();
        if (tables.isNotEmpty) return tables;
      } catch (_) {
        // Fall back to the saved table data below.
      }
    }
    return [table];
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

    try {
      switch (table.type) {
        case TableType.staining:
          if (wizardState == null) return null;
          return StainingResultTable(
            wizard: StainingWizard.fromJson(jsonDecode(wizardState)),
            generator: StainingTableGeneratorService(),
          );
        case TableType.plateLayout:
          return null;
        case TableType.masterMix:
        case TableType.serialDilution:
        case TableType.checklist:
        case TableType.generic:
        case TableType.materialList:
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
      case TableType.masterMix:
        return Icons.calculate;
      case TableType.checklist:
        return Icons.fact_check;
      case TableType.staining:
        return Icons.color_lens;
      case TableType.serialDilution:
        return Icons.water_drop;
      case TableType.generic:
        return Icons.table_chart;
      case TableType.materialList:
        return Icons.inventory_2_outlined;
    }
  }

  String _typeLabel(TableType type) {
    switch (type) {
      case TableType.masterMix:
        return 'Master mix';
      case TableType.staining:
        return 'Staining table';
      case TableType.serialDilution:
        return 'Serial dilution';
      case TableType.plateLayout:
        return 'Plate layout';
      case TableType.checklist:
        return 'Checklist';
      case TableType.generic:
        return 'Generic table';
      case TableType.materialList:
        return 'Material list';
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
    this.onDelete,
    this.initiallyCollapsed = false,
  });

  final List<ProtocolTable> tables;
  final bool isReadOnly;
  final ValueChanged<ProtocolTable>? onSave;
  final bool showOrderControls;
  final void Function(int index)? onMoveUp;
  final void Function(int index)? onMoveDown;
  final void Function(ProtocolTable table)? onUnlink;
  final void Function(ProtocolTable table)? onDelete;
  final bool initiallyCollapsed;

  @override
  State<LinkedProtocolTablesSection> createState() =>
      _LinkedProtocolTablesSectionState();
}

class _CompactPlateTablePreview extends StatefulWidget {
  const _CompactPlateTablePreview({required this.tables});

  final List<ProtocolTable> tables;

  @override
  State<_CompactPlateTablePreview> createState() =>
      _CompactPlateTablePreviewState();
}

class _CompactPlateTablePreviewState extends State<_CompactPlateTablePreview> {
  int _plateIndex = 0;

  @override
  void didUpdateWidget(covariant _CompactPlateTablePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_plateIndex >= widget.tables.length) {
      _plateIndex = widget.tables.isEmpty ? 0 : widget.tables.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tables.isEmpty) return const SizedBox.shrink();

    final table = widget.tables[_plateIndex];
    final rows =
        int.tryParse(table.metadata['rows'] ?? '') ?? table.data.length;
    final cols =
        int.tryParse(table.metadata['columns'] ?? '') ??
        table.data.fold<int>(
          0,
          (max, row) => row.length > max ? row.length : max,
        );
    if (rows <= 0 || cols <= 0) return _InlineTableData(table: table);

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardWidth = _boardWidth(cols + 1);
        final boardHeight = _boardHeight(rows);
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : boardWidth;
        final scale = availableWidth < boardWidth
            ? (availableWidth / boardWidth).clamp(0.24, 1.0).toDouble()
            : 1.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: boardWidth * scale,
                height: boardHeight * scale,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: boardWidth,
                    maxWidth: boardWidth,
                    minHeight: boardHeight,
                    maxHeight: boardHeight,
                    child: SizedBox(
                      width: boardWidth,
                      height: boardHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                        child: _buildBoard(table, rows, cols),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.tables.length > 1) _buildPlatePager(),
          ],
        );
      },
    );
  }

  Widget _buildPlatePager() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Plate ${_plateIndex + 1}/${widget.tables.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            _pagerButton(
              tooltip: 'Previous plate',
              icon: Icons.chevron_left,
              onPressed: _plateIndex > 0
                  ? () => setState(() => _plateIndex--)
                  : null,
            ),
            _pagerButton(
              tooltip: 'Next plate',
              icon: Icons.chevron_right,
              onPressed: _plateIndex < widget.tables.length - 1
                  ? () => setState(() => _plateIndex++)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagerButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 26, height: 26),
    );
  }

  Widget _buildBoard(ProtocolTable table, int rows, int cols) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 30),
            ...List.generate(
              cols,
              (index) => SizedBox(
                width: 48,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(
          rows,
          (rowIndex) => Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  rowIndex < table.rowHeaders.length
                      ? table.rowHeaders[rowIndex]
                      : String.fromCharCode(65 + rowIndex),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ...List.generate(
                cols,
                (colIndex) => _buildWell(table, rowIndex, colIndex),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWell(ProtocolTable table, int rowIndex, int colIndex) {
    final content = _cellText(table, rowIndex, colIndex);
    final colorHex = _cellColor(table, rowIndex, colIndex);
    final fill = colorHex.isEmpty
        ? Colors.grey.shade50
        : _parseHexColor(colorHex).withValues(alpha: 0.8);
    final parts = content.split('\n');
    final name = parts.isNotEmpty ? parts[0] : '';
    final condition = parts.length > 1 ? parts[1] : '';
    final dilution = parts.length > 2 ? parts[2] : '';

    return Container(
      width: 45,
      height: 45,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: content.isEmpty ? AppColors.outlineVariant : AppColors.outline,
        ),
      ),
      child: content.isEmpty
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (condition.isNotEmpty)
                  Text(
                    condition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 7,
                      color: AppColors.info,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (dilution.isNotEmpty)
                  Text(
                    dilution,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 7,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
    );
  }

  String _cellText(ProtocolTable table, int rowIndex, int colIndex) {
    if (rowIndex < 0 ||
        colIndex < 0 ||
        rowIndex >= table.data.length ||
        colIndex >= table.data[rowIndex].length) {
      return '';
    }
    return table.data[rowIndex][colIndex]?.toString() ?? '';
  }

  String _cellColor(ProtocolTable table, int rowIndex, int colIndex) {
    if (rowIndex < 0 ||
        colIndex < 0 ||
        rowIndex >= table.cellColors.length ||
        colIndex >= table.cellColors[rowIndex].length) {
      return '';
    }
    return table.cellColors[rowIndex][colIndex];
  }

  Color _parseHexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.transparent;
    }
  }

  double _boardWidth(int cols) => 24 + 30 + cols * 48;

  double _boardHeight(int rows) => 32 + 8 + rows * 48 + 32;
}

class _LinkedProtocolTablesSectionState
    extends State<LinkedProtocolTablesSection> {
  final Set<String> _collapsedTableIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initiallyCollapsed) {
      _collapsedTableIds.addAll(widget.tables.map((table) => table.id));
    }
  }

  @override
  void didUpdateWidget(covariant LinkedProtocolTablesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.tables.map((table) => table.id).toSet();
    _collapsedTableIds.removeWhere((id) => !currentIds.contains(id));
    if (widget.initiallyCollapsed) {
      final previousIds = oldWidget.tables.map((table) => table.id).toSet();
      _collapsedTableIds.addAll(currentIds.difference(previousIds));
      if (!oldWidget.initiallyCollapsed) {
        _collapsedTableIds.addAll(currentIds);
      }
    }
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
            onDelete: widget.onDelete == null
                ? null
                : () => widget.onDelete!(table),
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
    return TransferStatusIcons(statusText: status);
  }
}
