import 'package:flutter/material.dart';
import '../models/protocol_table.dart';
import '../theme/app_colors.dart';
import 'horizontal_table_scroll.dart';
import 'protocolflow_ui.dart';
import 'table_export_actions.dart';
import 'transfer_status_icons.dart';

class GenericResultTable extends StatelessWidget {
  final ProtocolTable table;

  const GenericResultTable({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    if (table.data.isEmpty) return const SizedBox.shrink();
    final columnCount = table.columnHeaders.isNotEmpty
        ? table.columnHeaders.length
        : table.data.fold<int>(
            0,
            (max, row) => row.length > max ? row.length : max,
          );
    if (columnCount == 0) return const SizedBox.shrink();

    return TableExportActions(
      table: table,
      includeRowHeaders: true,
      child: ProtocolFlowTableCard(
        title: null,
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
              ...List.generate(
                columnCount,
                (index) => DataColumn(
                  label: Text(
                    index < table.columnHeaders.length
                        ? table.columnHeaders[index]
                        : _columnName(index),
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
                      rIdx < table.rowHeaders.length
                          ? table.rowHeaders[rIdx]
                          : '${rIdx + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  ...List.generate(columnCount, (cellIndex) {
                    final cell = cellIndex < row.length ? row[cellIndex] : '';
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
    return TransferStatusIcons(statusText: status);
  }

  String _columnName(int index) {
    var value = index + 1;
    final chars = <String>[];
    while (value > 0) {
      value--;
      chars.insert(0, String.fromCharCode(65 + (value % 26)));
      value ~/= 26;
    }
    return chars.join();
  }
}
