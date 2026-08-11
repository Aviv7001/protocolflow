import 'package:flutter/material.dart';
import '../widgets/generic_result_table.dart';
import '../models/protocol_table.dart';
import '../widgets/save_table_action.dart';
import '../widgets/table_workspace.dart';
import 'table_data_editor_screen.dart';

class GenericViewerScreen extends StatefulWidget {
  final ProtocolTable table;
  final bool isReadOnly;
  final Function(ProtocolTable) onUpdate;

  const GenericViewerScreen({
    super.key,
    required this.table,
    this.isReadOnly = false,
    required this.onUpdate,
  });

  @override
  State<GenericViewerScreen> createState() => _GenericViewerScreenState();
}

class _GenericViewerScreenState extends State<GenericViewerScreen> {
  late ProtocolTable _table;

  @override
  void initState() {
    super.initState();
    _table = widget.table;
  }

  void _editTable() async {
    final updatedTables = await Navigator.push<List<ProtocolTable>>(
      context,
      MaterialPageRoute(
        builder: (context) => TableDataEditorScreen(
          tables: [_table],
          onSave: (updated) {
            // Updated in manager
          },
        ),
      ),
    );

    if (updatedTables != null && updatedTables.isNotEmpty) {
      setState(() {
        _table = updatedTables.first;
      });
      widget.onUpdate(_table);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMaterialList = _table.type == TableType.materialList;
    return TableViewerScaffold(
      title: _table.title.isEmpty ? 'Table Viewer' : _table.title,
      typeLabel: isMaterialList ? 'Material list' : 'Generic table',
      typeIcon: isMaterialList
          ? Icons.inventory_2_outlined
          : Icons.table_chart_outlined,
      actions: [
        SaveTableAction(table: _table),
        if (!widget.isReadOnly)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTable,
            tooltip: 'Edit Table',
          ),
      ],
      table: GenericResultTable(table: _table),
    );
  }
}
