import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/protocol_table.dart';
import '../models/plate_wizard.dart';
import '../models/master_mix_wizard.dart';
import 'plate_wizard_samples_screen.dart';
import '../features/staining_table/models/staining_wizard.dart';
import '../widgets/horizontal_table_scroll.dart';

class TableDataEditorScreen extends StatefulWidget {
  final List<ProtocolTable> tables;
  final Function(List<ProtocolTable>) onSave;

  const TableDataEditorScreen({
    super.key,
    required this.tables,
    required this.onSave,
  });

  @override
  State<TableDataEditorScreen> createState() => _TableDataEditorScreenState();
}

class _TableDataEditorScreenState extends State<TableDataEditorScreen> {
  late List<ProtocolTable> _allTables;
  int _currentTableIndex = 0;

  late List<List<dynamic>> _data;
  late List<List<String>> _cellColors;
  late List<String> _colHeaders;
  late List<String> _rowHeaders;
  late String _title;
  late TableType _type;
  bool _isGridView = false;
  bool _genericGridGenerated = true;
  int _genericTotalRows = 6;
  int _genericColumns = 4;

  late PlateLayoutWizard _plateWizard;
  late MasterMixWizard _masterMixWizard;
  late StainingWizard _stainingWizard;

  final TransformationController _transformationController =
      TransformationController();

  bool get _isEditableGridType =>
      _type == TableType.generic || _type == TableType.materialList;

  @override
  void initState() {
    super.initState();
    _allTables = widget.tables.map((t) => t.copyWith()).toList();
    if (_allTables.isEmpty) {
      _allTables = [
        ProtocolTable(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          title: 'New Table',
        ),
      ];
    }

    _loadTable(_currentTableIndex);
  }

  void _loadTable(int index) {
    final table = _allTables[index];
    final needsDimensionSetup =
        table.type == TableType.generic &&
        table.metadata['needs_dimension_setup'] == 'true';
    _data = table.data
        .map<List<dynamic>>((row) => List<dynamic>.from(row))
        .toList();
    final columnCount = _resolvedColumnCount(table);
    if (_data.isEmpty && !needsDimensionSetup) {
      _data = List.generate(1, (_) => List.generate(columnCount, (_) => ''));
    } else {
      _data = _data.map((row) {
        return List<dynamic>.generate(
          columnCount,
          (index) => index < row.length ? row[index] : '',
        );
      }).toList();
    }
    _cellColors = table.cellColors
        .map<List<String>>((row) => List<String>.from(row))
        .toList();
    _cellColors = List.generate(_data.length, (rowIndex) {
      final colors = rowIndex < _cellColors.length
          ? _cellColors[rowIndex]
          : const <String>[];
      return List<String>.generate(
        columnCount,
        (index) => index < colors.length ? colors[index] : '',
      );
    });

    _colHeaders = List<String>.generate(
      columnCount,
      (index) => index < table.columnHeaders.length
          ? table.columnHeaders[index]
          : _columnName(index),
    );
    _rowHeaders = List<String>.generate(
      _data.length,
      (index) => index < table.rowHeaders.length
          ? table.rowHeaders[index]
          : '${index + 1}',
    );
    _title = table.title;
    _type = table.type;
    if (_isEditableGridType) {
      _genericGridGenerated =
          !needsDimensionSetup ||
          table.data.isNotEmpty ||
          table.columnHeaders.isNotEmpty;
      _genericTotalRows =
          int.tryParse(table.metadata['generic_total_rows'] ?? '') ??
          (needsDimensionSetup ? 6 : (_data.isNotEmpty ? _data.length + 1 : 6));
      _genericColumns =
          int.tryParse(table.metadata['generic_columns'] ?? '') ??
          (needsDimensionSetup
              ? 4
              : (_colHeaders.isNotEmpty ? _colHeaders.length : 4));
    }

    // Initialize Wizards from metadata if available
    if (_type == TableType.plateLayout) {
      _isGridView = true;
      if (table.metadata.containsKey('wizard_state')) {
        try {
          _plateWizard = PlateLayoutWizard.fromJson(
            jsonDecode(table.metadata['wizard_state']!),
          );
        } catch (e) {
          _initDefaultPlateWizard();
        }
      } else {
        _initDefaultPlateWizard();
      }
    } else if (_type == TableType.masterMix) {
      _isGridView = false;
      if (table.metadata.containsKey('wizard_state')) {
        try {
          _masterMixWizard = MasterMixWizard.fromJson(
            jsonDecode(table.metadata['wizard_state']!),
          );
        } catch (e) {
          _initDefaultMasterMixWizard();
        }
      } else {
        _initDefaultMasterMixWizard();
      }
    } else if (_type == TableType.staining) {
      _isGridView = false;
      if (table.metadata.containsKey('wizard_state')) {
        try {
          _stainingWizard = StainingWizard.fromJson(
            jsonDecode(table.metadata['wizard_state']!),
          );
        } catch (e) {
          _initDefaultStainingWizard();
        }
      } else {
        _initDefaultStainingWizard();
      }
    } else {
      _isGridView = false;
    }
  }

