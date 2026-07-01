import 'package:flutter/material.dart';
import '../services/master_mix_calculator_service.dart';
import '../../../models/master_mix_wizard.dart';
import '../../../widgets/table_export_actions.dart';
import '../../../theme/app_colors.dart';

class MasterMixResultTable extends StatelessWidget {
  final MasterMixWizard wizard;
  final MasterMixCalculatorService calculator;

  const MasterMixResultTable({
    super.key,
    required this.wizard,
    required this.calculator,
  });

  @override
  Widget build(BuildContext context) {
    final res = calculator.calculateMasterMix(
      MasterMixInput(
        mixName: wizard.mixName,
        finalVolume: wizard.finalVolume,
        finalVolumeUnit: wizard.finalVolumeUnit,
        extraVolumePercent: wizard.extraVolumePercent,
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

    return TableExportActions(
      table: wizard.generateTable(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Output Table', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: AppColors.outlineVariant),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(2.5),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                ),
                children: [
                  _cellPadding(
                    const Text(
                      'Reagent',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _cellPadding(
                    const Text(
                      'Stock',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _cellPadding(
                    const Text(
                      'Final',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _cellPadding(
                    const Text(
                      'Volume',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _cellPadding(
                    const Text(
                      'Suggestion',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              ...res.reagentResults.map(
                (r) => TableRow(
                  children: [
                    _cellPadding(
                      Text(r.reagentName, style: const TextStyle(fontSize: 12)),
                    ),
                    _cellPadding(
                      Text(
                        r.formattedStockConcentration,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    _cellPadding(
                      Text(
                        r.formattedFinalConcentration,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    _cellPadding(
                      Text(
                        r.formattedReagentVolume,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _cellPadding(
                      Text(
                        r.suggestions.isEmpty
                            ? ''
                            : r.suggestions.first.message,
                        style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TableRow(
                children: [
                  _cellPadding(
                    Text(
                      wizard.baseSolventName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  _cellPadding(const Text('-', style: TextStyle(fontSize: 12))),
                  _cellPadding(const Text('-', style: TextStyle(fontSize: 12))),
                  _cellPadding(
                    Text(
                      res.formattedBaseSolventVolume,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _cellPadding(const SizedBox.shrink()),
                ],
              ),
              TableRow(
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                ),
                children: [
                  _cellPadding(
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _cellPadding(const SizedBox.shrink()),
                  _cellPadding(const SizedBox.shrink()),
                  _cellPadding(
                    Text(
                      res.formattedOptimizedFinalVolume,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _cellPadding(const SizedBox.shrink()),
                ],
              ),
            ],
          ),
          if (res.warnings.isNotEmpty ||
              res.reagentResults.any(
                (r) => r.warnings.isNotEmpty || r.suggestions.isNotEmpty,
              )) ...[
            const SizedBox(height: 16),
            ...res.warnings.map((w) => _warningItem(w)),
            ...res.reagentResults.expand(
              (r) =>
                  r.warnings.map((w) => _warningItem('${r.reagentName}: $w')),
            ),
            ...res.reagentResults.expand(
              (r) => r.suggestions.map(
                (s) => _suggestionItem('${r.reagentName}: ${s.message}'),
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

  Widget _cellPadding(Widget child) {
    return Padding(padding: const EdgeInsets.all(8.0), child: child);
  }
}
