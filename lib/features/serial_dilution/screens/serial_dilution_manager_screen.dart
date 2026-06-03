import 'package:flutter/material.dart';

import '../../master_mix/services/master_mix_calculator_service.dart'
    show ConcentrationFamily, ConcentrationUnit, VolumeUnit;
import '../models/serial_dilution_input.dart';
import '../services/serial_dilution_calculator_service.dart';
import '../widgets/serial_dilution_result_table.dart';

class SerialDilutionManagerScreen extends StatefulWidget {
  final SerialDilutionInput input;
  final Function(SerialDilutionInput) onUpdate;

  const SerialDilutionManagerScreen({
    super.key,
    required this.input,
    required this.onUpdate,
  });

  @override
  State<SerialDilutionManagerScreen> createState() =>
      _SerialDilutionManagerScreenState();
}

class _SerialDilutionManagerScreenState
    extends State<SerialDilutionManagerScreen> {
  late SerialDilutionInput _input;
  final _calculator = SerialDilutionCalculatorService();
  static const double _uniformFontSize = 14.0;

  static const _allowedConcentrationUnits = [
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

  @override
  void initState() {
    super.initState();
    _input = widget.input;
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculator.generateDilutionTable(_input);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Dilution Manager'),
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
            const SizedBox(height: 16),
            _buildDilutionOptions(),
            const SizedBox(height: 24),
            _buildGlobalResultPreview(result),
            const SizedBox(height: 12),
            SerialDilutionResultTable(input: _input, calculator: _calculator),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalResultPreview(dynamic result) {
    if (result.success != true) return const SizedBox.shrink();

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _resItem(
              'Dilutions',
              result.calculatedNumberOfDilutions.toString(),
              Colors.blue,
            ),
            _resItemEditable('Final Volume', result.optimizedFinalVolumeUl, (
              val,
            ) {
              final rounded = (val * 10).round() / 10.0;
              setState(
                () => _input = _input.copyWith(
                  finalVolume: rounded,
                  finalVolumeUnit: VolumeUnit.uL,
                ),
              );
            }, Colors.black),
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
              initialValue: _input.title,
              style: const TextStyle(fontSize: _uniformFontSize),
              onCommit: (v) =>
                  setState(() => _input = _input.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            _DelayedTextField(
              decoration: const InputDecoration(
                labelText: 'Stock Solution Name',
                border: OutlineInputBorder(),
              ),
              initialValue: _input.stockSolutionName,
              style: const TextStyle(fontSize: _uniformFontSize),
              onCommit: (v) => setState(
                () => _input = _input.copyWith(stockSolutionName: v),
              ),
            ),
            const SizedBox(height: 12),
            _buildConcRow(
              'Stock Concentration',
              _input.stockConcentration,
              _input.stockConcentrationUnit,
              (v) => setState(
                () => _input = _input.copyWith(stockConcentration: v),
              ),
              (u) => setState(
                () => _input = _input.copyWith(
                  stockConcentrationUnit: u,
                  startingDilutionConcentrationUnit:
                      _sameFamily(u, _input.startingDilutionConcentrationUnit)
                      ? _input.startingDilutionConcentrationUnit
                      : u,
                  targetLowestConcentrationUnit:
                      _sameFamily(u, _input.targetLowestConcentrationUnit)
                      ? _input.targetLowestConcentrationUnit
                      : u,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildStartingConcRow(),
            const SizedBox(height: 12),
            _DelayedTextField(
              decoration: const InputDecoration(
                labelText: 'Solvent Name',
                border: OutlineInputBorder(),
              ),
              initialValue: _input.solventName,
              style: const TextStyle(fontSize: _uniformFontSize),
              onCommit: (v) =>
                  setState(() => _input = _input.copyWith(solventName: v)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDilutionOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dilution Setup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DelayedTextField(
                    initialValue: _input.dilutionFactor.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Dilution Factor',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _input = _input.copyWith(
                        dilutionFactor: double.tryParse(v) ?? 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DelayedTextField(
                    initialValue: _input.extraVolumePercent.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Extra Volume %',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _input = _input.copyWith(
                        extraVolumePercent: double.tryParse(v) ?? 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildVolumeRow(),
            const SizedBox(height: 12),
            DropdownButtonFormField<DilutionMode>(
              initialValue: _input.dilutionMode,
              decoration: const InputDecoration(
                labelText: 'Dilution Mode',
                border: OutlineInputBorder(),
              ),
              items: DilutionMode.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        _dilutionModeLabel(m),
                        style: const TextStyle(fontSize: _uniformFontSize),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _input = _input.copyWith(dilutionMode: v)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SeriesLengthMode>(
              initialValue: _input.seriesLengthMode,
              decoration: const InputDecoration(
                labelText: 'Series Length Mode',
                border: OutlineInputBorder(),
              ),
              items: SeriesLengthMode.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        _seriesModeLabel(m),
                        style: const TextStyle(fontSize: _uniformFontSize),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _input = _input.copyWith(seriesLengthMode: v)),
            ),
            const SizedBox(height: 12),
            if (_input.seriesLengthMode == SeriesLengthMode.numberOfDilutions)
              _DelayedTextField(
                initialValue: (_input.numberOfDilutions ?? 8).toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Dilutions',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: _uniformFontSize),
                onCommit: (v) => setState(
                  () => _input = _input.copyWith(
                    numberOfDilutions: int.tryParse(v) ?? 0,
                  ),
                ),
              )
            else
              _buildTargetConcRow(),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(
                () => _input = _input.copyWith(
                  includeZeroConcentrationRow:
                      !_input.includeZeroConcentrationRow,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _input.includeZeroConcentrationRow,
                    onChanged: (v) => setState(
                      () => _input = _input.copyWith(
                        includeZeroConcentrationRow: v ?? false,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Include zero concentration row',
                      style: TextStyle(fontSize: _uniformFontSize),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartingConcRow() {
    final unit =
        _input.startingDilutionConcentrationUnit ??
        _input.stockConcentrationUnit;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _DelayedTextField(
            initialValue: (_input.startingDilutionConcentration ?? 0)
                .toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Starting Dilution Concentration (D0)',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: _uniformFontSize),
            onCommit: (v) => setState(
              () => _input = _input.copyWith(
                startingDilutionConcentration: double.tryParse(v) ?? 0,
              ),
            ),
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
            items: _compatibleUnits(_input.stockConcentrationUnit)
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
            onChanged: (v) => setState(
              () => _input = _input.copyWith(
                startingDilutionConcentrationUnit: v,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _DelayedTextField(
            initialValue: _input.finalVolume.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Final Volume / Dilution',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: _uniformFontSize),
            onCommit: (v) => setState(
              () => _input = _input.copyWith(
                finalVolume: double.tryParse(v) ?? 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<VolumeUnit>(
            initialValue: _input.finalVolumeUnit,
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
                      style: const TextStyle(fontSize: _uniformFontSize),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) =>
                setState(() => _input = _input.copyWith(finalVolumeUnit: v)),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetConcRow() {
    final unit =
        _input.targetLowestConcentrationUnit ?? _input.stockConcentrationUnit;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _DelayedTextField(
            initialValue: (_input.targetLowestConcentration ?? 0).toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target Lowest Concentration',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: _uniformFontSize),
            onCommit: (v) => setState(
              () => _input = _input.copyWith(
                targetLowestConcentration: double.tryParse(v) ?? 0,
              ),
            ),
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
            items: _compatibleUnits(_input.stockConcentrationUnit)
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
            onChanged: (v) => setState(
              () => _input = _input.copyWith(targetLowestConcentrationUnit: v),
            ),
          ),
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
            items: _allowedConcentrationUnits
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

  Future<void> _handleDone(BuildContext context) async {
    final name = await _showSaveDialog(context, _input.title);
    if (name != null) {
      setState(() => _input = _input.copyWith(title: name));
      widget.onUpdate(_input);
      if (context.mounted) Navigator.pop(context, _input);
    }
  }

  Future<String?> _showSaveDialog(BuildContext context, String suggestedName) {
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
    final useMl = valUl >= 1000;
    final displayVal = useMl
        ? (valUl / 1000).toStringAsFixed(2)
        : valUl.toStringAsFixed(1);
    final unit = useMl ? 'mL' : 'uL';
    final factor = useMl ? 1000.0 : 1.0;

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
                onCommit: (v) => onVal((double.tryParse(v) ?? 0) * factor),
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

  List<ConcentrationUnit> _compatibleUnits(ConcentrationUnit stockUnit) {
    final family = _family(stockUnit);
    return _allowedConcentrationUnits
        .where((u) => _family(u) == family)
        .toList();
  }

  bool _sameFamily(ConcentrationUnit unit, ConcentrationUnit? other) {
    return other != null && _family(unit) == _family(other);
  }

  ConcentrationFamily _family(ConcentrationUnit unit) {
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

  String _dilutionModeLabel(DilutionMode mode) {
    switch (mode) {
      case DilutionMode.forward:
        return 'Forward Dilution';
      case DilutionMode.independent:
        return 'Independent Dilution';
    }
  }

  String _seriesModeLabel(SeriesLengthMode mode) {
    switch (mode) {
      case SeriesLengthMode.numberOfDilutions:
        return 'Number of dilutions';
      case SeriesLengthMode.targetLowestConcentration:
        return 'Target lowest concentration';
    }
  }

  String _unitLabel(ConcentrationUnit unit) {
    switch (unit) {
      case ConcentrationUnit.M:
        return 'M';
      case ConcentrationUnit.mM:
        return 'mM';
      case ConcentrationUnit.uM:
        return 'uM';
      case ConcentrationUnit.nM:
        return 'nM';
      case ConcentrationUnit.pM:
        return 'pM';
      case ConcentrationUnit.gL:
        return 'g/L';
      case ConcentrationUnit.mgML:
        return 'mg/mL';
      case ConcentrationUnit.ugML:
        return 'ug/mL';
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
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) widget.onCommit(_controller.text);
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
      onSubmitted: widget.onCommit,
    );
  }
}
