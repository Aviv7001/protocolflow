import 'package:flutter/material.dart';

import '../../lab_math/lab_calculation.dart';
import '../../lab_math/widgets/concentration_input_row.dart';
import '../models/serial_dilution_input.dart';
import '../services/serial_dilution_calculator_service.dart';
import '../widgets/serial_dilution_result_table.dart';
import '../../../widgets/unsaved_changes_pop_scope.dart';

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
  bool _canActuallyPop = false;

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
    ConcentrationUnit.X,
    ConcentrationUnit.ratio,
    ConcentrationUnit.cellsML,
  ];
  static const _solidConcentrationUnits = [
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
    _input = _normalizeInputForEditor(widget.input);
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculator.generateDilutionTable(_input);

    return UnsavedChangesPopScope(
      canPop: _canActuallyPop,
      message:
          'You have unsaved changes in this table. Are you sure you want to exit?',
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildGlobalResultPreview(dynamic result) {
    if (result.success != true) return const SizedBox.shrink();

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _resItem(
                  'Dilutions',
                  result.calculatedNumberOfDilutions.toString(),
                  Colors.blue,
                ),
                _resItemEditable(
                  'Final Volume',
                  result.optimizedFinalVolumeUl,
                  (val) {
                    final rounded = (val * 10).round() / 10.0;
                    setState(
                      () => _input = _input.copyWith(
                        finalVolume: rounded,
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
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              initialValue: _input.title,
              style: const TextStyle(fontSize: _uniformFontSize),
              onCommit: (v) =>
                  setState(() => _input = _input.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DelayedTextField(
                    decoration: InputDecoration(
                      labelText:
                          _input.startingSourceType ==
                              ReagentSourceType.solidMaterial
                          ? 'Solid Material Name'
                          : 'Stock Solution Name',
                      border: const OutlineInputBorder(),
                    ),
                    initialValue: _input.stockSolutionName,
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _input = _input.copyWith(stockSolutionName: v),
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
                  selected: {_input.startingSourceType},
                  onSelectionChanged: (selection) {
                    final sourceType = selection.first;
                    setState(() {
                      final stockUnit = _coerceUnitForSource(
                        _input.stockConcentrationUnit,
                        sourceType,
                      );
                      final startingUnit = _coerceUnitForSource(
                        _input.startingDilutionConcentrationUnit ?? stockUnit,
                        sourceType,
                      );
                      final targetUnits = _compatibleUnits(startingUnit);
                      final currentTarget =
                          _input.targetLowestConcentrationUnit;
                      _input = _input.copyWith(
                        startingSourceType: sourceType,
                        stockConcentrationUnit: stockUnit,
                        startingDilutionConcentrationUnit: startingUnit,
                        targetLowestConcentrationUnit:
                            currentTarget != null &&
                                targetUnits.contains(currentTarget)
                            ? currentTarget
                            : startingUnit,
                      );
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (_input.startingSourceType == ReagentSourceType.liquidStock) ...[
              const SizedBox(height: 12),
              _buildConcRow(
                'Stock Concentration',
                _input.stockConcentration,
                _input.stockConcentrationUnit,
                _allowedConcentrationUnits,
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
            ],
            const SizedBox(height: 12),
            _buildStartingConcRow(),
            if (_needsMolecularWeight()) ...[
              const SizedBox(height: 12),
              _DelayedTextField(
                decoration: const InputDecoration(
                  labelText: 'Molecular weight (g/mol)',
                  border: OutlineInputBorder(),
                ),
                initialValue: _input.molecularWeight?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: _uniformFontSize),
                onCommit: (v) => setState(
                  () => _input = _input.copyWith(
                    molecularWeight: double.tryParse(v),
                    clearMolecularWeight: v.trim().isEmpty,
                  ),
                ),
              ),
            ],
            if (_input.startingSourceType == ReagentSourceType.liquidStock)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _input = _input.copyWith(
                      startingDilutionConcentration: _input.stockConcentration,
                      startingDilutionConcentrationUnit:
                          _input.stockConcentrationUnit,
                    ),
                  ),
                  icon: const Icon(Icons.science, size: 18),
                  label: const Text('Use stock as D0'),
                ),
              ),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto optimize extra volume'),
              subtitle: const Text(
                'Try 10% to 30% and choose the best transfer score',
              ),
              value: _input.autoExtraVolume,
              onChanged: (value) => setState(
                () => _input = _input.copyWith(autoExtraVolume: value),
              ),
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
    return ConcentrationInputRow(
      label: _input.startingSourceType == ReagentSourceType.solidMaterial
          ? 'D0 Final Concentration'
          : 'Starting Dilution Concentration (D0)',
      value: _input.startingDilutionConcentration ?? 0,
      unit: unit,
      units: _input.startingSourceType == ReagentSourceType.solidMaterial
          ? _solidConcentrationUnits
          : _compatibleUnits(_input.stockConcentrationUnit),
      onValueChanged: (value) => setState(
        () => _input = _input.copyWith(startingDilutionConcentration: value),
      ),
      onUnitChanged: (unit) => setState(() {
        final targetUnits = _compatibleUnits(unit);
        final currentTarget = _input.targetLowestConcentrationUnit;
        _input = _input.copyWith(
          stockConcentrationUnit:
              _input.startingSourceType == ReagentSourceType.solidMaterial
              ? unit
              : _input.stockConcentrationUnit,
          startingDilutionConcentrationUnit: unit,
          targetLowestConcentrationUnit:
              currentTarget != null && targetUnits.contains(currentTarget)
              ? currentTarget
              : unit,
        );
      }),
      fontSize: _uniformFontSize,
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
    final unit = _input.targetLowestConcentrationUnit ?? _seriesBaseUnit();
    return ConcentrationInputRow(
      label: 'Target Lowest Concentration',
      value: _input.targetLowestConcentration ?? 0,
      unit: unit,
      units: _compatibleUnits(_seriesBaseUnit()),
      onValueChanged: (value) => setState(
        () => _input = _input.copyWith(targetLowestConcentration: value),
      ),
      onUnitChanged: (unit) => setState(
        () => _input = _input.copyWith(targetLowestConcentrationUnit: unit),
      ),
      fontSize: _uniformFontSize,
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

  Future<void> _handleDone(BuildContext context) async {
    final name = await _showSaveDialog(context, _input.title);
    if (name != null) {
      setState(() => _input = _input.copyWith(title: name));
      widget.onUpdate(_input);
      if (context.mounted) {
        setState(() => _canActuallyPop = true);
        Navigator.pop(context, _input);
      }
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

  ConcentrationUnit _seriesBaseUnit() {
    return _input.startingSourceType == ReagentSourceType.solidMaterial
        ? _input.startingDilutionConcentrationUnit ??
              _input.stockConcentrationUnit
        : _input.stockConcentrationUnit;
  }

  ConcentrationUnit _coerceUnitForSource(
    ConcentrationUnit unit,
    ReagentSourceType sourceType,
  ) {
    final allowed = sourceType == ReagentSourceType.solidMaterial
        ? _solidConcentrationUnits
        : _allowedConcentrationUnits;
    return allowed.contains(unit) ? unit : allowed.first;
  }

  SerialDilutionInput _normalizeInputForEditor(SerialDilutionInput input) {
    final stockUnit = _coerceUnitForSource(
      input.stockConcentrationUnit,
      input.startingSourceType,
    );
    final startingUnit = _coerceUnitForSource(
      input.startingDilutionConcentrationUnit ?? stockUnit,
      input.startingSourceType,
    );
    final targetUnits = _compatibleUnits(startingUnit);
    final currentTarget = input.targetLowestConcentrationUnit;
    return input.copyWith(
      stockConcentrationUnit: stockUnit,
      startingDilutionConcentrationUnit: startingUnit,
      targetLowestConcentrationUnit:
          currentTarget != null && targetUnits.contains(currentTarget)
          ? currentTarget
          : startingUnit,
    );
  }

  bool _needsMolecularWeight() {
    if (_input.startingSourceType != ReagentSourceType.solidMaterial) {
      return false;
    }
    final unit =
        _input.startingDilutionConcentrationUnit ??
        _input.stockConcentrationUnit;
    return LabCalculation.familyOf(unit) == ConcentrationFamily.molar;
  }

  bool _sameFamily(ConcentrationUnit unit, ConcentrationUnit? other) {
    return other != null && _family(unit) == _family(other);
  }

  ConcentrationFamily _family(ConcentrationUnit unit) {
    return LabCalculation.familyOf(unit);
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
