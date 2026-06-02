import 'package:flutter/material.dart';
import '../widgets/staining_result_table.dart';
import '../services/staining_table_generator_service.dart';
import '../models/staining_wizard.dart';
import 'staining_table_manager_screen.dart';
import '../../../models/protocol_table.dart';

class StainingTableViewerScreen extends StatefulWidget {
  final StainingWizard wizard;
  final bool isReadOnly;
  final Function(ProtocolTable) onUpdate;

  const StainingTableViewerScreen({
    super.key,
    required this.wizard,
    this.isReadOnly = false,
    required this.onUpdate,
  });

  @override
  State<StainingTableViewerScreen> createState() => _StainingTableViewerScreenState();
}

class _StainingTableViewerScreenState extends State<StainingTableViewerScreen> {
  late StainingWizard _wizard;
  final StainingTableGeneratorService _generator = StainingTableGeneratorService();

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
  }

  void _editTable() async {
    final updatedWizard = await Navigator.push<StainingWizard>(
      context,
      MaterialPageRoute(
        builder: (context) => StainingTableManagerScreen(
          wizard: _wizard,
          onUpdate: (updated) {
            // Updated in manager
          },
        ),
      ),
    );

    if (updatedWizard != null) {
      setState(() {
        _wizard = updatedWizard;
      });
      widget.onUpdate(_wizard.generateTable());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_wizard.title.isEmpty ? 'Staining Table' : _wizard.title),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StainingResultTable(
              wizard: _wizard,
              generator: _generator,
            ),
          ],
        ),
      ),
    );
  }
}
