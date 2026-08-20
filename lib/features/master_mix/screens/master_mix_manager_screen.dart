import 'package:flutter/material.dart';

import '../../../models/master_mix_wizard.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/unsaved_changes_pop_scope.dart';
import '../../../widgets/protocolflow_app_bar.dart';
import '../../../widgets/table_workspace.dart';
import '../../lab_math/lab_calculation.dart';
import '../../lab_math/widgets/concentration_input_row.dart';
import '../services/master_mix_calculator_service.dart';
import '../widgets/master_mix_result_table.dart';

class MasterMixManagerScreen extends StatefulWidget {
  final MasterMixWizard wizard;
  final Function(MasterMixWizard) onUpdate;
  final bool promptForSaveDetails;

  const MasterMixManagerScreen({
    super.key,
    required this.wizard,
    required this.onUpdate,
    this.promptForSaveDetails = true,
  });

  @override
  State<MasterMixManagerScreen> createState() => _MasterMixManagerScreenState();
}

class _MasterMixManagerScreenState extends State<MasterMixManagerScreen> {
  late MasterMixWizard _wizard;
  final MasterMixCalculatorService _calculator = MasterMixCalculatorService();
  static const double _uniformFontSize = 14.0;
  static const List<ConcentrationUnit> _masterMixConcentrationUnits = [
    ConcentrationUnit.M,
    ConcentrationUnit.mM,
    ConcentrationUnit.uM,
    ConcentrationUnit.nM,
    ConcentrationUnit.pM,
    ConcentrationUnit.gL,
    ConcentrationUnit.mgML,
    ConcentrationUnit.ugML,
    ConcentrationUnit.ngML,
    ConcentrationUnit.percent,
    ConcentrationUnit.X,
    ConcentrationUnit.ratio,
    ConcentrationUnit.cellsML,
  ];
  static const List<ConcentrationUnit> _solidConcentrationUnits = [
    ConcentrationUnit.M,
    ConcentrationUnit.mM,
    ConcentrationUnit.uM,
    ConcentrationUnit.nM,
    ConcentrationUnit.pM,
    ConcentrationUnit.gL,
    ConcentrationUnit.mgML,
    ConcentrationUnit.ugML,
    ConcentrationUnit.ngML,
    ConcentrationUnit.percent,
  ];
  bool _canActuallyPop = false;
  final Set<int> _collapsedMixIndexes = {};

  @override
  void initState() {
    super.initState();
    final initialWizard = widget.wizard.mixes.isEmpty
        ? widget.wizard.copyWith(mixes: [MasterMixItem()])
        : widget.wizard;
    _wizard = initialWizard.copyWith(
      mixes: initialWizard.mixes
          .map(
            (mix) => mix.copyWith(
              reagents: mix.reagents.map(_normalizeReagentForEditor).toList(),
            ),
          )
          .toList(),
    );
  }

  void _addMix() {
    setState(() {
      _wizard = _wizard.copyWith(
        mixes: [
          ..._wizard.mixes,
          MasterMixItem(mixName: 'Mix ${_wizard.mixes.length + 1}'),
        ],
      );
    });
  }

  void _removeMix(int mixIndex) {
    if (_wizard.mixes.length <= 1) return;
    setState(() {
      final mixes = List<MasterMixItem>.from(_wizard.mixes)..removeAt(mixIndex);
      final collapsed = _collapsedMixIndexes.toList()..sort();
      _collapsedMixIndexes
        ..clear()
        ..addAll(
          collapsed
              .where((index) => index != mixIndex)
              .map((index) => index > mixIndex ? index - 1 : index),
        );
      _wizard = _wizard.copyWith(mixes: mixes);
    });
  }

  void _toggleMixCollapsed(int mixIndex) {
    setState(() {
      if (_collapsedMixIndexes.contains(mixIndex)) {
        _collapsedMixIndexes.remove(mixIndex);
      } else {
        _collapsedMixIndexes.add(mixIndex);
      }
    });
  }

