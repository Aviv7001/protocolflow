import 'package:flutter/material.dart';
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
          title: const Text('Reagent Manager'),
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
          'Generated Reagent Table Preview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ReagentResultTable(wizard: _wizard),
      ],
    );
  }

  Widget _buildReagentEditor(int index, ReagentItem item) {
    final calc = ReagentMixCalculatorService();
    final result = calc.calculateMix(
      ReagentMixInput(
        reagentName: item.name,
        stockConcentration: item.stockConc,
        stockUnit: item.stockUnit,
        workingConcentration: item.workingConc,
        workingUnit: item.workingUnit,
        volumePerTube: item.volPerSample,
        volumePerTubeUnit: item.volUnit,
        numberOfTubes: item.numSamples,
        molecularWeight: item.molecularWeight,
      ),
    );

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
            _buildConcRow(
              'C1 (Stock Conc.)',
              item.stockConc,
              item.stockUnit,
              (val) => _updateReagent(index, item.copyWith(stockConc: val)),
              (unit) => _updateReagent(index, item.copyWith(stockUnit: unit)),
            ),
            const SizedBox(height: 8),
            _buildConcRow(
              'C2 (Final Conc.)',
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
                    decoration: const InputDecoration(
                      labelText: 'Vol. / Tube',
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
                    decoration: const InputDecoration(
                      labelText: '# Tubes',
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
          flex: 2,
          child: DropdownButtonFormField<ConcentrationUnit>(
            initialValue: unit,
            decoration: const InputDecoration(labelText: 'Unit', isDense: true),
            items: ConcentrationUnit.values
                .map(
                  (u) => DropdownMenuItem(
                    value: u,
                    child: Text(
                      _unitLabel(u),
                      style: const TextStyle(fontSize: _uniformFontSize),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => onUnit(v!),
          ),
        ),
      ],
    );
  }

  String _unitLabel(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return 'M';
      case ConcentrationUnit.mM:
        return 'mM';
      case ConcentrationUnit.uM:
        return 'µM';
      case ConcentrationUnit.nM:
        return 'nM';
      case ConcentrationUnit.gL:
        return 'g/L';
      case ConcentrationUnit.mgML:
        return 'mg/mL';
      case ConcentrationUnit.ugML:
        return 'µg/mL';
      case ConcentrationUnit.percent:
        return '%';
      case ConcentrationUnit.ratio:
        return 'ratio';
      case ConcentrationUnit.gMol:
        return 'g/mol';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isMass)
              _resItemEditableMass('V1 (Stock)', result.reagentMassGrams!, (
                val,
              ) {
                // val is in grams. We don't adjust C1 (MW) or C2.
                // If mass is adjusted, we adjust the total volume V2 to keep the same C2.
                final bool isStockMW = item.stockUnit == ConcentrationUnit.gMol;
                final double mw = isStockMW ? item.stockConc : item.workingConc;
                final double targetConc = isStockMW
                    ? item.workingConc
                    : item.stockConc;
                final ConcentrationUnit targetUnit = isStockMW
                    ? item.workingUnit
                    : item.stockUnit;

                double newV2L = 0;
                if (targetUnit.index < 4) {
                  // Molar
                  final double m =
                      targetConc * [1, 1e-3, 1e-6, 1e-9][targetUnit.index];
                  newV2L = val / (mw * m);
                } else if (targetUnit == ConcentrationUnit.gL ||
                    targetUnit == ConcentrationUnit.mgML) {
                  newV2L = val / targetConc;
                } else if (targetUnit == ConcentrationUnit.ugML) {
                  newV2L = val / (targetConc * 1e-3);
                }

                if (newV2L > 0) {
                  final newV2uL = newV2L * 1e6;
                  // Round to 1 decimal place to avoid floating point issues
                  final newVolPerTube =
                      (newV2uL / item.numSamples * 10).round() / 10.0;
                  _updateReagent(
                    index,
                    item.copyWith(volPerSample: newVolPerTube),
                  );
                }
              }, Colors.blue)
            else
              _resItemEditable('V1 (Stock)', result.reagentVolumeUl, (val) {
                if (result.reagentVolumeUl > 0) {
                  final ratio = result.totalVolumeUl / result.reagentVolumeUl;
                  final newV2 = val * ratio;
                  // Round to 1 decimal place to keep it clean
                  final newVolPerTube =
                      (newV2 / (item.numSamples * 1.1) * 10).round() / 10.0;
                  _updateReagent(
                    index,
                    item.copyWith(volPerSample: newVolPerTube),
                  );
                }
              }, Colors.blue),
            _resItem('Solvent', result.formattedSolventVolume, Colors.green),
            _resItemEditable('V2 (Total)', result.totalVolumeUl, (val) {
              final newVolPerTube = val / (item.numSamples * 1.1);
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
