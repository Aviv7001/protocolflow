import 'package:flutter/material.dart';
import '../../../models/reagent_mix_wizard.dart';
import '../../../models/protocol_table.dart';
import '../../measuring_tools/services/transfer_optimizer_service.dart';
import '../services/reagent_mix_calculator_service.dart';
import '../../../widgets/horizontal_table_scroll.dart';
import '../../../widgets/table_export_actions.dart';
import '../../../theme/app_colors.dart';

class ReagentResultTable extends StatelessWidget {
  final ReagentMixWizard wizard;
  final bool showExportActions;
  final ProtocolTable? tableOverride;

  const ReagentResultTable({
    super.key,
    required this.wizard,
    this.showExportActions = true,
    this.tableOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (wizard.reagents.isEmpty) return const SizedBox.shrink();

    final table = tableOverride ?? wizard.generateTable();
    final calculator = ReagentMixCalculatorService();
    final results = wizard.reagents.map((reagent) {
      final input = ReagentMixInput(
        reagentName: reagent.name,
        stockConcentration: reagent.stockConc,
        stockUnit: reagent.stockUnit,
        workingConcentration: reagent.workingConc,
        workingUnit: reagent.workingUnit,
        volumePerTube: reagent.volPerSample,
        volumePerTubeUnit: reagent.volUnit,
        numberOfTubes: reagent.numSamples,
        extraVolumePercent: wizard.extraVolumePercent,
        autoExtraVolume: wizard.autoExtraVolume,
        molecularWeight: reagent.molecularWeight,
      );
      return reagent.preparationType == ReagentPreparationType.solidSuspension
          ? calculator.calculateSuspension(input)
          : calculator.calculateMix(input);
    }).toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: HorizontalTableScroll(
            child: DataTable(
              border: TableBorder.all(color: AppColors.outlineVariant),
              columnSpacing: 20,
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.surfaceContainer,
              ),
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
              rows: table.data.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final row = entry.value;
                return DataRow(
                  cells: row.asMap().entries.map((cellEntry) {
                    final isStatus =
                        table.columnHeaders[cellEntry.key] == 'Status';
                    if (isStatus && rowIndex < results.length) {
                      final result = results[rowIndex];
                      return DataCell(
                        _statusIcons(
                          warnings: result.warnings,
                          suggestions: result.suggestions,
                          evaluation: result.reagentTransferEvaluation,
                        ),
                      );
                    }
                    return DataCell(
                      Text(
                        cellEntry.value.toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
        if (results.any(
          (r) =>
              r.warnings.isNotEmpty ||
              r.suggestions.isNotEmpty ||
              r.autoExtraVolumeReason != null,
        )) ...[
          const SizedBox(height: 12),
          ...results
              .where((result) => result.autoExtraVolumeReason != null)
              .map((result) => _suggestionItem(result.autoExtraVolumeReason!)),
          ...results.asMap().entries.expand((entry) {
            final name = wizard.reagents[entry.key].name;
            final label = name.isEmpty ? 'Row ${entry.key + 1}' : name;
            final result = entry.value;
            return [
              ...result.warnings.map((w) => _warningItem('$label: $w')),
              ...result.suggestions.map(
                (s) => _suggestionItem('$label: ${s.message}'),
              ),
            ];
          }),
        ],
      ],
    );

    if (!showExportActions) return content;

    return TableExportActions(table: table, child: content);
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

  Widget _warningItem(String text) {
    return _noteItem(Icons.warning_amber, AppColors.warning, text);
  }

  Widget _suggestionItem(String text) {
    return _noteItem(Icons.tips_and_updates, AppColors.info, text);
  }

  Widget _noteItem(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }
}
