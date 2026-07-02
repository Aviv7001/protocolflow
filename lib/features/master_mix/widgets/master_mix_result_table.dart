import 'package:flutter/material.dart';
import '../services/master_mix_calculator_service.dart';
import '../../../models/master_mix_wizard.dart';
import '../../../models/protocol_table.dart';
import '../../../widgets/horizontal_table_scroll.dart';
import '../../../widgets/table_export_actions.dart';
import '../../../theme/app_colors.dart';
import '../../lab_math/lab_calculation.dart';
import '../../measuring_tools/services/transfer_optimizer_service.dart';

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
    final res = calculator.calculateMasterMix(
      MasterMixInput(
        mixName: wizard.mixName,
        finalVolume: wizard.finalVolume,
        finalVolumeUnit: wizard.finalVolumeUnit,
        extraVolumePercent: wizard.extraVolumePercent,
        autoExtraVolume: wizard.autoExtraVolume,
        baseSolventName: wizard.baseSolventName,
        reagents: wizard.reagents.map((r) => r.toInput()).toList(),
      ),
    );

    if (!res.success) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error),
        ),
        child: Text(
          res.errorMessage ?? 'Error in calculation',
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
                DataColumn(label: _HeaderCell('Reagent')),
                DataColumn(label: _HeaderCell('Stock')),
                DataColumn(label: _HeaderCell('Final')),
                DataColumn(label: _HeaderCell('Volume')),
                DataColumn(label: _HeaderCell('Transfer')),
                DataColumn(label: _HeaderCell('Tool')),
                DataColumn(label: _HeaderCell('Status')),
              ],
              rows: [
                ...res.reagentResults.map(
                  (r) => DataRow(
                    cells: [
                      DataCell(
                        Text(
                          r.reagentName,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(
                        Text(
                          r.formattedStockConcentration,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(
                        Text(
                          r.formattedFinalConcentration,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(
                        Text(
                          r.formattedReagentVolume,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _transferLabel(r.transferEvaluation),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(
                        Text(
                          r.transferEvaluation?.recommendedToolName ?? '-',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(
                        _statusIcons(
                          warnings: r.warnings,
                          suggestions: r.suggestions,
                          evaluation: r.transferEvaluation,
                        ),
                      ),
                    ],
                  ),
                ),
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        wizard.baseSolventName,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const DataCell(Text('-', style: TextStyle(fontSize: 10))),
                    const DataCell(Text('-', style: TextStyle(fontSize: 10))),
                    DataCell(
                      Text(
                        res.formattedBaseSolventVolume,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _transferLabel(res.solventTransferEvaluation),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    DataCell(
                      Text(
                        res.solventTransferEvaluation?.recommendedToolName ??
                            '-',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const DataCell(SizedBox.shrink()),
                  ],
                ),
                DataRow(
                  color: const WidgetStatePropertyAll(
                    AppColors.primaryContainer,
                  ),
                  cells: [
                    const DataCell(
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const DataCell(SizedBox.shrink()),
                    const DataCell(SizedBox.shrink()),
                    DataCell(
                      Text(
                        res.formattedOptimizedFinalVolume,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const DataCell(SizedBox.shrink()),
                    const DataCell(SizedBox.shrink()),
                    const DataCell(SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (res.autoExtraVolumeReason != null) ...[
          const SizedBox(height: 8),
          _suggestionItem(res.autoExtraVolumeReason!),
        ],
        if (res.warnings.isNotEmpty ||
            res.reagentResults.any(
              (r) => r.warnings.isNotEmpty || r.suggestions.isNotEmpty,
            )) ...[
          const SizedBox(height: 16),
          ...res.warnings.map((w) => _warningItem(w)),
          ...res.reagentResults.expand(
            (r) => r.warnings.map((w) => _warningItem('${r.reagentName}: $w')),
          ),
          ...res.reagentResults.expand(
            (r) => r.suggestions.map(
              (s) => _suggestionItem('${r.reagentName}: ${s.message}'),
            ),
          ),
        ],
      ],
    );

    if (!showExportActions) return content;

    return TableExportActions(
      table: tableOverride ?? wizard.generateTable(),
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

  Widget _statusIcons({
    required List<String> warnings,
    required List<dynamic> suggestions,
    dynamic evaluation,
  }) {
    final status = evaluation?.status;
    final hasWarning =
        warnings.isNotEmpty ||
        status == TransferStatus.cautionLowRange ||
        status == TransferStatus.cautionRepeatedTransfer ||
        status == TransferStatus.warningNoCompatibleTool;
    final hasSuggestion =
        suggestions.isNotEmpty || evaluation?.suggestionMessage != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasWarning)
          const Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
        if (hasWarning && hasSuggestion) const SizedBox(width: 4),
        if (hasSuggestion)
          const Icon(Icons.tips_and_updates, size: 16, color: AppColors.info),
      ],
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