  void _updateMix(int mixIndex, MasterMixItem mix) {
    setState(() {
      final mixes = List<MasterMixItem>.from(_wizard.mixes);
      mixes[mixIndex] = mix;
      _wizard = _wizard.copyWith(mixes: mixes);
    });
  }

  void _addReagent(int mixIndex) {
    final mix = _wizard.mixes[mixIndex];
    var lastStockUnit = ConcentrationUnit.mM;
    var lastFinalUnit = ConcentrationUnit.uM;

    if (mix.reagents.isNotEmpty) {
      final last = mix.reagents.last;
      lastStockUnit = last.stockUnit;
      lastFinalUnit = last.finalUnit;
    }

    _updateMix(
      mixIndex,
      mix.copyWith(
        reagents: [
          ...mix.reagents,
          MasterMixReagentItem(
            name: 'Reagent ${mix.reagents.length + 1}',
            stockUnit: lastStockUnit,
            finalUnit: lastFinalUnit,
          ),
        ],
      ),
    );
  }

  void _removeReagent(int mixIndex, int reagentIndex) {
    final mix = _wizard.mixes[mixIndex];
    final reagents = List<MasterMixReagentItem>.from(mix.reagents)
      ..removeAt(reagentIndex);
    _updateMix(mixIndex, mix.copyWith(reagents: reagents));
  }

