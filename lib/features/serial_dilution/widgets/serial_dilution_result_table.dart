import 'package:flutter/material.dart';

import '../models/serial_dilution_input.dart';
import '../services/serial_dilution_calculator_service.dart';

class SerialDilutionResultTable extends StatelessWidget {
  final SerialDilutionInput input;
  final SerialDilutionCalculatorService calculator;

  const SerialDilutionResultTable({
    super.key,
    required this.input,
    required this.calculator,
  });

  @override
  Widget build(BuildContext context) {
    final result = calculator.generateDilutionTable(input);

    if (!result.success) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          result.errorMessage ?? 'Error in calculation',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Output Table', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
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
              columns: const [
                DataColumn(label: _HeaderCell('Dilution')),
                DataColumn(label: _HeaderCell('Concentration')),
                DataColumn(label: _HeaderCell('Transfer From')),
                DataColumn(label: _HeaderCell('Transfer')),
                DataColumn(label: _HeaderCell('Solvent')),
                DataColumn(label: _HeaderCell('Final')),
              ],
              rows: result.rows
                  .map(
                    (row) => DataRow(
                      color: row.isZeroConcentrationRow
                          ? WidgetStateProperty.all(Colors.blue.shade50)
                          : null,
                      cells: [
                        DataCell(
                          Text(
                            row.dilutionName,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.formattedConcentration,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.transferFrom,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.formattedTransferVolume,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.formattedSolventVolume,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.formattedFinalVolume,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryItem(
              label: 'Dilutions',
              value: result.calculatedNumberOfDilutions.toString(),
            ),
            const SizedBox(width: 24),
            _SummaryItem(
              label: 'Optimized final volume',
              value: result.formattedOptimizedFinalVolume,
            ),
          ],
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...result.warnings.map((w) => _warningItem(w)),
        ],
      ],
    );
  }

  Widget _warningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 14, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
