import 'package:flutter/material.dart';
import '../widgets/master_mix_result_table.dart';
import '../services/master_mix_calculator_service.dart';
import '../../../models/master_mix_wizard.dart';
import 'master_mix_manager_screen.dart';
import '../../../models/protocol_table.dart';

class MasterMixViewerScreen extends StatefulWidget {
  final MasterMixWizard wizard;
  final bool isReadOnly;
  final Function(ProtocolTable) onUpdate;

  const MasterMixViewerScreen({
    super.key,
    required this.wizard,
    this.isReadOnly = false,
    required this.onUpdate,
  });

  @override
  State<MasterMixViewerScreen> createState() => _MasterMixViewerScreenState();
}

class _MasterMixViewerScreenState extends State<MasterMixViewerScreen> {
  late MasterMixWizard _wizard;
  final MasterMixCalculatorService _calculator = MasterMixCalculatorService();

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
  }

  void _editTable() async {
    final updatedWizard = await Navigator.push<MasterMixWizard>(
      context,
      MaterialPageRoute(
        builder: (context) => MasterMixManagerScreen(
          wizard: _wizard,
          onUpdate: (updated) {
            // This onUpdate is called when saving in manager
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
        title: Text(_wizard.mixName),
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
        child: MasterMixResultTable(
          wizard: _wizard,
          calculator: _calculator,
        ),
      ),
    );
  }
}
