import 'package:flutter/material.dart';

import '../models/serial_dilution_input.dart';
import '../services/serial_dilution_calculator_service.dart';
import '../../../widgets/table_export_actions.dart';
import '../../../theme/app_colors.dart';

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
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error),
        ),
        child: Text(
          result.errorMessage ?? 'Error in calculation',
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return TableExportActions(
      table: input.generateTable(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Output Table', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: const WidgetStatePropertyAll(
                  AppColors.surfaceContainer,
                ),
                columns: const [
                  DataColumn(label: _HeaderCell('Dilution')),
                  DataColumn(label: _HeaderCell('Concentration')),
                  DataColumn(label: _HeaderCell('Transfer From')),
                  DataColumn(label: _HeaderCell('Transfer')),
                  DataColumn(label: _HeaderCell('Solvent')),
                  DataColumn(label: _HeaderCell('Final')),
                  DataColumn(label: _HeaderCell('Suggestion')),
                ],
                rows: result.rows
                    .map(
                      (row) => DataRow(
                        color: row.isZeroConcentrationRow
                            ? const WidgetStatePropertyAll(
                                AppColors.primaryContainer,
                              )
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
                                color: AppColors.primary,
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
                          DataCell(
                            Text(
                              row.suggestions.isEmpty
                                  ? ''
                                  : row.suggestions.first.message,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.info,
                              ),
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
          if (result.warnings.isNotEmpty ||
              result.rows.any((row) => row.suggestions.isNotEmpty)) ...[
            const SizedBox(height: 16),
            ...result.warnings.map((w) => _warningItem(w)),
            ...result.rows.expand(
              (row) => row.suggestions.map(
                (s) => _suggestionItem('${row.dilutionName}: ${s.message}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _warningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 14, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates, size: 14, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: AppColors.info),
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
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
