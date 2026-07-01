import 'package:flutter/material.dart';
import '../features/lab_math/lab_calculation.dart';
import '../models/reagent_mix_wizard.dart';
import '../features/reagent_mix/services/reagent_mix_calculator_service.dart';
import '../features/reagent_mix/widgets/reagent_result_table.dart';
import '../widgets/unsaved_changes_pop_scope.dart';

class ReagentManagerScreen extends StatefulWidget {
  final ReagentMixWizard wizard;
  final Function(ReagentMixWizard) onUpdate;

  const ReagentManagerScreen({
    super.key,
    required this.wizard,
    required this.onUpdate,
  });

  @override
  State<ReagentManagerScreen> createState() => _ReagentManagerScreenState();
}

class _ReagentManagerScreenState extends State<ReagentManagerScreen> {
  late ReagentMixWizard _wizard;
  static const double _uniformFontSize = 14.0;
  bool _canActuallyPop = false;

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
  }

  void _addReagent() {
    setState(() {
      ConcentrationUnit lastStockUnit = ConcentrationUnit.ugML;
      ConcentrationUnit lastWorkingUnit = ConcentrationUnit.ugML;
      VolumeUnit lastVolUnit = VolumeUnit.uL;

      if (_wizard.reagents.isNotEmpty) {
        final last = _wizard.reagents.last;
        lastStockUnit = last.stockUnit;
        lastWorkingUnit = last.workingUnit;
        lastVolUnit = last.volUnit;
      }

      _wizard = _wizard.copyWith(
        reagents: [
          ..._wizard.reagents,
          ReagentItem(
            name: 'Reagent ${_wizard.reagents.length + 1}',
            stockUnit: lastStockUnit,
            workingUnit: lastWorkingUnit,
            volUnit: lastVolUnit,
          ),
        ],
      );
    });
  }

  void _removeReagent(int index) {
    setState(() {
      final newReagents = List<ReagentItem>.from(_wizard.reagents)
        ..removeAt(index);
      _wizard = _wizard.copyWith(reagents: newReagents);
    });
  }

  void _updateReagent(int index, ReagentItem newItem) {
    setState(() {
      final newReagents = List<ReagentItem>.from(_wizard.reagents);
      newReagents[index] = newItem;
      _wizard = _wizard.copyWith(reagents: newReagents);
    });
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesPopScope(
      canPop: _canActuallyPop,
      message:
          'You have unsaved changes in this table. Are you sure you want to exit?',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('C1V1 = C2V2 Dilution'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _handleDone(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGeneralInfo(),
              const SizedBox(height: 24),
              Text('Reagents', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ..._wizard.reagents.asMap().entries.map(
                (entry) => _buildReagentEditor(entry.key, entry.value),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _addReagent,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Add Reagent',
                      style: TextStyle(fontSize: _uniformFontSize),
                    ),
                  ),
                ),
              ),
              _buildGlobalPreviewTable(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDone(BuildContext context) async {
    final String? name = await _showSaveDialog(context, _wizard.title);
    if (name != null) {
      setState(() {
        _wizard = _wizard.copyWith(title: name);
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
    String currentName = suggestedName;
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

  Widget _buildGlobalPreviewTable() {
    if (_wizard.reagents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        Text(
          'Generated Dilution Table Preview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ReagentResultTable(wizard: _wizard),
      ],
    );
  }

  Widget _buildReagentEditor(int index, ReagentItem item) {
    final calc = ReagentMixCalculatorService();
    final input = ReagentMixInput(
      reagentName: item.name,
      stockConcentration: item.stockConc,
      stockUnit: item.stockUnit,
      workingConcentration: item.workingConc,
      workingUnit: item.workingUnit,
      volumePerTube: item.volPerSample,
      volumePerTubeUnit: item.volUnit,
      numberOfTubes: item.numSamples,
      extraVolumePercent: _wizard.extraVolumePercent,
      molecularWeight: item.molecularWeight,
    );
    final isSuspension =
        item.preparationType == ReagentPreparationType.solidSuspension;
    final result = isSuspension
        ? calc.calculateSuspension(input)
        : calc.calculateMix(input);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _DelayedTextField(
                    decoration: const InputDecoration(
                      labelText: 'Reagent Name',
                    ),
                    initialValue: item.name,
                    style: const TextStyle(
                      fontSize: _uniformFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    onCommit: (v) =>
                        _updateReagent(index, item.copyWith(name: v)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeReagent(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReagentPreparationType>(
              initialValue: item.preparationType,
              decoration: const InputDecoration(
                labelText: 'Preparation Type',
                isDense: true,
              ),
              items: ReagentPreparationType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (type) {
                if (type == null) return;
                _updateReagent(index, item.copyWith(preparationType: type));
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DelayedTextField(
                    decoration: const InputDecoration(labelText: 'Solvent'),
                    initialValue: item.solvent,
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) =>
                        _updateReagent(index, item.copyWith(solvent: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isSuspension) ...[
              _buildConcRow(
                'C1 (Stock Conc.)',
                item.stockConc,
                item.stockUnit,
                (val) => _updateReagent(index, item.copyWith(stockConc: val)),
                (unit) => _updateReagent(index, item.copyWith(stockUnit: unit)),
              ),
              const SizedBox(height: 8),
            ],
            _buildConcRow(
              isSuspension ? 'Target Conc.' : 'C2 (Final Conc.)',
              item.workingConc,
              item.workingUnit,
              (val) => _updateReagent(index, item.copyWith(workingConc: val)),
              (unit) => _updateReagent(index, item.copyWith(workingUnit: unit)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _DelayedTextField(
                    decoration: InputDecoration(
                      labelText: isSuspension ? 'Final Volume' : 'Vol. / Tube',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    initialValue: item.volPerSample.toString(),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => _updateReagent(
                      index,
                      item.copyWith(volPerSample: double.tryParse(v) ?? 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<VolumeUnit>(
                    initialValue: item.volUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      isDense: true,
                    ),
                    items: VolumeUnit.values
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(
                              u.name,
                              style: const TextStyle(
                                fontSize: _uniformFontSize,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        _updateReagent(index, item.copyWith(volUnit: v!)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _DelayedTextField(
                    decoration: InputDecoration(
                      labelText: isSuspension ? '# Preps' : '# Tubes',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: item.numSamples.toString(),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => _updateReagent(
                      index,
                      item.copyWith(numSamples: int.tryParse(v) ?? 1),
                    ),
                  ),
                ),
              ],
            ),
            if (result.success ||
                result.warnings.isNotEmpty ||
                result.errorMessage != null) ...[
              const Divider(height: 24),
              _buildResultPreview(index, item, result),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _DelayedTextField(
              decoration: const InputDecoration(
                labelText: 'Table Title',
                border: OutlineInputBorder(),
              ),
              initialValue: _wizard.title,
              style: const TextStyle(fontSize: _uniformFontSize),
              onCommit: (v) =>
                  setState(() => _wizard = _wizard.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            _DelayedTextField(
              decoration: const InputDecoration(
                labelText: 'Extra Volume %',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              initialValue: _wizard.extraVolumePercent.toString(),
              style: const TextStyle(fontSize: _uniformFontSize),
              onCommit: (v) => setState(
                () => _wizard = _wizard.copyWith(
                  extraVolumePercent: double.tryParse(v) ?? 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _parseConcentration(String v) {
    if (v.contains(':')) {
      final parts = v.split(':');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]) ?? 1.0;
        final den = double.tryParse(parts[1]) ?? 1.0;
        return den / num; // We return the denominator for ratios > 1
      }
    } else if (v.contains('/')) {
      final parts = v.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]) ?? 1.0;
        final den = double.tryParse(parts[1]) ?? 1.0;
        if (num == 1.0) return den;
        return num / den;
      }
    }
    return double.tryParse(v) ?? 0;
  }

  Widget _buildConcRow(
    String label,
    double value,
    ConcentrationUnit unit,
    Function(double) onVal,
    Function(ConcentrationUnit) onUnit,
  ) {
    String displayValue = value.toString();
    if (unit == ConcentrationUnit.ratio && value >= 1) {
      displayValue = '1:${value == value.toInt() ? value.toInt() : value}';
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _DelayedTextField(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              hintText: unit == ConcentrationUnit.ratio
                  ? 'e.g. 1:400 or 1/400'
                  : '',
            ),
            keyboardType: unit == ConcentrationUnit.ratio
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
            initialValue: displayValue,
            style: const TextStyle(fontSize: _uniformFontSize),
            onCommit: (v) => onVal(_parseConcentration(v)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _ConcentrationUnitPicker(unit: unit, onChanged: onUnit),
        ),
      ],
    );
  }

  String unitLabel(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return 'M';
      case ConcentrationUnit.mM:
        return 'mM';
      case ConcentrationUnit.uM:
        return 'µM';
      case ConcentrationUnit.nM:
        return 'nM';
      case ConcentrationUnit.pM:
        return 'pM';
      case ConcentrationUnit.gL:
        return 'g/L';
      case ConcentrationUnit.mgML:
        return 'mg/mL';
      case ConcentrationUnit.ugML:
        return 'µg/mL';
      case ConcentrationUnit.percent:
        return '%';
      case ConcentrationUnit.ngML:
        return 'ng/mL';
      case ConcentrationUnit.ratio:
        return 'ratio';
      case ConcentrationUnit.X:
        return 'X';
      case ConcentrationUnit.gMol:
        return 'g/mol';
      case ConcentrationUnit.gUL:
        return 'g/uL';
      case ConcentrationUnit.mgUL:
        return 'mg/uL';
      case ConcentrationUnit.ugUL:
        return 'ug/uL';
      case ConcentrationUnit.ngUL:
        return 'ng/uL';
    }
  }

  Widget _buildResultPreview(
    int index,
    ReagentItem item,
    ReagentMixResult result,
  ) {
    if (!result.success) {
      return Text(
        result.errorMessage ?? 'Error in calculation',
        style: const TextStyle(
          color: Colors.red,
          fontSize: _uniformFontSize,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final bool isMass = result.reagentMassGrams != null;
    final bool isSuspension =
        item.preparationType == ReagentPreparationType.solidSuspension;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isMass)
              _resItemEditableMass(
                isSuspension ? 'Solid' : 'V1 (Stock)',
                result.reagentMassGrams!,
                (val) {
                  final targetConc = isSuspension
                      ? item.workingConc
                      : item.stockUnit == ConcentrationUnit.gMol
                      ? item.workingConc
                      : item.stockConc;
                  final targetUnit = isSuspension
                      ? item.workingUnit
                      : item.stockUnit == ConcentrationUnit.gMol
                      ? item.workingUnit
                      : item.stockUnit;
                  final mw = item.stockUnit == ConcentrationUnit.gMol
                      ? item.stockConc
                      : item.workingConc;

                  double newV2L = 0;
                  if (LabCalculation.familyOf(targetUnit) ==
                      ConcentrationFamily.molar) {
                    final double m = LabCalculation.concentrationToBase(
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
                  } else if (LabCalculation.familyOf(targetUnit) ==
                      ConcentrationFamily.percentage) {
                    newV2L = val / (targetConc * 10);
                  }

                  if (newV2L > 0) {
                    final newV2uL = newV2L * 1e6;
                    final divisor = isSuspension
                        ? item.numSamples
                        : item.numSamples * _extraFactor;
                    final newVolPerTube =
                        (newV2uL / divisor * 10).round() / 10.0;
                    _updateReagent(
                      index,
                      item.copyWith(volPerSample: newVolPerTube),
                    );
                  }
                },
                Colors.blue,
              )
            else
              _resItemEditable('V1 (Stock)', result.reagentVolumeUl, (val) {
                if (result.reagentVolumeUl > 0) {
                  final ratio = result.totalVolumeUl / result.reagentVolumeUl;
                  final newV2 = val * ratio;
                  // Round to 1 decimal place to keep it clean
                  final newVolPerTube =
                      (newV2 / (item.numSamples * _extraFactor) * 10).round() /
                      10.0;
                  _updateReagent(
                    index,
                    item.copyWith(volPerSample: newVolPerTube),
                  );
                }
              }, Colors.blue),
            _resItem(
              isSuspension ? 'Solvent' : 'Solvent',
              result.formattedSolventVolume,
              Colors.green,
            ),
            _resItemEditable('V2 (Total)', result.totalVolumeUl, (val) {
              final divisor = isSuspension
                  ? item.numSamples
                  : item.numSamples * _extraFactor;
              final newVolPerTube = val / divisor;
              _updateReagent(index, item.copyWith(volPerSample: newVolPerTube));
            }, Colors.black),
          ],
        ),
        if (result.warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: result.warnings
                  .map(
                    (w) => Text(
                      '• $w',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: _uniformFontSize - 2,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (result.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.35)),
              ),
              child: Text(
                result.suggestions.first.message,
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontSize: _uniformFontSize - 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
      displayVal = valGrams.toStringAsFixed(2);
      unit = 'g';
      factor = 1;
    } else if (valGrams >= 0.001) {
      displayVal = (valGrams * 1000).toStringAsFixed(2);
      unit = 'mg';
      factor = 0.001;
    } else {
      displayVal = (valGrams * 1000000).toStringAsFixed(1);
      unit = 'µg';
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
              width: 70,
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
    // Convert uL to mL if needed for display/edit
    String displayVal;
    String unit;
    double factor;
    if (valUl >= 1000) {
      displayVal = (valUl / 1000).toStringAsFixed(2);
      unit = 'mL';
      factor = 1000;
    } else {
      displayVal = valUl.toStringAsFixed(1);
      unit = 'µL';
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
              width: 70,
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

  double get _extraFactor {
    return 1 + _wizard.extraVolumePercent.clamp(0, 100) / 100;
  }
}

class _ConcentrationUnitPicker extends StatelessWidget {
  final ConcentrationUnit unit;
  final ValueChanged<ConcentrationUnit> onChanged;

  const _ConcentrationUnitPicker({required this.unit, required this.onChanged});

  static const List<String> _amounts = [
    'M',
    'mM',
    'uM',
    'nM',
    'pM',
    'g',
    'mg',
    'ug',
    'ng',
    '%',
    'X',
    'ratio',
  ];

  @override
  Widget build(BuildContext context) {
    final parts = _UnitParts.fromUnit(unit);
    final denominators = _denominatorsFor(parts.amount);
    final selectedDenominator = denominators.contains(parts.denominator)
        ? parts.denominator
        : denominators.first;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: parts.amount,
            decoration: const InputDecoration(labelText: 'Unit', isDense: true),
            items: _amounts
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final nextDenominator = _denominatorsFor(value).first;
              onChanged(_UnitParts(value, nextDenominator).toUnit());
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedDenominator,
            decoration: const InputDecoration(labelText: 'Per', isDense: true),
            items: denominators
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: denominators.length == 1
                ? null
                : (value) {
                    if (value == null) return;
                    onChanged(_UnitParts(parts.amount, value).toUnit());
                  },
          ),
        ),
      ],
    );
  }

  static List<String> _denominatorsFor(String amount) {
    switch (amount) {
      case 'g':
        return const ['L', 'uL', 'mol'];
      case 'mg':
      case 'ug':
      case 'ng':
        return const ['mL', 'uL'];
      default:
        return const ['-'];
    }
  }
}

class _UnitParts {
  final String amount;
  final String denominator;

  const _UnitParts(this.amount, this.denominator);

  factory _UnitParts.fromUnit(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return const _UnitParts('M', '-');
      case ConcentrationUnit.mM:
        return const _UnitParts('mM', '-');
      case ConcentrationUnit.uM:
        return const _UnitParts('uM', '-');
      case ConcentrationUnit.nM:
        return const _UnitParts('nM', '-');
      case ConcentrationUnit.pM:
        return const _UnitParts('pM', '-');
      case ConcentrationUnit.gL:
        return const _UnitParts('g', 'L');
      case ConcentrationUnit.gUL:
        return const _UnitParts('g', 'uL');
      case ConcentrationUnit.mgML:
        return const _UnitParts('mg', 'mL');
      case ConcentrationUnit.mgUL:
        return const _UnitParts('mg', 'uL');
      case ConcentrationUnit.ugML:
        return const _UnitParts('ug', 'mL');
      case ConcentrationUnit.ugUL:
        return const _UnitParts('ug', 'uL');
      case ConcentrationUnit.ngML:
        return const _UnitParts('ng', 'mL');
      case ConcentrationUnit.ngUL:
        return const _UnitParts('ng', 'uL');
      case ConcentrationUnit.percent:
        return const _UnitParts('%', '-');
      case ConcentrationUnit.X:
        return const _UnitParts('X', '-');
      case ConcentrationUnit.ratio:
        return const _UnitParts('ratio', '-');
      case ConcentrationUnit.gMol:
        return const _UnitParts('g', 'mol');
    }
  }

  ConcentrationUnit toUnit() {
    if (amount == 'M') return ConcentrationUnit.M;
    if (amount == 'mM') return ConcentrationUnit.mM;
    if (amount == 'uM') return ConcentrationUnit.uM;
    if (amount == 'nM') return ConcentrationUnit.nM;
    if (amount == 'pM') return ConcentrationUnit.pM;
    if (amount == 'g' && denominator == 'L') return ConcentrationUnit.gL;
    if (amount == 'g' && denominator == 'uL') return ConcentrationUnit.gUL;
    if (amount == 'mg' && denominator == 'mL') return ConcentrationUnit.mgML;
    if (amount == 'mg' && denominator == 'uL') return ConcentrationUnit.mgUL;
    if (amount == 'ug' && denominator == 'mL') return ConcentrationUnit.ugML;
    if (amount == 'ug' && denominator == 'uL') return ConcentrationUnit.ugUL;
    if (amount == 'ng' && denominator == 'mL') return ConcentrationUnit.ngML;
    if (amount == 'ng' && denominator == 'uL') return ConcentrationUnit.ngUL;
    if (amount == 'g' && denominator == 'mol') return ConcentrationUnit.gMol;
    if (amount == '%') return ConcentrationUnit.percent;
    if (amount == 'X') return ConcentrationUnit.X;
    if (amount == 'ratio') return ConcentrationUnit.ratio;
    return ConcentrationUnit.ugML;
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
