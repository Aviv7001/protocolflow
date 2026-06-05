import 'package:flutter/material.dart';
import '../../../models/reagent_mix_wizard.dart';
import '../../../widgets/table_export_actions.dart';

class ReagentResultTable extends StatelessWidget {
  final ReagentMixWizard wizard;

  const ReagentResultTable({super.key, required this.wizard});

  @override
  Widget build(BuildContext context) {
    if (wizard.reagents.isEmpty) return const SizedBox.shrink();

    final table = wizard.generateTable();

    return TableExportActions(
      table: table,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            columns: table.columnHeaders
                .map(
                  (h) => DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
                .toList(),
            rows: table.data
                .map(
                  (row) => DataRow(
                    cells: row
                        .map(
                          (cell) => DataCell(
                            Text(
                              cell.toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