  void _initDefaultPlateWizard() {
    _plateWizard = PlateLayoutWizard(
      rows: _rowHeaders.isNotEmpty ? _rowHeaders.length : 8,
      columns: _colHeaders.isNotEmpty ? _colHeaders.length : 12,
      items: [TestItem(sampleName: 'Sample 1')],
    );
  }

  void _initDefaultMasterMixWizard() {
    _masterMixWizard = MasterMixWizard(
      reagents: [MasterMixReagentItem(name: 'Reagent 1')],
    );
  }

  void _initDefaultStainingWizard() {
    _stainingWizard = StainingWizard(samples: []);
  }

  int _resolvedColumnCount(ProtocolTable table) {
    final maxDataColumns = table.data.fold<int>(
      table.columnHeaders.length,
      (max, row) => row.length > max ? row.length : max,
    );
    return maxDataColumns > 0 ? maxDataColumns : 1;
  }

  void _saveCurrentTable() {
    _allTables[_currentTableIndex] = _allTables[_currentTableIndex].copyWith(
      title: _title,
      type: _type,
      data: _data,
      cellColors: _cellColors,
      columnHeaders: _colHeaders,
      rowHeaders: _rowHeaders,
      metadata: {
        ..._allTables[_currentTableIndex].metadata,
        if (_type == TableType.plateLayout)
          'wizard_state': jsonEncode(_plateWizard.toJson()),
        if (_type == TableType.masterMix)
          'wizard_state': jsonEncode(_masterMixWizard.toJson()),
        if (_type == TableType.staining)
          'wizard_state': jsonEncode(_stainingWizard.toJson()),
        if (_isEditableGridType) ...{
          'needs_dimension_setup': 'false',
          'generic_total_rows': (_data.length + 1).toString(),
          'generic_columns': _colHeaders.length.toString(),
          'generic_grid_generated': 'true',
        },
      },
    );
  }

  void _regenerateTable() {
    _saveCurrentTable();
    List<ProtocolTable> updatedTables = [];

    if (_type == TableType.plateLayout) {
      updatedTables = _plateWizard.generateTables();
    } else if (_type == TableType.masterMix) {
      updatedTables = [_masterMixWizard.generateTable()];
    } else if (_type == TableType.staining) {
      updatedTables = [_stainingWizard.generateTable()];
    }

    if (updatedTables.isNotEmpty) {
      setState(() {
        _allTables = updatedTables;
        _currentTableIndex = 0;
        _loadTable(0);
      });
    }
  }

  void _switchTable(int newIndex) {
    _saveCurrentTable();
    setState(() {
      _currentTableIndex = newIndex;
      _loadTable(_currentTableIndex);
      _resetView();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _data.add(List.generate(_colHeaders.length, (_) => ''));
      _cellColors.add(List.generate(_colHeaders.length, (_) => ''));
      _rowHeaders.add(
        _isEditableGridType
            ? (_rowHeaders.length + 2).toString()
            : (_rowHeaders.length + 1).toString(),
      );
      if (_isEditableGridType) _genericTotalRows = _data.length + 1;
    });
  }

