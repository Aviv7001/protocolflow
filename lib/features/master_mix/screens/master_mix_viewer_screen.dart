import 'package:flutter/material.dart';
import '../widgets/master_mix_result_table.dart';
import '../services/master_mix_calculator_service.dart';
import '../../../models/master_mix_wizard.dart';
import 'master_mix_manager_screen.dart';
import '../../../models/protocol_table.dart';
import '../../../widgets/save_table_action.dart';
import '../../../widgets/table_workspace.dart';

class MasterMixViewerScreen extends StatefulWidget {
  final MasterMixWizard wizard;
  final ProtocolTable initialTable;
  final bool isReadOnly;
  final Function(ProtocolTable) onUpdate;

  const MasterMixViewerScreen({
    super.key,
    required this.wizard,
    required this.initialTable,
    this.isReadOnly = false,
    required this.onUpdate,
  });

  @override
  State<MasterMixViewerScreen> createState() => _MasterMixViewerScreenState();
}

class _MasterMixViewerScreenState extends State<MasterMixViewerScreen> {
  late MasterMixWizard _wizard;
  late ProtocolTable _table;
  final MasterMixCalculatorService _calculator = MasterMixCalculatorService();

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
    _table = widget.initialTable;
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
      final updatedTable = updatedWizard.generateTable().copyWith(
        id: _table.id,
      );
      setState(() {
        _wizard = updatedWizard;
        _table = updatedTable;
      });
      widget.onUpdate(updatedTable);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TableViewerScaffold(
      title: _wizard.tableName.isEmpty ? 'Master Mix' : _wizard.tableName,
      typeLabel: 'Master mix',
      typeIcon: Icons.biotech_outlined,
      actions: [
        SaveTableAction(table: _table),
        if (!widget.isReadOnly)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTable,
            tooltip: 'Edit Table',
          ),
      ],
      table: MasterMixResultTable(
        wizard: _wizard,
        calculator: _calculator,
        tableOverride: _table,
      ),
    );
  }
}
