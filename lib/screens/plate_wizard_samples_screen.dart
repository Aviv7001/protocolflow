import 'package:flutter/material.dart';
import '../models/plate_wizard.dart';
import '../features/plate_wizard/models/plate_wizard_models.dart';
import '../features/plate_wizard/services/plate_long_format_service.dart';
import '../features/plate_wizard/widgets/plate_result_preview.dart';
import '../widgets/unsaved_changes_pop_scope.dart';
import '../widgets/protocolflow_app_bar.dart';
import '../widgets/table_workspace.dart';
import '../theme/app_colors.dart';

enum _SampleCardAction { duplicate, moveUp, moveDown, manualFit, useAuto }

class PlateWizardSamplesScreen extends StatefulWidget {
  final PlateLayoutWizard wizard;
  final Function(PlateLayoutWizard) onUpdate;
  final bool promptForSaveDetails;

  const PlateWizardSamplesScreen({
    super.key,
    required this.wizard,
    required this.onUpdate,
    this.promptForSaveDetails = true,
  });

  @override
  State<PlateWizardSamplesScreen> createState() =>
      _PlateWizardSamplesScreenState();
}

class _PlateWizardSamplesScreenState extends State<PlateWizardSamplesScreen> {
  late PlateLayoutWizard _wizard;
  final Map<int, ScrollController> _scrollControllers = {};
  final _longFormatService = const PlateLongFormatService();
  final Set<String> _collapsedItemIds = {};
  static const double _uniformFontSize = 14.0;
  bool _canActuallyPop = false;
  int? _manualFitIndex;
  List<PlateWellPosition> _draftManualWells = [];
  final List<List<PlateWellPosition>> _manualSelectionHistory = [];
  Map<String, String> _lockedWellOwners = {};

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
      _clearChooseWellsState();
      _wizard = _asGeneratedLayout(
        _wizard.copyWith(
          items: [
            ..._wizard.items,
            TestItem(
              sampleName: isStandardCurve
                  ? 'Standard Curve ${_wizard.items.where((i) => i.isStandardCurve).length + 1}'
                  : 'Sample ${_wizard.items.where((i) => !i.isStandardCurve).length + 1}',
              colorHex: _sampleColorForIndex(_wizard.items.length),
              isStandardCurve: isStandardCurve,
              applyToAllPlates: isStandardCurve,
            ),
          ],
        ),
      );
    });
  }

  void _duplicateTestItem(int index) {
    setState(() {
      _clearChooseWellsState();
      final itemToClone = _wizard.items[index];
      final newItem = itemToClone.copyWith(
        id: 'sample_${DateTime.now().microsecondsSinceEpoch}',
        sampleName: '${itemToClone.sampleName} (Copy)',
        manualWells: const [],
      );
      final newItems = List<TestItem>.from(_wizard.items)
        ..insert(index + 1, newItem);
      _wizard = _asGeneratedLayout(_wizard.copyWith(items: newItems));
    });
  }

  void _removeTestItem(int index) {
    setState(() {
      _clearChooseWellsState();
      final newItems = List<TestItem>.from(_wizard.items)..removeAt(index);
      _collapsedItemIds.remove(_wizard.items[index].id);
      _wizard = _asGeneratedLayout(_wizard.copyWith(items: newItems));
    });
  }

  void _updateTestItem(int index, TestItem newItem) {
    setState(() {
      final newItems = List<TestItem>.from(_wizard.items);
      newItems[index] = newItem;
      _wizard = _asGeneratedLayout(_wizard.copyWith(items: newItems));
    });
  }

  void _moveTestItem(int index, int offset) {
    _moveTestItemTo(index, index + offset);
  }

  void _moveTestItemTo(int index, int target) {
    if (target < 0 || target >= _wizard.items.length) return;
    setState(() {
      _clearChooseWellsState();
      final items = List<TestItem>.from(_wizard.items);
      final item = items.removeAt(index);
      items.insert(target, item);
      _wizard = _asGeneratedLayout(_wizard.copyWith(items: items));
    });
  }

  void _toggleAllCards() {
    setState(() {
      final allCollapsed = _wizard.items.every(
        (item) => _collapsedItemIds.contains(item.id),
      );
      if (allCollapsed) {
        _collapsedItemIds.clear();
      } else {
        _collapsedItemIds
          ..clear()
          ..addAll(_wizard.items.map((item) => item.id));
      }
    });
  }

  void _autoFitAll() {
    setState(() {
      _clearChooseWellsState();
      final items = _wizard.items.map(_autoDirectionsFor).toList();
      _wizard = _asGeneratedLayout(_wizard.copyWith(items: items));
    });
  }

  TestItem _autoDirectionsFor(TestItem item) {
    return item.copyWith(
      variables: item.variables
          .map((variable) => variable.copyWith(direction: Direction.auto))
          .toList(),
      sampleDirection: Direction.auto,
      duplicateDirection: Direction.auto,
      manualWells: const [],
    );
  }

  void _startChooseWells(int index) {
    final tables = _wizard.generateTables();
    final locked = <String, String>{};
    for (var plateIndex = 0; plateIndex < tables.length; plateIndex++) {
      final table = tables[plateIndex];
      for (var row = 0; row < table.data.length; row++) {
        for (var column = 0; column < table.data[row].length; column++) {
          final owner = table.data[row][column].toString().split('\n').first;
          if (owner.isNotEmpty && owner != _wizard.items[index].sampleName) {
            locked['$plateIndex:$row:$column'] = owner;
          }
        }
      }
    }
    setState(() {
      _manualFitIndex = index;
      _draftManualWells = List.of(_wizard.items[index].manualWells);
      _manualSelectionHistory.clear();
      _lockedWellOwners = locked;
    });
  }

  void _clearChooseWellsState() {
    _manualFitIndex = null;
    _draftManualWells = [];
    _manualSelectionHistory.clear();
    _lockedWellOwners = {};
  }

  void _cancelChooseWells() => setState(_clearChooseWellsState);

  void _undoManualSelection() {
    if (_manualSelectionHistory.isEmpty) return;
    setState(() {
      _draftManualWells = _manualSelectionHistory.removeLast();
    });
  }

  void _clearManualSelection() {
    if (_draftManualWells.isEmpty) return;
    setState(() {
      _manualSelectionHistory.add(List.of(_draftManualWells));
      _draftManualWells = [];
    });
  }

  void _applyChooseWells() {
    final index = _manualFitIndex;
    if (index == null) return;
    final item = _wizard.items[index];
    final candidate = _wizard.copyWith(
      items: List<TestItem>.from(_wizard.items)
        ..[index] = item.copyWith(manualWells: _draftManualWells),
    );
    final error = candidate
        .generateTables()
        .firstOrNull
        ?.metadata['layoutError'];
    if (_draftManualWells.length != item.requiredWells(_wizard.plateCount) ||
        error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Choose every required well first.')),
      );
      return;
    }
    setState(() {
      _wizard = _asGeneratedLayout(candidate);
      _clearChooseWellsState();
    });
  }

  PlateLayoutWizard get _previewWizard {
    final index = _manualFitIndex;
    if (index == null || index >= _wizard.items.length) return _wizard;
    final active = _wizard.items[index].copyWith(
      manualWells: _draftManualWells,
    );
    final previewItems = <TestItem>[];
    if (_draftManualWells.isNotEmpty) previewItems.add(active);
    for (var itemIndex = 0; itemIndex < _wizard.items.length; itemIndex++) {
      if (itemIndex == index) continue;
      final item = _wizard.items[itemIndex];
      final wells = _lockedWellOwners.entries
          .where((entry) => entry.value == item.sampleName)
          .map((entry) {
            final parts = entry.key.split(':').map(int.parse).toList();
            return PlateWellPosition(
              plateIndex: parts[0],
              row: parts[1],
              column: parts[2],
            );
          })
          .toList();
      if (wells.isNotEmpty) previewItems.add(item.copyWith(manualWells: wells));
    }
    return _wizard.copyWith(items: previewItems, importedTables: const []);
  }

  void _toggleManualWell(PlateWellPosition position) {
    final index = _manualFitIndex;
    if (index == null || index >= _wizard.items.length) return;
    final lockedOwner = _lockedWellOwners[position.key];
    if (lockedOwner != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reserved by $lockedOwner. Choose another well.'),
        ),
      );
      return;
    }
    final item = _wizard.items[index];
    final wells = List<PlateWellPosition>.from(_draftManualWells);
    final selectedIndex = wells.indexWhere((well) => well.key == position.key);
    if (selectedIndex >= 0) {
      wells.removeAt(selectedIndex);
    } else {
      final required = item.requiredWells(_wizard.plateCount);
      if (wells.length >= required) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All $required required cells are assigned.')),
        );
        return;
      }
      wells.add(position);
    }
    setState(() {
      _manualSelectionHistory.add(List.of(_draftManualWells));
      _draftManualWells = wells;
    });
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesPopScope(
      canPop: _canActuallyPop,
      message:
          'You have unsaved changes in this table. Are you sure you want to exit?',
      child: Scaffold(
        appBar: ProtocolFlowAppBar(
          title: 'Sample Manager',
          actions: [
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _importTemplate,
              tooltip: 'Import filled template',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadTemplate,
              tooltip: 'Download import template',
            ),
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
              _buildPlateSettings(),
              const SizedBox(height: 24),
              Text('Test Items', style: Theme.of(context).textTheme.titleLarge),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('sample-cards-toggle-all'),
                  onPressed: _wizard.items.isEmpty ? null : _toggleAllCards,
                  icon: Icon(
                    _wizard.items.isNotEmpty &&
                            _wizard.items.every(
                              (item) => _collapsedItemIds.contains(item.id),
                            )
                        ? Icons.unfold_more
                        : Icons.unfold_less,
                  ),
                  label: Text(
                    _wizard.items.isNotEmpty &&
                            _wizard.items.every(
                              (item) => _collapsedItemIds.contains(item.id),
                            )
                        ? 'Expand all samples'
                        : 'Shrink all samples',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                key: const Key('sample-card-list'),
                primary: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _wizard.items.length,
                itemBuilder: (context, index) =>
                    _buildTestItemEditor(index, _wizard.items[index]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _addTestItem(isStandardCurve: true),
                        icon: const Icon(Icons.show_chart, color: Colors.amber),
                        label: const Text(
                          'Add Std Curve',
                          style: TextStyle(fontSize: _uniformFontSize),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade50,
                          foregroundColor: Colors.amber.shade900,
                        ),
                      ),
                      FilledButton.icon(
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
            ],
          ),
          independentWideScroll: true,
          widePreviewHeader: _buildPlacementControls(),
          narrowFooter: _buildPlacementControls(),
          preview: PlateResultPreview(
            wizard: _previewWizard,
            manualFitItem: _manualFitIndex == null
                ? null
                : _wizard.items[_manualFitIndex!].copyWith(
                    manualWells: _draftManualWells,
                  ),
            lockedWellOwners: _lockedWellOwners,
            onWellTap: _toggleManualWell,
          ),
        ),
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    await _longFormatService.downloadTemplate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plate import template downloaded')),
    );
  }

  Future<void> _importTemplate() async {
    final result = await _longFormatService.importTemplate();
    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    setState(() {
      _wizard = _wizard.copyWith(
        title: _wizard.title.isEmpty ? 'Imported Plate Layout' : _wizard.title,
        items: result.items,
        rows: result.rows ?? _wizard.rows,
        columns: result.columns ?? _wizard.columns,
        plateCount: result.plateCount ?? _wizard.plateCount,
        importedTables: result.tables,
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  PlateLayoutWizard _asGeneratedLayout(PlateLayoutWizard wizard) {
    return wizard.copyWith(importedTables: const []);
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

  Widget _buildPlacementControls() {
    final manualItem =
        _manualFitIndex == null || _manualFitIndex! >= _wizard.items.length
        ? null
        : _wizard.items[_manualFitIndex!];
    final required = manualItem?.requiredWells(_wizard.plateCount) ?? 0;
    final assigned = manualItem == null ? 0 : _draftManualWells.length;
    final remaining = (required - assigned).clamp(0, required);
    final candidate = manualItem == null
        ? _wizard
        : _wizard.copyWith(
            items: List<TestItem>.from(_wizard.items)
              ..[_manualFitIndex!] = manualItem.copyWith(
                manualWells: _draftManualWells,
              ),
          );
    final error = candidate
        .generateTables()
        .firstOrNull
        ?.metadata['layoutError'];
    final canApply =
        manualItem != null && assigned == required && error == null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('sample-auto-fit-all'),
                  onPressed: _autoFitAll,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Auto-fit all'),
                ),
                if (manualItem != null)
                  FilledButton.icon(
                    key: const Key('sample-choose-wells-apply'),
                    onPressed: canApply ? _applyChooseWells : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                  ),
                if (manualItem != null)
                  OutlinedButton.icon(
                    key: const Key('sample-choose-wells-undo'),
                    onPressed: _manualSelectionHistory.isEmpty
                        ? null
                        : _undoManualSelection,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
                if (manualItem != null)
                  OutlinedButton.icon(
                    key: const Key('sample-choose-wells-clear'),
                    onPressed: assigned == 0 ? null : _clearManualSelection,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                if (manualItem != null)
                  TextButton(
                    key: const Key('sample-choose-wells-cancel'),
                    onPressed: _cancelChooseWells,
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            if (manualItem != null) ...[
              const SizedBox(height: 10),
              Text(
                'Choose wells: ${manualItem.sampleName} — $required wells needed, '
                '$assigned selected, $remaining left. Locked wells belong to other samples.',
                key: const Key('manual-fit-status'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('sample-layout-error'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
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
    const directions = [
      Direction.auto,
      Direction.horizontal,
      Direction.vertical,
    ];
    return ToggleButtons(
      key: Key(
        'direction-${label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
      ),
      isSelected: directions.map((direction) => direction == current).toList(),
      onPressed: (index) => onChanged(directions[index]),
      constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
      borderRadius: BorderRadius.circular(18),
      borderColor: AppColors.primary,
      selectedBorderColor: AppColors.primary,
      selectedColor: AppColors.onPrimary,
      fillColor: AppColors.primary,
      color: AppColors.primary,
      textStyle: const TextStyle(fontSize: 11),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('Auto'),
        ),
        Tooltip(message: 'Across', child: Icon(Icons.arrow_forward, size: 18)),
        Tooltip(message: 'Down', child: Icon(Icons.arrow_downward, size: 18)),
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
                    decoration: const InputDecoration(labelText: 'Rows'),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _wizard = _asGeneratedLayout(
                        _wizard.copyWith(rows: int.tryParse(v) ?? 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DelayedTextField(
                    initialValue: _wizard.columns.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Columns'),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _wizard = _asGeneratedLayout(
                        _wizard.copyWith(columns: int.tryParse(v) ?? 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DelayedTextField(
                    initialValue: _wizard.plateCount.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Plate Count'),
                    style: const TextStyle(fontSize: _uniformFontSize),
                    onCommit: (v) => setState(
                      () => _wizard = _asGeneratedLayout(
                        _wizard.copyWith(plateCount: int.tryParse(v) ?? 1),
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
    final collapsed = _collapsedItemIds.contains(item.id);
    final itemColor = _colorFromHex(item.colorHex);
    return Card(
      key: Key('sample-card-${item.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      color: Color.alphaBlend(
        itemColor.withValues(alpha: 0.12),
        AppColors.surface,
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: item.isStandardCurve ? AppColors.warning : AppColors.outline,
          width: item.isStandardCurve ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
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
                      color: AppColors.warning,
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
                        activeThumbColor: AppColors.warning,
                        activeTrackColor: AppColors.warning.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            Row(
              children: [
                IconButton(
                  key: Key('sample-collapse-${item.id}'),
                  tooltip: collapsed ? 'Expand sample' : 'Shrink sample',
                  onPressed: () => setState(() {
                    if (collapsed) {
                      _collapsedItemIds.remove(item.id);
                    } else {
                      _collapsedItemIds.add(item.id);
                    }
                  }),
                  icon: Icon(
                    collapsed ? Icons.keyboard_arrow_down : Icons.expand_less,
                    size: 28,
                  ),
                ),
                Tooltip(
                  message: 'Choose sample color',
                  child: InkWell(
                    key: Key('sample-color-${item.id}'),
                    onTap: () => _chooseSampleColor(index, item),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: itemColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _DelayedTextField(
                    decoration: InputDecoration(
                      hintText: item.isStandardCurve
                          ? 'Curve name'
                          : 'Sample name',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    initialValue: item.sampleName,
                    style: const TextStyle(
                      fontSize: _uniformFontSize + 2,
                      fontWeight: FontWeight.w600,
                    ),
                    onCommit: (v) =>
                        _updateTestItem(index, item.copyWith(sampleName: v)),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete sample',
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _removeTestItem(index),
                ),
                PopupMenuButton<_SampleCardAction>(
                  key: Key('sample-menu-${item.id}'),
                  tooltip: 'Sample actions',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case _SampleCardAction.duplicate:
                        _duplicateTestItem(index);
                        break;
                      case _SampleCardAction.moveUp:
                        _moveTestItem(index, -1);
                        break;
                      case _SampleCardAction.moveDown:
                        _moveTestItem(index, 1);
                        break;
                      case _SampleCardAction.manualFit:
                        _startChooseWells(index);
                        break;
                      case _SampleCardAction.useAuto:
                        _updateTestItem(
                          index,
                          item.copyWith(manualWells: const []),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      key: Key('sample-duplicate-${item.id}'),
                      value: _SampleCardAction.duplicate,
                      child: const ListTile(
                        dense: true,
                        leading: Icon(Icons.copy_outlined),
                        title: Text('Duplicate'),
                      ),
                    ),
                    PopupMenuItem(
                      key: Key('sample-move-up-${item.id}'),
                      value: _SampleCardAction.moveUp,
                      enabled: index > 0,
                      child: const ListTile(
                        dense: true,
                        leading: Icon(Icons.arrow_upward),
                        title: Text('Move up'),
                      ),
                    ),
                    PopupMenuItem(
                      key: Key('sample-move-down-${item.id}'),
                      value: _SampleCardAction.moveDown,
                      enabled: index < _wizard.items.length - 1,
                      child: const ListTile(
                        dense: true,
                        leading: Icon(Icons.arrow_downward),
                        title: Text('Move down'),
                      ),
                    ),
                    PopupMenuItem(
                      key: Key('sample-manual-fit-${item.id}'),
                      value: _SampleCardAction.manualFit,
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.touch_app_outlined),
                        title: Text(
                          item.manualWells.isEmpty
                              ? 'Choose wells'
                              : 'Edit chosen wells (${item.manualWells.length})',
                        ),
                      ),
                    ),
                    if (item.manualWells.isNotEmpty)
                      const PopupMenuItem(
                        value: _SampleCardAction.useAuto,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.auto_fix_high),
                          title: Text('Use auto placement'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (!collapsed) ...[
              const SizedBox(height: 8),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Arrangement',
                      style: TextStyle(
                        fontSize: _uniformFontSize + 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildDirectionToggle(
                        'Layout ${item.id}',
                        item.sampleDirection,
                        (direction) => _updateTestItem(
                          index,
                          item.copyWith(sampleDirection: direction),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Auto chooses the best fit. Across → continues through columns; '
                  'Down ↓ continues through rows.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: _uniformFontSize - 2,
                  ),
                ),
              ),
              const Divider(),
              if (item.variables.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'No variables added',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              DragBoundary(
                child: ReorderableListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  dragBoundaryProvider: DragBoundary.forRectOf,
                  itemCount: item.variables.length,
                  itemBuilder: (context, variableIndex) =>
                      _buildVariableEditor(index, item, variableIndex),
                  onReorder: (oldIndex, newIndex) =>
                      _reorderVariable(index, item, oldIndex, newIndex),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('sample-add-variable-${item.id}'),
                  onPressed: () => _updateTestItem(
                    index,
                    item.copyWith(
                      variables: [
                        ...item.variables,
                        SampleVariable(
                          name: 'Variable ${item.variables.length + 1}',
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add variable'),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Replicates',
                      style: TextStyle(
                        fontSize: _uniformFontSize + 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildDirectionToggle(
                        'Replicates ${item.id}',
                        item.duplicateDirection,
                        (direction) => _updateTestItem(
                          index,
                          item.copyWith(duplicateDirection: direction),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: item.duplicates,
                decoration: const InputDecoration(
                  labelText: 'Number of replicates',
                  isDense: true,
                ),
                items: [1, 2, 3, 4, 5, 6, 8, 12]
                    .map(
                      (count) =>
                          DropdownMenuItem(value: count, child: Text('$count')),
                    )
                    .toList(),
                onChanged: (value) => _updateTestItem(
                  index,
                  item.copyWith(duplicates: value!, manualWells: const []),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVariableEditor(int itemIndex, TestItem item, int variableIndex) {
    final variable = item.variables[variableIndex];
    return Padding(
      key: Key('sample-variable-${item.id}-$variableIndex'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                key: Key('sample-variable-drag-${item.id}-$variableIndex'),
                index: variableIndex,
                child: const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.drag_handle,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: _DelayedTextField(
                  key: Key('sample-variable-name-${item.id}-$variableIndex'),
                  initialValue: variable.name,
                  decoration: const InputDecoration(
                    labelText: 'Variable name',
                    isDense: true,
                  ),
                  onCommit: (name) => _replaceVariable(
                    itemIndex,
                    item,
                    variableIndex,
                    variable.copyWith(name: name),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildDirectionToggle(
                'Variable ${item.id} $variableIndex',
                variable.direction,
                (direction) => _replaceVariable(
                  itemIndex,
                  item,
                  variableIndex,
                  variable.copyWith(direction: direction),
                ),
              ),
              IconButton(
                tooltip: 'Remove variable',
                onPressed: () {
                  final variables = List<SampleVariable>.from(item.variables)
                    ..removeAt(variableIndex);
                  _updateTestItem(
                    itemIndex,
                    item.copyWith(variables: variables, manualWells: const []),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildListField(
            'Values',
            variable.values,
            (values) => _replaceVariable(
              itemIndex,
              item,
              variableIndex,
              variable.copyWith(values: values),
            ),
          ),
          const SizedBox(height: 2),
          const Divider(),
        ],
      ),
    );
  }

  void _reorderVariable(
    int itemIndex,
    TestItem item,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final variables = List<SampleVariable>.from(item.variables);
    final variable = variables.removeAt(oldIndex);
    variables.insert(newIndex, variable);
    _updateTestItem(
      itemIndex,
      item.copyWith(variables: variables, manualWells: const []),
    );
  }

  void _replaceVariable(
    int itemIndex,
    TestItem item,
    int variableIndex,
    SampleVariable variable,
  ) {
    final variables = List<SampleVariable>.from(item.variables);
    variables[variableIndex] = variable;
    _updateTestItem(
      itemIndex,
      item.copyWith(variables: variables, manualWells: const []),
    );
  }

  Future<void> _chooseSampleColor(int index, TestItem item) async {
    const colors = [
      '#FFCDD2',
      '#F8BBD0',
      '#E1BEE7',
      '#C5CAE9',
      '#BBDEFB',
      '#B2EBF2',
      '#B2DFDB',
      '#C8E6C9',
      '#DCEDC8',
      '#FFF9C4',
      '#FFE0B2',
      '#D7CCC8',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose sample color'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((hex) {
            final selected = hex == item.colorHex;
            return InkWell(
              key: Key('sample-color-option-$hex'),
              onTap: () => Navigator.pop(dialogContext, hex),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _colorFromHex(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.outline,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected ? const Icon(Icons.check, size: 20) : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
    if (selected != null && mounted) {
      _updateTestItem(index, item.copyWith(colorHex: selected));
    }
  }

  Color _colorFromHex(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFE3F2FD);
    }
  }

  String _sampleColorForIndex(int index) {
    const colors = [
      '#BBDEFB',
      '#C8E6C9',
      '#FFE0B2',
      '#E1BEE7',
      '#B2EBF2',
      '#FFF9C4',
      '#F8BBD0',
      '#D7CCC8',
    ];
    return colors[index % colors.length];
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
                color: AppColors.primary,
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
    super.key,
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
