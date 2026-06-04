import 'package:flutter/material.dart';
import '../services/master_mix_calculator_service.dart';
import '../../../models/master_mix_wizard.dart';
import '../widgets/master_mix_result_table.dart';
import '../../../widgets/unsaved_changes_pop_scope.dart';

class MasterMixManagerScreen extends StatefulWidget {
  final MasterMixWizard wizard;
  final Function(MasterMixWizard) onUpdate;

  const MasterMixManagerScreen({
    super.key,
    required this.wizard,
    required this.onUpdate,
  });

  @override
  State<MasterMixManagerScreen> createState() => _MasterMixManagerScreenState();
}

class _MasterMixManagerScreenState extends State<MasterMixManagerScreen> {
  late MasterMixWizard _wizard;
  final MasterMixCalculatorService _calculator = MasterMixCalculatorService();
  static const double _uniformFontSize = 14.0;
  bool _canActuallyPop = false;

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
  }

  void _addReagent() {
    setState(() {
      ConcentrationUnit lastStockUnit = ConcentrationUnit.mM;
      ConcentrationUnit lastFinalUnit = ConcentrationUnit.uM;

      if (_wizard.reagents.isNotEmpty) {
        final last = _wizard.reagents.last;
        lastStockUnit = last.stockUnit;
        lastFinalUnit = last.finalUnit;
      }

      _wizard = _wizard.copyWith(
        reagents: [
          ..._wizard.reagents,
          MasterMixReagentItem(
            name: 'Reagent ${_wizard.reagents.length + 1}',
            stockUnit: lastStockUnit,
            finalUnit: lastFinalUnit,
          ),
        ],
      );
    });
  }

  void _removeReagent(int index) {
    setState(() {
      final newReagents = List<MasterMixReagentItem>.from(_wizard.reagents)
        ..removeAt(index);
      _wizard = _wizard.copyWith(reagents: newReagents);
    });
  }

  void _updateReagent(int index, MasterMixReagentItem newItem) {
    setState(() {
      final newReagents = List<MasterMixReagentItem>.from(_wizard.reagents);
      newReagents[index] = newItem;
      _wizard = _wizard.copyWith(reagents: newReagents);
    });
  }

  @override
  Widget build(BuildContext context) {
    final res = _calculator.calculateMasterMix(
      MasterMixInput(
        mixName: _wizard.mixName,
        finalVolume: _wizard.finalVolume,
        finalVolumeUnit: _wizard.finalVolumeUnit,
        baseSolventName: _wizard.baseSolventName,
        reagents: _wizard.reagents.map((r) => r.toInput()).toList(),
      ),
    );

    return UnsavedChangesPopScope(
      canPop: _canActuallyPop,
      message:
          'You have unsaved changes in this table. Are you sure you want to exit?',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Master Mix Manager'),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGeneralInfo(),
              const SizedBox(height: 24),
              Text('Reagents', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._wizard.reagents.asMap().entries.map(
                (e) => _buildReagentEditor(e.key, e.value, res),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
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
              const SizedBox(height: 32),
              _buildGlobalResultPreview(res),
              const SizedBox(height: 12),
              MasterMixResultTable(wizard: _wizard, calculator: _calculator),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalResultPreview(MasterMixResult res) {
    if (!res.success) return const SizedBox.shrink();

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _resItem('Solvent', res.formattedBaseSolventVolume, Colors.green),
            _resItemEditable('V2 (Total Mix)', res.optimizedFinalVolumeUl, (
              val,
            ) {
              final roundedV2 = (val * 10).round() / 10.0;
              setState(
                () => _wizard = _wizard.copyWith(
                  finalVolume: roundedV2,
                  finalVolumeUnit: VolumeUnit.uL,
                ),
              );
            }, Colors.black),
          ],
        ),
      ),
    );
  }

  void _handleDone(BuildContext context) async {
    final String? name = await _showSaveDialog(context, 'Master Mix Table');
    if (name != null) {
      setState(() {
        _wizard = _wizard.copyWith(mixName: name);
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
                labelText: 'Mix Name / Table Title',
                border: OutlineInputBorder(),
              ),
              initialValue: _wizard.mixName,
              style: const TextStyle(fontSize: _uniformFontSize),
              onCommit: (v) =>
                  setState(() => _wizard = _wizard.copyWith(mixName: v)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _DelayedTextField(
                    initialValue: _wizard.finalVolume.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Final Volume',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _wizard = _wizard.copyWith(
                        finalVolume: double.tryParse(v) ?? 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<VolumeUnit>(
                    initialValue: _wizard.finalVolumeUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
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
                    onChanged: (v) => setState(
                      () => _wizard = _wizard.copyWith(finalVolumeUnit: v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DelayedTextField(
              initialValue: _wizard.baseSolventName,
              decoration: const InputDecoration(
                labelText: 'Base Solvent Name',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: _uniformFontSize),
              onCommit: (v) => setState(
                () => _wizard = _wizard.copyWith(baseSolventName: v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReagentEditor(
    int index,
    MasterMixReagentItem item,
    MasterMixResult res,
  ) {
    MasterMixReagentResult? reagentRes;
    if (res.success && index < res.reagentResults.length) {
      reagentRes = res.reagentResults[index];
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _DelayedTextField(
                    initialValue: item.name,
                    decoration: const InputDecoration(
                      labelText: 'Reagent Name',
                      border: UnderlineInputBorder(),
                    ),
                    style: const TextStyle(
                      fontSize: _uniformFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    onCommit: (v) =>
                        _updateReagent(index, item.copyWith(name: v)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeReagent(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildConcRow(
              'C1 (Stock Concentration)',
              item.stockConc,
              item.stockUnit,
              (v) => _updateReagent(index, item.copyWith(stockConc: v)),
              (u) => _updateReagent(index, item.copyWith(stockUnit: u)),
            ),
            const SizedBox(height: 12),
            _buildConcRow(
              'C2 (Final Concentration)',
              item.finalConc,
              item.finalUnit,
              (v) => _updateReagent(index, item.copyWith(finalConc: v)),
              (u) => _updateReagent(index, item.copyWith(finalUnit: u)),
            ),

            if (reagentRes != null) ...[
              const Divider(height: 24),
              _buildReagentResultPreview(index, item, reagentRes, res),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReagentResultPreview(
    int index,
    MasterMixReagentItem item,
    MasterMixReagentResult rRes,
    MasterMixResult globalRes,
  ) {
    final bool isMass = rRes.reagentMassGrams != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (isMass)
          _resItemEditableMass('V1 (from Stock)', rRes.reagentMassGrams!, (
            val,
          ) {
            // Adjust Global V2 based on this mass and C1/C2
            final bool isStockMW = item.stockUnit == ConcentrationUnit.gMol;
            final double mw = isStockMW ? item.stockConc : item.finalConc;
            final double targetConc = isStockMW
                ? item.finalConc
                : item.stockConc;
            final ConcentrationUnit targetUnit = isStockMW
                ? item.finalUnit
                : item.stockUnit;

            double newV2L = 0;
            if (targetUnit.index < 5) {
              // Molar
              final double m =
                  targetConc * [1, 1e-3, 1e-6, 1e-9, 1e-12][targetUnit.index];
              newV2L = val / (mw * m);
            } else if (targetUnit == ConcentrationUnit.gL ||
                targetUnit == ConcentrationUnit.mgML) {
              newV2L = val / targetConc;
            } else if (targetUnit == ConcentrationUnit.ugML) {
              newV2L = val / (targetConc * 1e-3);
            } else if (targetUnit == ConcentrationUnit.ngML) {
              newV2L = val / (targetConc * 1e-6);
            }

            if (newV2L > 0) {
              final newV2uL = newV2L * 1e6;
              // Round to 1 decimal place to keep it clean
              final roundedV2 = (newV2uL * 10).round() / 10.0;
              setState(
                () => _wizard = _wizard.copyWith(
                  finalVolume: roundedV2,
                  finalVolumeUnit: VolumeUnit.uL,
                ),
              );
            }
          }, Colors.blue)
        else
          _resItemEditable('V1 (from Stock)', rRes.reagentVolumeUl, (val) {
            // Calculate required Global V2 to get this V1 for this reagent
            final stockFamily = _getFamily(item.stockUnit);
            final finalFamily = _getFamily(item.finalUnit);
            double ratio = 0;
            if (stockFamily == finalFamily) {
              final stockBase = _convertToBaseConc(
                item.stockConc,
                item.stockUnit,
              );
              final finalBase = _convertToBaseConc(
                item.finalConc,
                item.finalUnit,
              );
              ratio = finalBase / stockBase;
            }
            if (ratio > 0) {
              final newV2 = val / ratio;
              // Round to 1 decimal place to keep it clean
              final roundedV2 = (newV2 * 10).round() / 10.0;
              setState(
                () => _wizard = _wizard.copyWith(
                  finalVolume: roundedV2,
                  finalVolumeUnit: VolumeUnit.uL,
                ),
              );
            }
          }, Colors.blue),
        _resItem('Stock C1', rRes.formattedStockConcentration, Colors.grey),
        _resItem('Final C2', rRes.formattedFinalConcentration, Colors.grey),
      ],
    );
  }

  ConcentrationFamily _getFamily(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
      case ConcentrationUnit.mM:
      case ConcentrationUnit.uM:
      case ConcentrationUnit.nM:
      case ConcentrationUnit.pM:
        return ConcentrationFamily.molar;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML:
      case ConcentrationUnit.ugML:
      case ConcentrationUnit.ngML:
        return ConcentrationFamily.massVolume;
      case ConcentrationUnit.percent:
        return ConcentrationFamily.percentage;
      case ConcentrationUnit.X:
        return ConcentrationFamily.fold;
      case ConcentrationUnit.gMol:
        return ConcentrationFamily.molecularWeight;
    }
  }

  double _convertToBaseConc(double val, ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return val;
      case ConcentrationUnit.mM:
        return val * 1e-3;
      case ConcentrationUnit.uM:
        return val * 1e-6;
      case ConcentrationUnit.nM:
        return val * 1e-9;
      case ConcentrationUnit.pM:
        return val * 1e-12;
      case ConcentrationUnit.gL:
      case ConcentrationUnit.mgML:
        return val;
      case ConcentrationUnit.ugML:
        return val * 1e-3;
      case ConcentrationUnit.ngML:
        return val * 1e-6;
      case ConcentrationUnit.percent:
      case ConcentrationUnit.X:
      case ConcentrationUnit.gMol:
        return val;
    }
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

  Widget _buildConcRow(
    String label,
    double value,
    ConcentrationUnit unit,
    Function(double) onVal,
    Function(ConcentrationUnit) onUnit,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _DelayedTextField(
            initialValue: value.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: _uniformFontSize),
            onCommit: (v) => onVal(double.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<ConcentrationUnit>(
            initialValue: unit,
            decoration: const InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(),
            ),
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
      case ConcentrationUnit.pM:
        return 'pM';
      case ConcentrationUnit.gL:
        return 'g/L';
      case ConcentrationUnit.mgML:
        return 'mg/mL';
      case ConcentrationUnit.ugML:
        return 'µg/mL';
      case ConcentrationUnit.ngML:
        return 'ng/mL';
      case ConcentrationUnit.percent:
        return '%';
      case ConcentrationUnit.X:
        return 'X';
      case ConcentrationUnit.gMol:
        return 'g/mol';
    }
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
