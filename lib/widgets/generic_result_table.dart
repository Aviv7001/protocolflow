import 'package:flutter/material.dart';
import '../models/protocol_table.dart';
import '../theme/app_colors.dart';
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
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
                  ...row.map((cell) {
                    return DataCell(
                      Text(
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
}
