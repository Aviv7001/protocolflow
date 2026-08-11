import 'package:flutter/material.dart';

import '../models/serial_dilution_input.dart';
import '../services/serial_dilution_calculator_service.dart';
import '../../../models/protocol_table.dart';
import '../../../widgets/horizontal_table_scroll.dart';
import '../../../widgets/table_export_actions.dart';
import '../../../widgets/transfer_status_icons.dart';
import '../../../theme/app_colors.dart';
import '../../lab_math/lab_calculation.dart';
import '../../measuring_tools/services/mass_measurement_optimizer_service.dart';

class SerialDilutionResultTable extends StatelessWidget {
  final SerialDilutionInput input;
  final SerialDilutionCalculatorService calculator;
  final bool showExportActions;
  final ProtocolTable? tableOverride;

  const SerialDilutionResultTable({
    super.key,
    required this.input,
    required this.calculator,
    this.showExportActions = true,
    this.tableOverride,
  });

  @override
  Widget build(BuildContext context) {
    final result = calculator.generateDilutionTable(input);

    if (!result.success) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Output Table', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: HorizontalTableScroll(
            child: DataTable(
              border: TableBorder.all(color: AppColors.outlineVariant),
              columnSpacing: 20,
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.surfaceContainer,
              ),
              columns: const [
                DataColumn(label: _HeaderCell('Dilution')),
                DataColumn(label: _HeaderCell('Concentration')),
                DataColumn(label: _HeaderCell('Transfer From')),
                DataColumn(label: _HeaderCell('Transfer Amount')),
                DataColumn(label: _HeaderCell('Solvent')),
                DataColumn(label: _HeaderCell('Final')),
                DataColumn(label: _HeaderCell('Suggested')),
                DataColumn(label: _HeaderCell('Tool')),
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
                            _transferLabel(row.transferEvaluation),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.massEvaluation?.recommendedToolName ??
                                row.transferEvaluation?.recommendedToolName ??
                                '-',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        DataCell(
                          TransferStatusIcons(
                            warnings: row.warnings,
                            suggestions: row.suggestions,
                            evaluation: row.transferEvaluation,
                            statusText: row.massEvaluation?.status.label,
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
        if (result.autoExtraVolumeReason != null) ...[
          const SizedBox(height: 8),
          _suggestionItem(result.autoExtraVolumeReason!),
        ],
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
    );

    if (!showExportActions) return content;

    return TableExportActions(
      table: tableOverride ?? input.generateTable(),
      child: content,
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
    final icon = text.toLowerCase().contains('auto-selected')
        ? Icons.auto_fix_high
        : Icons.science_outlined;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.info),
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

  String _transferLabel(dynamic evaluation) {
    if (evaluation?.transferVolumePerRepeatUl == null) return '-';
    final perRepeat = evaluation.transferVolumePerRepeatUl as double;
    final repeats = evaluation.repeats as int? ?? 1;
    final label = LabCalculation.formatVolume(perRepeat, unicodeMicro: true);
    return repeats > 1 ? '$label x $repeats' : label;
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
