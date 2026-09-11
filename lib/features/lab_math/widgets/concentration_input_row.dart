import 'package:flutter/material.dart';

import '../lab_calculation.dart';

class ConcentrationInputRow extends StatefulWidget {
  final String label;
  final double value;
  final ConcentrationUnit unit;
  final List<ConcentrationUnit> units;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<ConcentrationUnit> onUnitChanged;
  final double fontSize;
  final bool separateUnitParts;

  const ConcentrationInputRow({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.units,
    required this.onValueChanged,
    required this.onUnitChanged,
    this.fontSize = 14,
    this.separateUnitParts = false,
  });

  @override
  State<ConcentrationInputRow> createState() => _ConcentrationInputRowState();
}

class _ConcentrationInputRowState extends State<ConcentrationInputRow> {
  late final TextEditingController _valueController;
  late final TextEditingController _exponentController;
  late final FocusNode _valueFocusNode;
  late final FocusNode _exponentFocusNode;

  bool get _isRatio => widget.unit == ConcentrationUnit.ratio;
  bool get _isCells => widget.unit == ConcentrationUnit.cellsML;

  int get _currentExponent => LabCalculation.cellsExponent(widget.value);

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController();
    _exponentController = TextEditingController();
    _valueFocusNode = FocusNode()..addListener(_handleValueFocus);
    _exponentFocusNode = FocusNode()..addListener(_handleExponentFocus);
    _syncControllers();
  }

  @override
  void didUpdateWidget(ConcentrationInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.unit != widget.unit) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    if (!_valueFocusNode.hasFocus) {
      _valueController.text = LabCalculation.concentrationInputText(
        widget.value,
        widget.unit,
      );
    }
    if (!_exponentFocusNode.hasFocus) {
      _exponentController.text = _currentExponent.toString();
    }
  }

  void _handleValueFocus() {
    if (!_valueFocusNode.hasFocus) _commitValue(_valueController.text);
  }

  void _handleExponentFocus() {
    if (!_exponentFocusNode.hasFocus) {
      _commitExponent(_exponentController.text);
    }
  }

  void _commitValue(String text) {
    final parsed = LabCalculation.parseConcentrationInput(
      text,
      widget.unit,
      cellsExponent: int.tryParse(_exponentController.text) ?? _currentExponent,
    );
    if (parsed != null) {
      if (_isRatio) {
        _valueController.text = LabCalculation.concentrationInputText(
          parsed,
          widget.unit,
        );
        _valueController.selection = TextSelection.collapsed(
          offset: _valueController.text.length,
        );
      }
      widget.onValueChanged(parsed);
    }
  }

  void _commitExponent(String text) {
    final exponent = int.tryParse(text);
    final coefficient = double.tryParse(_valueController.text);
    if (exponent == null || coefficient == null) {
      _syncControllers();
      return;
    }
    final parsed = LabCalculation.parseConcentrationInput(
      coefficient.toString(),
      ConcentrationUnit.cellsML,
      cellsExponent: exponent,
    );
    if (parsed != null) widget.onValueChanged(parsed);
  }

  @override
  void dispose() {
    _valueFocusNode
      ..removeListener(_handleValueFocus)
      ..dispose();
    _exponentFocusNode
      ..removeListener(_handleExponentFocus)
      ..dispose();
    _valueController.dispose();
    _exponentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final valueAndExponent = Row(
          children: [
            Expanded(child: _buildValueField()),
            if (_isCells) ...[
              const SizedBox(width: 8),
              SizedBox(width: 84, child: _buildExponentField()),
            ],
          ],
        );

        final canKeepSplitUnitsInline =
            widget.separateUnitParts &&
            !_isCells &&
            constraints.maxWidth >= 300;

        if (constraints.maxWidth < 520 && !canKeepSplitUnitsInline) {
          return Column(
            children: [
              valueAndExponent,
              const SizedBox(height: 12),
              _buildUnitField(),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: canKeepSplitUnitsInline ? 2 : (_isCells ? 3 : 2),
              child: valueAndExponent,
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: canKeepSplitUnitsInline ? 3 : (_isCells ? 2 : 1),
              child: _buildUnitField(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildValueField() {
    return TextField(
      controller: _valueController,
      focusNode: _valueFocusNode,
      keyboardType: _isRatio
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: _isRatio ? '1:50 or 1/50' : null,
      ),
      style: TextStyle(fontSize: widget.fontSize),
      onSubmitted: _commitValue,
    );
  }

  Widget _buildExponentField() {
    return TextField(
      controller: _exponentController,
      focusNode: _exponentFocusNode,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: const InputDecoration(labelText: 'x10^'),
      style: TextStyle(fontSize: widget.fontSize),
      onSubmitted: _commitExponent,
    );
  }

  Widget _buildUnitField() {
    if (widget.separateUnitParts) return _buildSeparatedUnitFields();
    return DropdownButtonFormField<ConcentrationUnit>(
      key: ValueKey('${widget.label}_${widget.unit.name}'),
      initialValue: widget.unit,
      decoration: const InputDecoration(labelText: 'Unit'),
      items: widget.units
          .map(
            (unit) => DropdownMenuItem(
              value: unit,
              child: Text(
                LabCalculation.unitLabel(unit),
                style: TextStyle(fontSize: widget.fontSize),
              ),
            ),
          )
          .toList(),
      onChanged: (unit) {
        if (unit != null) widget.onUnitChanged(unit);
      },
    );
  }

  Widget _buildSeparatedUnitFields() {
    final currentParts = _unitParts(widget.unit);
    final numeratorLabels = <String>[];
    for (final unit in widget.units) {
      final numerator = _unitParts(unit).numerator;
      if (!numeratorLabels.contains(numerator)) numeratorLabels.add(numerator);
    }
    final denominatorUnits = widget.units
        .where(
          (unit) =>
              _unitParts(unit).numerator == currentParts.numerator &&
              _unitParts(unit).denominator != null,
        )
        .toList();

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(
              '${widget.label}_numerator_${currentParts.numerator}',
            ),
            initialValue: currentParts.numerator,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Numerator'),
            items: numeratorLabels
                .map(
                  (numerator) => DropdownMenuItem(
                    value: numerator,
                    child: Text(
                      numerator,
                      style: TextStyle(fontSize: widget.fontSize),
                    ),
                  ),
                )
                .toList(),
            onChanged: (numerator) {
              if (numerator == null) return;
              final matchingUnits = widget.units
                  .where((unit) => _unitParts(unit).numerator == numerator)
                  .toList();
              final matchingDenominator = matchingUnits.where(
                (unit) =>
                    _unitParts(unit).denominator == currentParts.denominator,
              );
              widget.onUnitChanged(
                matchingDenominator.isNotEmpty
                    ? matchingDenominator.first
                    : matchingUnits.first,
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('/', style: TextStyle(fontSize: 28)),
        ),
        Expanded(
          child: currentParts.denominator == null
              ? const InputDecorator(
                  decoration: InputDecoration(labelText: 'Denominator'),
                  child: Text('—'),
                )
              : DropdownButtonFormField<ConcentrationUnit>(
                  key: ValueKey(
                    '${widget.label}_denominator_${widget.unit.name}',
                  ),
                  initialValue: widget.unit,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Denominator'),
                  items: denominatorUnits
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(
                            _unitParts(unit).denominator!,
                            style: TextStyle(fontSize: widget.fontSize),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (unit) {
                    if (unit != null) widget.onUnitChanged(unit);
                  },
                ),
        ),
      ],
    );
  }

  ({String numerator, String? denominator}) _unitParts(ConcentrationUnit unit) {
    return switch (unit) {
      ConcentrationUnit.M => (numerator: 'mol', denominator: 'L'),
      ConcentrationUnit.mM => (numerator: 'mmol', denominator: 'L'),
      ConcentrationUnit.uM => (numerator: 'µmol', denominator: 'L'),
      ConcentrationUnit.nM => (numerator: 'nmol', denominator: 'L'),
      ConcentrationUnit.pM => (numerator: 'pmol', denominator: 'L'),
      ConcentrationUnit.gL => (numerator: 'g', denominator: 'L'),
      ConcentrationUnit.gML => (numerator: 'g', denominator: 'mL'),
      ConcentrationUnit.gUL => (numerator: 'g', denominator: 'µL'),
      ConcentrationUnit.mgL => (numerator: 'mg', denominator: 'L'),
      ConcentrationUnit.mgML => (numerator: 'mg', denominator: 'mL'),
      ConcentrationUnit.mgUL => (numerator: 'mg', denominator: 'µL'),
      ConcentrationUnit.ugL => (numerator: 'µg', denominator: 'L'),
      ConcentrationUnit.ugML => (numerator: 'µg', denominator: 'mL'),
      ConcentrationUnit.ugUL => (numerator: 'µg', denominator: 'µL'),
      ConcentrationUnit.ngL => (numerator: 'ng', denominator: 'L'),
      ConcentrationUnit.ngML => (numerator: 'ng', denominator: 'mL'),
      ConcentrationUnit.ngUL => (numerator: 'ng', denominator: 'µL'),
      ConcentrationUnit.percent => (numerator: '%', denominator: null),
      ConcentrationUnit.X => (numerator: 'X', denominator: null),
      ConcentrationUnit.ratio => (numerator: 'Ratio', denominator: null),
      ConcentrationUnit.cellsML => (numerator: 'cells', denominator: 'mL'),
      ConcentrationUnit.gMol => (numerator: 'g', denominator: 'mol'),
    };
  }
}