  void _removeRow(int index) {
    if (_rowHeaders.length > 1) {
      setState(() {
        _data.removeAt(index);
        _cellColors.removeAt(index);
        _rowHeaders.removeAt(index);
        // Renumber rows if they are just numbers
        for (int i = 0; i < _rowHeaders.length; i++) {
          if (int.tryParse(_rowHeaders[i]) != null) {
            _rowHeaders[i] = _isEditableGridType
                ? (i + 2).toString()
                : (i + 1).toString();
          }
        }
        if (_isEditableGridType) _genericTotalRows = _data.length + 1;
      });
    }
  }

  void _addColumn() {
    setState(() {
      for (var row in _data) {
        row.add('');
      }
      for (var row in _cellColors) {
        row.add('');
      }
      _colHeaders.add(_columnName(_colHeaders.length));
      if (_isEditableGridType) _genericColumns = _colHeaders.length;
    });
  }

  String _columnName(int index) {
    var value = index + 1;
    final chars = <String>[];
    while (value > 0) {
      value--;
      chars.insert(0, String.fromCharCode(65 + (value % 26)));
      value ~/= 26;
    }
    return chars.join();
  }

  void _resetView() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  Color _parseHexColor(String hex) {
    if (hex.isEmpty) return Colors.transparent;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canActuallyPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog();
        if (shouldPop ?? false) {
          if (context.mounted) {
            setState(() => _canActuallyPop = true);
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _type == TableType.materialList
                ? 'Material List Editor'
                : _type == TableType.generic
                ? 'Generic Table Editor'
                : 'Edit Table',
          ),
          actions: [
            IconButton(
              tooltip: 'Save table',
              onPressed: () => _handleDone(context),
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_type == TableType.plateLayout) _buildPlateWizardHeader(),
            if (_allTables.length > 1) _buildTableNavigation(),
            const Divider(height: 1),
            Expanded(
              child: _isEditableGridType
                  ? (_genericGridGenerated
                        ? _buildGenericGrid()
                        : _buildGenericSetupCard())
                  : (_isGridView ? _buildZoomableGrid() : _buildSpreadsheet()),
            ),
          ],
        ),
        floatingActionButton: _type == TableType.plateLayout
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlateWizardSamplesScreen(
                        wizard: _plateWizard,
                        onUpdate: (updatedWizard) {
                          setState(() {
                            _plateWizard = updatedWizard;
                          });
                          _regenerateTable();
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.science_rounded),
                label: const Text('Manage Samples'),
              )
            : null,
      ),
    );
  }

  Widget _buildTableNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentTableIndex > 0
                ? () => _switchTable(_currentTableIndex - 1)
                : null,
          ),
          Text(
            'Table ${_currentTableIndex + 1} of ${_allTables.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentTableIndex < _allTables.length - 1
                ? () => _switchTable(_currentTableIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPlateWizardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: const Text(
        'Plate Layout Preview (Zoomable)',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildSpreadsheet() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: HorizontalTableScroll(
        minWidth: 640,
        child: InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(1000),
          minScale: 0.1,
          maxScale: 3,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 50,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 100,
            columns: [
              const DataColumn(
                label: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ..._colHeaders.map(
                (h) => DataColumn(
                  label: Text(
                    h,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            rows: List<DataRow>.generate(_data.length, (rIdx) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      _rowHeaders[rIdx],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._data[rIdx].asMap().entries.map((entry) {
                    final cIdx = entry.key;
                    final value = entry.value;
                    final colorStr = _cellColors[rIdx][cIdx];

                    return DataCell(
                      Container(
                        constraints: const BoxConstraints(minWidth: 60),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: _parseHexColor(colorStr),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          value.toString().isEmpty ? '...' : value.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomableGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: HorizontalTableScroll(
        minWidth: 640,
        child: InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(1000),
          minScale: 0.1,
          maxScale: 5.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 40),
                  ..._colHeaders.map(
                    (h) => SizedBox(
                      width: 69,
                      child: Center(
                        child: Text(
                          h,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ...List<Widget>.generate(_data.length, (rIdx) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        _rowHeaders[rIdx],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    ...List<Widget>.generate(_data[rIdx].length, (cIdx) {
                      final val = _data[rIdx][cIdx].toString();
                      final colorStr = _cellColors[rIdx][cIdx];
                      return Container(
                        width: 65,
                        height: 65,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorStr.isEmpty
                              ? Colors.grey.shade200
                              : _parseHexColor(colorStr),
                          border: Border.all(color: Colors.blue.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              val,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  bool _canActuallyPop = false;

  Future<bool?> _showExitConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes in this table. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _handleDone(BuildContext context) async {
    if (_isEditableGridType && !_genericGridGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate the table grid before saving.')),
      );
      return;
    }

    final String suggestedName = _isEditableGridType
        ? (_title.isEmpty ? 'Generic Table' : _title)
        : _title;
    final String? name = await _showSaveDialog(context, suggestedName);
    if (name != null) {
      setState(() {
        _title = name;
      });
      _saveCurrentTable();
      widget.onSave(_allTables);
      if (context.mounted) {
        setState(() => _canActuallyPop = true);
        Navigator.pop(context, _allTables);
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

  Widget _buildGenericSetupCard() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Generic table size',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStepperRow(
                    label: 'Rows',
                    value: _genericTotalRows,
                    min: 1,
                    onChanged: (value) =>
                        setState(() => _genericTotalRows = value),
                  ),
                  const SizedBox(height: 12),
                  _buildStepperRow(
                    label: 'Columns',
                    value: _genericColumns,
                    min: 1,
                    onChanged: (value) =>
                        setState(() => _genericColumns = value),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _generateGenericGrid,
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Generate table'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepperRow({
    required String label,
    required int value,
    required int min,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton.outlined(
          tooltip: 'Decrease $label',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 56,
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton.outlined(
          tooltip: 'Increase $label',
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  void _generateGenericGrid() {
    final dataRows = (_genericTotalRows - 1).clamp(0, 10000).toInt();
    setState(() {
      _colHeaders = List.generate(_genericColumns, (_) => '');
      _data = List.generate(
        dataRows,
        (_) => List.generate(_genericColumns, (_) => ''),
      );
      _cellColors = List.generate(
        dataRows,
        (_) => List.generate(_genericColumns, (_) => ''),
      );
      _rowHeaders = List.generate(dataRows, (index) => '${index + 2}');
      _genericGridGenerated = true;
    });
  }

  Widget _buildGenericGrid() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: HorizontalTableScroll(
          minWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  ...List.generate(
                    _colHeaders.length,
                    (index) => Container(
                      width: 150,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: _ExcelCell(
                        initialValue: _colHeaders[index],
                        hintText: 'Header ${_columnName(index)}',
                        onChanged: (value) => _colHeaders[index] = value,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    onPressed: _addColumn,
                  ),
                ],
              ),
              ...List.generate(
                _data.length,
                (rIdx) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Center(
                        child: Text(
                          _rowHeaders[rIdx],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    ...List.generate(
                      _colHeaders.length,
                      (cIdx) => Container(
                        width: 150,
                        height: 56,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          color: _parseHexColor(_cellColors[rIdx][cIdx]),
                        ),
                        child: _ExcelCell(
                          initialValue: _data[rIdx][cIdx].toString(),
                          onChanged: (v) => _data[rIdx][cIdx] = v,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _removeRow(rIdx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  onPressed: _addRow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExcelCell extends StatefulWidget {
  final String initialValue;
  final String? hintText;
  final Function(String) onChanged;

  const _ExcelCell({
    required this.initialValue,
    required this.onChanged,
    this.hintText,
  });

  @override
  State<_ExcelCell> createState() => _ExcelCellState();
}

class _ExcelCellState extends State<_ExcelCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onChanged(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(_ExcelCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: 2,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: widget.hintText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        isDense: true,
      ),
      onChanged: (v) => widget.onChanged(v),
      onSubmitted: (v) => widget.onChanged(v),
    );
  }
}
