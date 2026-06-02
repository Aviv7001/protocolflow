import 'package:flutter/material.dart';
import '../widgets/reagent_result_table.dart';
import '../../../models/reagent_mix_wizard.dart';
import '../../../screens/reagent_manager_screen.dart';
import '../../../models/protocol_table.dart';

class ReagentViewerScreen extends StatefulWidget {
  final ReagentMixWizard wizard;
  final bool isReadOnly;
  final Function(ProtocolTable) onUpdate;

  const ReagentViewerScreen({
    super.key,
    required this.wizard,
    this.isReadOnly = false,
    required this.onUpdate,
  });

  @override
  State<ReagentViewerScreen> createState() => _ReagentViewerScreenState();
}

class _ReagentViewerScreenState extends State<ReagentViewerScreen> {
  late ReagentMixWizard _wizard;

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
  }

  void _editTable() async {
    final updatedWizard = await Navigator.push<ReagentMixWizard>(
      context,
      MaterialPageRoute(
        builder: (context) => ReagentManagerScreen(
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
        title: Text(_wizard.title.isEmpty ? 'Reagent Mix' : _wizard.title),
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
        child: ReagentResultTable(
          wizard: _wizard,
        ),
      ),
    );
  }
}
