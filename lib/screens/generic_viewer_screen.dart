import 'package:flutter/material.dart';
import '../widgets/generic_result_table.dart';
import '../models/protocol_table.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_table.title.isEmpty ? 'Table Viewer' : _table.title),
        actions: [
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editTable,
              tooltip: 'Edit Table',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: GenericResultTable(
          table: _table,
        ),
      ),
    );
  }
}
