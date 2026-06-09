import 'package:flutter/material.dart';
import '../models/staining_wizard.dart';
import '../services/staining_table_generator_service.dart';
import '../../../widgets/table_export_actions.dart';

class StainingResultTable extends StatelessWidget {
  final StainingWizard wizard;
  final StainingTableGeneratorService generator;

  const StainingResultTable({
    super.key,
    required this.wizard,
    required this.generator,
  });

  @override
  Widget build(BuildContext context) {
    final result = generator.generateTable(wizard);

    if (result.rows.isEmpty) {
      return const Center(child: Text('No staining data to display.'));
    }

    return TableExportActions(
      table: wizard.generateTable(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            dataRowMinHeight: 48,
            dataRowMaxHeight: 48,
            columns: [
              const DataColumn(label: Text('Tube/sample name')),
              const DataColumn(label: Text('Total stains')),
              ...result.stainColumns.map((col) => DataColumn(label: Text(col))),
            ],
            rows: [
              ...result.rows.map(
                (row) => DataRow(
                  cells: [
                    DataCell(
                      Text(
                        row.rowName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(
                      Text(
                        row.totalStainsText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    ...result.stainColumns.map((col) {
                      final isPositive = row.stainMap[col] ?? false;
                      return DataCell(
                        Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? Colors.green.shade500
                                  : Colors.red.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPositive ? '+' : '-',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // Metadata Rows
              ...result.metadataRows.map(
                (row) => DataRow(
                  color: WidgetStateProperty.all(Colors.grey.shade50),
                  cells: [
                    DataCell(
                      Text(
                        row.rowName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const DataCell(Text('')),
                    ...result.stainColumns.map((col) {
                      final val = row.metadataValues[col] ?? '';
                      return DataCell(
                        Center(
                          child: Text(
                            val,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
