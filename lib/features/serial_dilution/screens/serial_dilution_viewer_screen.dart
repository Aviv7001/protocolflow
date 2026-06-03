import 'package:flutter/material.dart';

import '../../../models/protocol_table.dart';
import '../models/serial_dilution_input.dart';
import '../services/serial_dilution_calculator_service.dart';
import '../widgets/serial_dilution_result_table.dart';
import 'serial_dilution_manager_screen.dart';

class SerialDilutionViewerScreen extends StatefulWidget {
  final SerialDilutionInput input;
  final bool isReadOnly;
  final Function(ProtocolTable) onUpdate;

  const SerialDilutionViewerScreen({
    super.key,
    required this.input,
    this.isReadOnly = false,
    required this.onUpdate,
  });

  @override
  State<SerialDilutionViewerScreen> createState() =>
      _SerialDilutionViewerScreenState();
}

class _SerialDilutionViewerScreenState
    extends State<SerialDilutionViewerScreen> {
  late SerialDilutionInput _input;
  final _calculator = SerialDilutionCalculatorService();

  @override
  void initState() {
    super.initState();
    _input = widget.input;
  }

  void _editTable() async {
    final updatedInput = await Navigator.push<SerialDilutionInput>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SerialDilutionManagerScreen(input: _input, onUpdate: (updated) {}),
      ),
    );

    if (updatedInput != null) {
      setState(() => _input = updatedInput);
      widget.onUpdate(_input.generateTable());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_input.title.isEmpty ? 'Serial Dilution' : _input.title),
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
        child: SerialDilutionResultTable(
          input: _input,
          calculator: _calculator,
        ),
      ),
    );
  }
}
