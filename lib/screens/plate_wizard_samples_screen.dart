import 'package:flutter/material.dart';
import '../models/plate_wizard.dart';
import '../features/plate_wizard/models/plate_wizard_models.dart';
import '../features/plate_wizard/widgets/plate_result_preview.dart';
import '../widgets/unsaved_changes_pop_scope.dart';

class PlateWizardSamplesScreen extends StatefulWidget {
  final PlateLayoutWizard wizard;
  final Function(PlateLayoutWizard) onUpdate;

  const PlateWizardSamplesScreen({
    super.key,
    required this.wizard,
    required this.onUpdate,
  });

  @override
  State<PlateWizardSamplesScreen> createState() =>
      _PlateWizardSamplesScreenState();
}

class _PlateWizardSamplesScreenState extends State<PlateWizardSamplesScreen> {
  late PlateLayoutWizard _wizard;
  final Map<int, ScrollController> _scrollControllers = {};
  static const double _uniformFontSize = 14.0;
  bool _canActuallyPop = false;

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addTestItem({bool isStandardCurve = false}) {
    setState(() {
      _wizard = _wizard.copyWith(
        items: [
          ..._wizard.items,
          TestItem(
            sampleName: isStandardCurve
                ? 'Standard Curve ${_wizard.items.where((i) => i.isStandardCurve).length + 1}'
                : 'Sample ${_wizard.items.where((i) => !i.isStandardCurve).length + 1}',
            isStandardCurve: isStandardCurve,
            applyToAllPlates: isStandardCurve,
          ),
        ],
      );
    });
  }

  void _duplicateTestItem(int index) {
    setState(() {
      final itemToClone = _wizard.items[index];
      final newItem = itemToClone.copyWith(
        sampleName: '${itemToClone.sampleName} (Copy)',
      );
      final newItems = List<TestItem>.from(_wizard.items)
        ..insert(index + 1, newItem);
      _wizard = _wizard.copyWith(items: newItems);
    });
  }

  void _removeTestItem(int index) {
    setState(() {
      final newItems = List<TestItem>.from(_wizard.items)..removeAt(index);
      _wizard = _wizard.copyWith(items: newItems);
    });
  }

