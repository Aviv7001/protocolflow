import 'package:flutter/material.dart';
import '../models/protocol_table.dart';
import '../theme/app_colors.dart';
import 'horizontal_table_scroll.dart';
import 'table_export_actions.dart';

class GenericResultTable extends StatelessWidget {
  final ProtocolTable table;

  const GenericResultTable({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    if (table.data.isEmpty) return const SizedBox.shrink();

    return TableExportActions(
      table: table,
      includeRowHeaders: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: HorizontalTableScroll(
          child: DataTable(
            border: TableBorder.all(color: AppColors.outlineVariant),
            columnSpacing: 20,
            headingRowColor: const WidgetStatePropertyAll(
              AppColors.surfaceContainer,
            ),
            columns: [
              const DataColumn(
                label: Text(
                  '#',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              ...table.columnHeaders.map(
                (h) => DataColumn(
                  label: Text(
                    h,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
            rows: table.data.asMap().entries.map((entry) {
              final rIdx = entry.key;
              final row = entry.value;
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      table.rowHeaders[rIdx],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  ...row.asMap().entries.map((cellEntry) {
                    final cellIndex = cellEntry.key;
                    final cell = cellEntry.value;
                    final isStatusColumn =
                        cellIndex < table.columnHeaders.length &&
                        table.columnHeaders[cellIndex] == 'Status';
                    return DataCell(
                      isStatusColumn
                          ? _statusIcons(cell.toString())
                          : Text(
                              cell.toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
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
