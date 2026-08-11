import 'package:flutter/material.dart';
import '../widgets/plate_result_preview.dart';
import '../../../models/plate_wizard.dart';
import '../../../screens/plate_wizard_samples_screen.dart';
import '../../../models/protocol_table.dart';
import '../../../widgets/save_table_action.dart';
import '../../../widgets/table_workspace.dart';

class PlateViewerScreen extends StatefulWidget {
  final PlateLayoutWizard wizard;
  final String? plateId;
  final Map<String, String> originalMetadata;
  final bool isReadOnly;
  final Function(ProtocolTable) onUpdate;

  const PlateViewerScreen({
    super.key,
    required this.wizard,
    this.plateId,
    this.originalMetadata = const {},
    this.isReadOnly = false,
    required this.onUpdate,
  });

  @override
  State<PlateViewerScreen> createState() => _PlateViewerScreenState();
}

class _PlateViewerScreenState extends State<PlateViewerScreen> {
  late PlateLayoutWizard _wizard;

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
  }

  void _editTable() async {
    final updatedWizard = await Navigator.push<PlateLayoutWizard>(
      context,
      MaterialPageRoute(
        builder: (context) => PlateWizardSamplesScreen(
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
      // Return the consolidated table representing the entire configuration
      widget.onUpdate(_wizard.toProtocolTable().copyWith(id: widget.plateId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TableViewerScaffold(
      title: _wizard.title.isEmpty ? 'Plate Layout' : _wizard.title,
      typeLabel: 'Plate layout',
      typeIcon: Icons.grid_on_outlined,
      actions: [
        SaveTableAction(
          table: _wizard.toProtocolTable().copyWith(id: widget.plateId),
        ),
        if (!widget.isReadOnly)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTable,
            tooltip: 'Edit Table',
          ),
      ],
      table: PlateResultPreview(wizard: _wizard),
    );
  }
}
