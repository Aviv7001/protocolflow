import 'package:flutter/material.dart';

import '../../../models/master_mix_wizard.dart';
import '../../../models/protocol_table.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/horizontal_table_scroll.dart';
import '../../../widgets/table_export_actions.dart';
import '../../../widgets/transfer_status_icons.dart';
import '../../lab_math/lab_calculation.dart';
import '../../measuring_tools/services/mass_measurement_optimizer_service.dart';
import '../services/master_mix_calculator_service.dart';

class MasterMixResultTable extends StatelessWidget {
  final MasterMixWizard wizard;
  final MasterMixCalculatorService calculator;
  final bool showExportActions;
  final ProtocolTable? tableOverride;

  const MasterMixResultTable({
    super.key,
    required this.wizard,
    required this.calculator,
    this.showExportActions = true,
    this.tableOverride,
  });

  @override
  Widget build(BuildContext context) {
    final results = [
      for (final mix in wizard.mixes)
        _MixCalculation(mix, calculator.calculateMasterMix(mix.toInput())),
    ];

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
                DataColumn(label: _HeaderCell('Mix')),
                DataColumn(label: _HeaderCell('Reagent')),
                DataColumn(label: _HeaderCell('Stock')),
                DataColumn(label: _HeaderCell('Final')),
                DataColumn(label: _HeaderCell('Amount')),
                DataColumn(label: _HeaderCell('Transfer')),
                DataColumn(label: _HeaderCell('Tool')),
                DataColumn(label: _HeaderCell('Status')),
              ],
              rows: [for (final item in results) ..._rowsForMix(item)],
            ),
          ),
        ),
        for (final item in results) ...[
          if (item.result.autoExtraVolumeReason != null) ...[
            const SizedBox(height: 8),
            _suggestionItem(
              '${item.mix.mixName}: ${item.result.autoExtraVolumeReason!}',
            ),
          ],
          if (!item.result.success) ...[
            const SizedBox(height: 8),
            _warningItem(
              '${item.mix.mixName}: ${item.result.errorMessage ?? 'Calculation failed'}',
            ),
          ],
          if (item.result.warnings.isNotEmpty ||
              item.result.reagentResults.any(
                (r) => r.suggestions.isNotEmpty,
              )) ...[
            const SizedBox(height: 8),
            ...item.result.warnings.toSet().map(
              (w) => _warningItem('${item.mix.mixName}: $w'),
            ),
            ...item.result.reagentResults.expand(
              (r) => r.suggestions.map(
                (s) => _suggestionItem(
                  '${item.mix.mixName} / ${r.reagentName}: ${s.message}',
                ),
              ),
            ),
          ],
        ],
      ],
    );

    if (!showExportActions) return content;

    return TableExportActions(
      table: tableOverride ?? wizard.generateTable(),
      child: content,
    );
  }

  List<DataRow> _rowsForMix(_MixCalculation item) {
    final mix = item.mix;
    final res = item.result;

    if (!res.success) {
      return [
        DataRow(
          cells: [
            DataCell(_CellText(mix.mixName)),
            const DataCell(_ErrorCell('Error')),
            DataCell(_CellText(res.errorMessage ?? 'Calculation failed')),
            const DataCell(_CellText('-')),
            const DataCell(_CellText('-')),
            const DataCell(_CellText('-')),
            const DataCell(_CellText('-')),
            const DataCell(SizedBox.shrink()),
          ],
        ),
      ];
    }

    return [
      ...res.reagentResults.map(
        (r) => DataRow(
          cells: [
            DataCell(_CellText(mix.mixName)),
            DataCell(_CellText(r.reagentName)),
            DataCell(_CellText(r.formattedStockConcentration)),
            DataCell(_CellText(r.formattedFinalConcentration)),
            DataCell(
              _CellText(
                r.formattedReagentVolume,
                color: AppColors.primary,
                bold: true,
              ),
            ),
            DataCell(_CellText(_transferLabel(r.transferEvaluation))),
            DataCell(
              _CellText(
                r.massEvaluation?.recommendedToolName ??
                    r.transferEvaluation?.recommendedToolName ??
                    '-',
              ),
            ),
            DataCell(
              TransferStatusIcons(
                warnings: r.warnings,
                suggestions: r.suggestions,
                evaluation: r.transferEvaluation,
                statusText: r.massEvaluation?.status.label,
              ),
            ),
          ],
        ),
      ),
      DataRow(
        cells: [
          DataCell(_CellText(mix.mixName)),
          DataCell(_CellText(mix.baseSolventName)),
          const DataCell(_CellText('-')),
          const DataCell(_CellText('-')),
          DataCell(_CellText(res.formattedBaseSolventVolume, bold: true)),
          DataCell(_CellText(_transferLabel(res.solventTransferEvaluation))),
          DataCell(
            _CellText(
              res.solventTransferEvaluation?.recommendedToolName ?? '-',
            ),
          ),
          const DataCell(SizedBox.shrink()),
        ],
      ),
      DataRow(
        color: const WidgetStatePropertyAll(AppColors.primaryContainer),
        cells: [
          DataCell(_CellText(mix.mixName, bold: true)),
          const DataCell(_CellText('TOTAL', bold: true)),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          DataCell(_CellText(res.formattedOptimizedFinalVolume, bold: true)),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
        ],
      ),
    ];
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

class _MixCalculation {
  final MasterMixItem mix;
  final MasterMixResult result;

  const _MixCalculation(this.mix, this.result);
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

class _CellText extends StatelessWidget {
  final String text;
  final Color? color;
  final bool bold;

  const _CellText(this.text, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: bold ? FontWeight.bold : null,
      ),
    );
  }
}

class _ErrorCell extends StatelessWidget {
  final String text;

  const _ErrorCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.error,
        fontWeight: FontWeight.bold,
        fontSize: 10,
      ),
    );
  }
}
