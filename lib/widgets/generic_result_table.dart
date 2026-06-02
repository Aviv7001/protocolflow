import 'package:flutter/material.dart';
import '../models/protocol_table.dart';

class GenericResultTable extends StatelessWidget {
  final ProtocolTable table;

  const GenericResultTable({
    super.key,
    required this.table,
  });

  @override
  Widget build(BuildContext context) {
    if (table.data.isEmpty) return const SizedBox.shrink();

    return Card(
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
          columns: [
            const DataColumn(
                label: Text('#',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            ...table.columnHeaders.map((h) => DataColumn(
                label: Text(h,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.blue)))),
          ],
          rows: table.data.asMap().entries.map((entry) {
            final rIdx = entry.key;
            final row = entry.value;
            return DataRow(
              cells: [
                DataCell(Text(table.rowHeaders[rIdx],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.blue))),
                ...row.map((cell) {
                  return DataCell(Text(
                    cell.toString(),
                    style: const TextStyle(fontSize: 10),
                  ));
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