  void _updateReagent(
    int mixIndex,
    int reagentIndex,
    MasterMixReagentItem reagent,
  ) {
    final mix = _wizard.mixes[mixIndex];
    final reagents = List<MasterMixReagentItem>.from(mix.reagents);
    reagents[reagentIndex] = reagent;
    _updateMix(mixIndex, mix.copyWith(reagents: reagents));
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesPopScope(
      canPop: _canActuallyPop,
      message:
          'You have unsaved changes in this table. Are you sure you want to exit?',
      child: Scaffold(
        appBar: ProtocolFlowAppBar(
          title: 'Master Mix Manager',
          actions: [
            IconButton(
              tooltip: 'Save table',
              icon: const Icon(Icons.save),
              onPressed: () => _handleDone(context),
            ),
          ],
        ),
        body: ResponsiveTableManagerLayout(
          controlsKey: const ValueKey('table-manager-controls'),
          previewKey: const ValueKey('table-manager-preview'),
          controls: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTableNameCard(),
              const SizedBox(height: 12),
              ..._wizard.mixes.asMap().entries.map(
                (entry) => _buildMixCard(entry.key, entry.value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: FilledButton.icon(
                  onPressed: _addMix,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Mix',
                    style: TextStyle(fontSize: _uniformFontSize),
                  ),
                ),
              ),
            ],
          ),
          preview: MasterMixResultTable(
            wizard: _wizard,
            calculator: _calculator,
          ),
        ),
      ),
    );
  }

  Widget _buildTableNameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _DelayedTextField(
          decoration: const InputDecoration(labelText: 'Table Name'),
          initialValue: _wizard.tableName,
          style: const TextStyle(fontSize: _uniformFontSize),
          onCommit: (v) =>
              setState(() => _wizard = _wizard.copyWith(tableName: v)),
        ),
      ),
    );
  }

  Widget _buildMixCard(int mixIndex, MasterMixItem mix) {
    final result = _calculator.calculateMasterMix(mix.toInput());
    final isCollapsed = _collapsedMixIndexes.contains(mixIndex);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mix.mixName.isEmpty ? 'Mix ${mixIndex + 1}' : mix.mixName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: isCollapsed ? 'Expand mix' : 'Shrink mix',
                  icon: Icon(
                    isCollapsed ? Icons.expand_more : Icons.expand_less,
                  ),
                  onPressed: () => _toggleMixCollapsed(mixIndex),
                ),
                if (_wizard.mixes.length > 1)
                  IconButton(
                    tooltip: 'Remove mix',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () => _removeMix(mixIndex),
                  ),
              ],
            ),
            if (isCollapsed) ...[
              const SizedBox(height: 4),
              Text(
                '${mix.reagents.length} reagent${mix.reagents.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (!isCollapsed) ...[
              const SizedBox(height: 12),
              _DelayedTextField(
                decoration: const InputDecoration(labelText: 'Mix Name'),
                initialValue: mix.mixName,
                style: const TextStyle(fontSize: _uniformFontSize),
                onCommit: (v) => _updateMix(mixIndex, mix.copyWith(mixName: v)),
              ),
              const SizedBox(height: 12),
              _DelayedTextField(
                initialValue: mix.baseSolventName,
                decoration: const InputDecoration(
                  labelText: 'Base Solvent Name',
                ),
                style: const TextStyle(fontSize: _uniformFontSize),
                onCommit: (v) =>
                    _updateMix(mixIndex, mix.copyWith(baseSolventName: v)),
              ),
              const SizedBox(height: 12),
              _buildVolumeRow(mixIndex, mix),
              const SizedBox(height: 12),
              _DelayedTextField(
                initialValue: mix.extraVolumePercent.toString(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Extra Volume %'),
                style: const TextStyle(fontSize: _uniformFontSize),
                onCommit: (v) => _updateMix(
                  mixIndex,
                  mix.copyWith(extraVolumePercent: double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Optimize extra volume'),
                subtitle: const Text(
                  'Try 10% to 30% and choose the best transfer score',
                ),
                value: mix.autoExtraVolume,
                onChanged: (value) =>
                    _updateMix(mixIndex, mix.copyWith(autoExtraVolume: value)),
              ),
              if (result.success) ...[
                const SizedBox(height: 8),
                _buildMixResultPreview(mixIndex, mix, result),
              ],
              ...mix.reagents.asMap().entries.map(
                (entry) => _buildReagentEditor(
                  mixIndex,
                  entry.key,
                  entry.value,
                  result,
                ),
              ),
              const Divider(height: 32),
              _buildAddReagentButton(mixIndex),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeRow(int mixIndex, MasterMixItem mix) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _DelayedTextField(
            initialValue: mix.finalVolume.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Final Volume'),
            style: const TextStyle(fontSize: _uniformFontSize),
            onCommit: (v) => _updateMix(
              mixIndex,
              mix.copyWith(finalVolume: double.tryParse(v) ?? 0),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<VolumeUnit>(
            initialValue: mix.finalVolumeUnit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: VolumeUnit.values
                .map(
                  (u) => DropdownMenuItem(
                    value: u,
                    child: Text(
                      u.name,
                      style: const TextStyle(fontSize: _uniformFontSize),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) =>
                _updateMix(mixIndex, mix.copyWith(finalVolumeUnit: v!)),
          ),
        ),
      ],
    );
  }

  Widget _buildMixResultPreview(
    int mixIndex,
    MasterMixItem mix,
    MasterMixResult result,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _resItem(
                  'Solvent',
                  result.formattedBaseSolventVolume,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              _resItemEditable(
                'V2 (Total Mix)',
                result.optimizedFinalVolumeUl,
                (val) {
                  final roundedV2 =
                      (val / _extraFactor(mix) * 1000).round() / 1000.0;
                  _updateMix(
                    mixIndex,
                    mix.copyWith(
                      finalVolume: roundedV2,
                      finalVolumeUnit: VolumeUnit.uL,
                    ),
                  );
                },
                Colors.black,
              ),
            ],
          ),
          if (result.autoExtraVolumeReason != null) ...[
            const SizedBox(height: 10),
            Text(
              result.autoExtraVolumeReason!,
              style: TextStyle(
                fontSize: _uniformFontSize - 2,
                color: AppColors.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddReagentButton(int mixIndex) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => _addReagent(mixIndex),
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Reagent',
          style: TextStyle(fontSize: _uniformFontSize),
        ),
      ),
    );
  }

  Widget _buildReagentEditor(
    int mixIndex,
    int reagentIndex,
    MasterMixReagentItem item,
    MasterMixResult result,
  ) {
    MasterMixReagentResult? reagentResult;
    if (result.success && reagentIndex < result.reagentResults.length) {
      reagentResult = result.reagentResults[reagentIndex];
    }

    return Column(
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: _DelayedTextField(
                initialValue: item.name,
                decoration: const InputDecoration(labelText: 'Reagent Name'),
                style: const TextStyle(
                  fontSize: _uniformFontSize,
                  fontWeight: FontWeight.bold,
                ),
                onCommit: (v) => _updateReagent(
                  mixIndex,
                  reagentIndex,
                  item.copyWith(name: v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<ReagentSourceType>(
              segments: const [
                ButtonSegment(
                  value: ReagentSourceType.liquidStock,
                  label: Text('Liquid'),
                ),
                ButtonSegment(
                  value: ReagentSourceType.solidMaterial,
                  label: Text('Solid'),
                ),
              ],
              selected: {item.sourceType},
              onSelectionChanged: (selection) {
                final sourceType = selection.first;
                _updateReagent(
                  mixIndex,
                  reagentIndex,
                  item.copyWith(
                    sourceType: sourceType,
                    finalUnit: _coerceUnitForSource(item.finalUnit, sourceType),
                  ),
                );
              },
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            IconButton(
              tooltip: 'Remove reagent',
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _removeReagent(mixIndex, reagentIndex),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (item.sourceType == ReagentSourceType.liquidStock) ...[
          _buildConcRow(
            'C1 (Stock Conc.)',
            item.stockConc,
            item.stockUnit,
            _masterMixConcentrationUnits,
            (v) => _updateReagent(
              mixIndex,
              reagentIndex,
              item.copyWith(stockConc: v),
            ),
            (u) => _updateReagent(
              mixIndex,
              reagentIndex,
              item.copyWith(stockUnit: u),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildConcRow(
          item.sourceType == ReagentSourceType.solidMaterial
              ? 'Final Concentration'
              : 'C2 (Final Conc.)',
          item.finalConc,
          item.finalUnit,
          item.sourceType == ReagentSourceType.solidMaterial
              ? _solidConcentrationUnits
              : _masterMixConcentrationUnits,
          (v) => _updateReagent(
            mixIndex,
            reagentIndex,
            item.copyWith(finalConc: v),
          ),
          (u) => _updateReagent(
            mixIndex,
            reagentIndex,
            item.copyWith(finalUnit: u),
          ),
        ),
        if (_needsMolecularWeight(item)) ...[
          const SizedBox(height: 12),
          _DelayedTextField(
            initialValue: item.mw?.toString() ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Molecular weight (g/mol)',
            ),
            style: const TextStyle(fontSize: _uniformFontSize),
            onCommit: (v) => _updateReagent(
              mixIndex,
              reagentIndex,
              item.copyWith(mw: double.tryParse(v), clearMw: v.trim().isEmpty),
            ),
          ),
        ],
        if (reagentResult != null) ...[
          const Divider(height: 24),
          _buildReagentResultPreview(
            mixIndex,
            reagentIndex,
            item,
            reagentResult,
          ),
        ],
      ],
    );
  }

  Widget _buildReagentResultPreview(
    int mixIndex,
    int reagentIndex,
    MasterMixReagentItem item,
    MasterMixReagentResult rRes,
  ) {
    final mix = _wizard.mixes[mixIndex];
    final isMass = rRes.reagentMassGrams != null;

    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        if (isMass)
          _resItemEditableMass('V1 (from Stock)', rRes.reagentMassGrams!, (
            val,
          ) {
            final isStockMW = item.stockUnit == ConcentrationUnit.gMol;
            final mw = isStockMW ? item.stockConc : item.finalConc;
            final targetConc = isStockMW ? item.finalConc : item.stockConc;
            final targetUnit = isStockMW ? item.finalUnit : item.stockUnit;

            var newV2L = 0.0;
            if (LabCalculation.familyOf(targetUnit) ==
                ConcentrationFamily.molar) {
              final m = LabCalculation.concentrationToBase(
                targetConc,
                targetUnit,
              );
              newV2L = val / (mw * m);
            } else if (LabCalculation.familyOf(targetUnit) ==
                ConcentrationFamily.massVolume) {
              final gPerL = LabCalculation.concentrationToBase(
                targetConc,
                targetUnit,
              );
              newV2L = val / gPerL;
            }

            if (newV2L > 0) {
              final newV2uL = newV2L * 1e6;
              final roundedV2 =
                  (newV2uL / _extraFactor(mix) * 1000).round() / 1000.0;
              _updateMix(
                mixIndex,
                mix.copyWith(
                  finalVolume: roundedV2,
                  finalVolumeUnit: VolumeUnit.uL,
                ),
              );
            }
          }, AppColors.primary)
        else
          _resItemEditable('V1 (from Stock)', rRes.reagentVolumeUl, (val) {
            final stockFamily = LabCalculation.familyOf(item.stockUnit);
            final finalFamily = LabCalculation.familyOf(item.finalUnit);
            var ratio = 0.0;
            if (stockFamily == finalFamily) {
              final stockBase = LabCalculation.concentrationToBase(
                item.stockConc,
                item.stockUnit,
              );
              final finalBase = LabCalculation.concentrationToBase(
                item.finalConc,
                item.finalUnit,
              );
              ratio = finalBase / stockBase;
            }
            if (ratio > 0) {
              final newV2 = val / ratio;
              final roundedV2 =
                  (newV2 / _extraFactor(mix) * 1000).round() / 1000.0;
              _updateMix(
                mixIndex,
                mix.copyWith(
                  finalVolume: roundedV2,
                  finalVolumeUnit: VolumeUnit.uL,
                ),
              );
            }
          }, AppColors.primary),
        _resItem('Stock C1', rRes.formattedStockConcentration, Colors.grey),
        _resItem('Final C2', rRes.formattedFinalConcentration, Colors.grey),
      ],
    );
  }

  double _extraFactor(MasterMixItem mix) {
    return (1 + mix.extraVolumePercent.clamp(0, 100) / 100).toDouble();
  }

  void _handleDone(BuildContext context) async {
    if (!widget.promptForSaveDetails) {
      widget.onUpdate(_wizard);
      if (context.mounted) {
        setState(() => _canActuallyPop = true);
        Navigator.pop(context, _wizard);
      }
      return;
    }
    final name = await _showSaveDialog(context, _wizard.tableName);
    if (name != null) {
      setState(() {
        _wizard = _wizard.copyWith(tableName: name);
      });
      widget.onUpdate(_wizard);
      if (context.mounted) {
        setState(() => _canActuallyPop = true);
        Navigator.pop(context, _wizard);
      }
    }
  }

  Future<String?> _showSaveDialog(
    BuildContext context,
    String suggestedName,
  ) async {
    var currentName = suggestedName;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Table'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Table Name',
            hintText: 'Enter table name...',
          ),
          controller: TextEditingController(text: suggestedName),
          onChanged: (v) => currentName = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, currentName),
            child: const Text(
              'SAVE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resItem(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: _uniformFontSize - 4,
            color: Colors.grey,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: _uniformFontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _resItemEditable(
    String label,
    double valUl,
    Function(double) onVal,
    Color color,
  ) {
    String displayVal;
    String unit;
    double factor;
    if (valUl >= 1000) {
      displayVal = (valUl / 1000).toStringAsFixed(3);
      unit = 'mL';
      factor = 1000;
    } else {
      displayVal = valUl.toStringAsFixed(3);
      unit = 'uL';
      factor = 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: _uniformFontSize - 4,
            color: Colors.grey,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 78,
              child: _DelayedTextField(
                initialValue: displayVal,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: _uniformFontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
                onCommit: (v) {
                  final d = double.tryParse(v) ?? 0;
                  onVal(d * factor);
                },
              ),
            ),
            Text(
              unit,
              style: TextStyle(fontSize: _uniformFontSize - 2, color: color),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resItemEditableMass(
    String label,
    double valGrams,
    Function(double) onVal,
    Color color,
  ) {
    String displayVal;
    String unit;
    double factor;
    if (valGrams >= 1) {
      displayVal = valGrams.toStringAsFixed(3);
      unit = 'g';
      factor = 1;
    } else if (valGrams >= 0.001) {
      displayVal = (valGrams * 1000).toStringAsFixed(3);
      unit = 'mg';
      factor = 0.001;
    } else {
      displayVal = (valGrams * 1000000).toStringAsFixed(3);
      unit = 'ug';
      factor = 0.000001;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: _uniformFontSize - 4,
            color: Colors.grey,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 78,
              child: _DelayedTextField(
                initialValue: displayVal,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: _uniformFontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
                onCommit: (v) {
                  final d = double.tryParse(v) ?? 0;
                  onVal(d * factor);
                },
              ),
            ),
            Text(
              unit,
              style: TextStyle(fontSize: _uniformFontSize - 2, color: color),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConcRow(
    String label,
    double value,
    ConcentrationUnit unit,
    List<ConcentrationUnit> units,
    Function(double) onVal,
    Function(ConcentrationUnit) onUnit,
  ) {
    return ConcentrationInputRow(
      label: label,
      value: value,
      unit: unit,
      units: units,
      onValueChanged: onVal,
      onUnitChanged: onUnit,
      fontSize: _uniformFontSize,
    );
  }

  ConcentrationUnit _coerceUnitForSource(
    ConcentrationUnit unit,
    ReagentSourceType sourceType,
  ) {
    final allowed = sourceType == ReagentSourceType.solidMaterial
        ? _solidConcentrationUnits
        : _masterMixConcentrationUnits;
    return allowed.contains(unit) ? unit : allowed.first;
  }

  MasterMixReagentItem _normalizeReagentForEditor(MasterMixReagentItem item) {
    if (item.stockUnit == ConcentrationUnit.gMol ||
        item.finalUnit == ConcentrationUnit.gMol) {
      final molecularWeight = item.stockUnit == ConcentrationUnit.gMol
          ? item.stockConc
          : item.finalConc;
      final concentration = item.stockUnit == ConcentrationUnit.gMol
          ? item.finalConc
          : item.stockConc;
      final unit = item.stockUnit == ConcentrationUnit.gMol
          ? item.finalUnit
          : item.stockUnit;
      final safeUnit = _coerceUnitForSource(
        unit,
        ReagentSourceType.solidMaterial,
      );
      return item.copyWith(
        sourceType: ReagentSourceType.solidMaterial,
        stockConc: concentration,
        stockUnit: safeUnit,
        finalConc: concentration,
        finalUnit: safeUnit,
        mw: molecularWeight,
      );
    }
    return item.copyWith(
      stockUnit: _coerceUnitForSource(
        item.stockUnit,
        ReagentSourceType.liquidStock,
      ),
      finalUnit: _coerceUnitForSource(item.finalUnit, item.sourceType),
    );
  }

  bool _needsMolecularWeight(MasterMixReagentItem item) {
    if (item.sourceType == ReagentSourceType.solidMaterial) {
      return LabCalculation.familyOf(item.finalUnit) ==
          ConcentrationFamily.molar;
    }
    final stockFamily = LabCalculation.familyOf(item.stockUnit);
    final finalFamily = LabCalculation.familyOf(item.finalUnit);
    return (stockFamily == ConcentrationFamily.molar &&
            finalFamily == ConcentrationFamily.massVolume) ||
        (stockFamily == ConcentrationFamily.massVolume &&
            finalFamily == ConcentrationFamily.molar);
  }
}

class _DelayedTextField extends StatefulWidget {
  final String initialValue;
  final Function(String) onCommit;
  final InputDecoration decoration;
  final TextInputType keyboardType;
  final TextStyle? style;

  const _DelayedTextField({
    required this.initialValue,
    required this.onCommit,
    this.decoration = const InputDecoration(),
    this.keyboardType = TextInputType.text,
    this.style,
  });

  @override
  State<_DelayedTextField> createState() => _DelayedTextFieldState();
}

class _DelayedTextFieldState extends State<_DelayedTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      widget.onCommit(_controller.text);
    }
  }

  @override
  void didUpdateWidget(_DelayedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      style: widget.style,
      onSubmitted: (v) => widget.onCommit(v),
    );
  }
}