  void _updateTestItem(int index, TestItem newItem) {
    setState(() {
      final newItems = List<TestItem>.from(_wizard.items);
      newItems[index] = newItem;
      _wizard = _wizard.copyWith(items: newItems);
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
          title: const Text('Sample Manager'),
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
              _buildPlateSettings(),
              const SizedBox(height: 24),
              Text('Test Items', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ..._wizard.items.asMap().entries.map(
                (entry) => _buildTestItemEditor(entry.key, entry.value),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _addTestItem(isStandardCurve: true),
                        icon: const Icon(Icons.show_chart, color: Colors.amber),
                        label: const Text(
                          'Add Std Curve',
                          style: TextStyle(fontSize: _uniformFontSize),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade50,
                          foregroundColor: Colors.amber.shade900,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _addTestItem(isStandardCurve: false),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add Sample',
                          style: TextStyle(fontSize: _uniformFontSize),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildLayoutControls(),
              const SizedBox(height: 16),
              PlateResultPreview(wizard: _wizard),
              const SizedBox(height: 80),
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

  Widget _buildLayoutControls() {
    return Card(
      color: Colors.blue.shade50,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Layout Directions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDirectionToggle(
                    'Samples',
                    _wizard.sampleDirection,
                    (v) => setState(
                      () => _wizard = _wizard.copyWith(sampleDirection: v),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildDirectionToggle(
                    'Conditions',
                    _wizard.conditionDirection,
                    (v) => setState(
                      () => _wizard = _wizard.copyWith(conditionDirection: v),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildDirectionToggle(
                    'Dilutions',
                    _wizard.dilutionDirection,
                    (v) => setState(
                      () => _wizard = _wizard.copyWith(dilutionDirection: v),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildDirectionToggle(
                    'Replicates',
                    _wizard.duplicateDirection,
                    (v) => setState(
                      () => _wizard = _wizard.copyWith(duplicateDirection: v),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionToggle(
    String label,
    Direction current,
    Function(Direction) onChanged,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 8),
        ToggleButtons(
          direction: Axis.vertical,
          isSelected: [
            current == Direction.horizontal,
            current == Direction.vertical,
          ],
          onPressed: (idx) =>
              onChanged(idx == 0 ? Direction.horizontal : Direction.vertical),
          constraints: const BoxConstraints(minHeight: 32, minWidth: 38),
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: Colors.blue.shade600,
          color: Colors.blue.shade900,
          children: const [
            Icon(Icons.arrow_forward, size: 16),
            Icon(Icons.arrow_downward, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildPlateSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plate Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DelayedTextField(
                    initialValue: _wizard.rows.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rows',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _wizard = _wizard.copyWith(
                        rows: int.tryParse(v) ?? 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DelayedTextField(
                    initialValue: _wizard.columns.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Columns',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _wizard = _wizard.copyWith(
                        columns: int.tryParse(v) ?? 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DelayedTextField(
                    initialValue: _wizard.plateCount.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Plate Count',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _wizard = _wizard.copyWith(
                        plateCount: int.tryParse(v) ?? 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestItemEditor(int index, TestItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: item.isStandardCurve ? 4 : 1,
      shape: item.isStandardCurve
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.amber, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.isStandardCurve)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'STANDARD CURVE',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: _uniformFontSize - 4,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Apply to all plates',
                        style: TextStyle(fontSize: _uniformFontSize - 4),
                      ),
                      Switch(
                        value: item.applyToAllPlates,
                        onChanged: (v) => _updateTestItem(
                          index,
                          item.copyWith(applyToAllPlates: v),
                        ),
                        activeThumbColor: Colors.amber,
                        activeTrackColor: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: _DelayedTextField(
                    decoration: InputDecoration(
                      labelText: item.isStandardCurve
                          ? 'Curve Name'
                          : 'Sample Name',
                      hintText: item.isStandardCurve
                          ? 'e.g., Protein Std'
                          : 'e.g., Control, Sample A',
                    ),
                    initialValue: item.sampleName,
                    style: const TextStyle(
                      fontSize: _uniformFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    onCommit: (v) =>
                        _updateTestItem(index, item.copyWith(sampleName: v)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blue),
                  tooltip: 'Duplicate Item',
                  onPressed: () => _duplicateTestItem(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeTestItem(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildListField(
              'Conditions',
              item.conditions,
              (newList) =>
                  _updateTestItem(index, item.copyWith(conditions: newList)),
            ),
            const SizedBox(height: 12),
            _buildListField(
              'Dilutions',
              item.dilutions,
              (newList) =>
                  _updateTestItem(index, item.copyWith(dilutions: newList)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Replicates: ',
                  style: TextStyle(fontSize: _uniformFontSize),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: item.duplicates,
                  items: [1, 2, 3, 4, 5, 6, 8, 12]
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            d.toString(),
                            style: const TextStyle(fontSize: _uniformFontSize),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      _updateTestItem(index, item.copyWith(duplicates: v!)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListField(
    String label,
    List<String> values,
    Function(List<String>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _uniformFontSize - 2,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...values.asMap().entries.map((entry) {
              return SizedBox(
                width: 110,
                child: _DelayedTextField(
                  decoration: InputDecoration(
                    hintText: 'Enter...',
                    isDense: true,
                    suffixIcon: values.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              final newList = List<String>.from(values)
                                ..removeAt(entry.key);
                              onChanged(newList);
                            },
                          )
                        : null,
                  ),
                  initialValue: entry.value,
                  style: const TextStyle(fontSize: _uniformFontSize - 2),
                  onCommit: (v) {
                    final newList = List<String>.from(values);
                    newList[entry.key] = v;
                    onChanged(newList);
                  },
                ),
              );
            }),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                size: 20,
                color: Colors.green,
              ),
              onPressed: () {
                final newList = List<String>.from(values)..add('');
                onChanged(newList);
              },
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
  final TextStyle? style;
  final TextInputType keyboardType;

  const _DelayedTextField({
    required this.initialValue,
    required this.onCommit,
    required this.decoration,
    this.style,
    this.keyboardType = TextInputType.text,
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
      onSubmitted: (v) => widget.onCommit(v),
      style: widget.style,
      keyboardType: widget.keyboardType,
    );
  }
}
