import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/protocol_table.dart';
import '../models/master_mix_wizard.dart';
import '../features/staining_table/models/staining_wizard.dart';
import '../models/reagent_mix_wizard.dart';
import '../models/plate_wizard.dart';
import '../features/master_mix/screens/master_mix_viewer_screen.dart';
import '../features/serial_dilution/models/serial_dilution_input.dart';
import '../features/serial_dilution/screens/serial_dilution_viewer_screen.dart';
import '../features/staining_table/screens/staining_table_viewer_screen.dart';
import '../features/reagent_mix/screens/reagent_viewer_screen.dart';
import '../features/plate_wizard/screens/plate_viewer_screen.dart';
import '../screens/generic_viewer_screen.dart';

class ProtocolTableWidget extends StatelessWidget {
  final ProtocolTable table;
  final bool isReadOnly;
  final Function(ProtocolTable)? onSave;

  const ProtocolTableWidget({
    super.key,
    required this.table,
    this.isReadOnly = true,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _openTableEditor(context),
            borderRadius: BorderRadius.circular(12),

            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Icon(
                _getTypeIcon(table.type),
                size: 40,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 100,
            child: Text(
              table.title.isEmpty ? 'Untitled Table' : table.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _openTableEditor(BuildContext context) {
    final wizardState = table.metadata['wizard_state'];

    if (table.type == TableType.masterMix) {
      final wizard = wizardState != null
          ? MasterMixWizard.fromJson(jsonDecode(wizardState))
          : MasterMixWizard();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MasterMixViewerScreen(
            wizard: wizard,
            isReadOnly: isReadOnly,
            onUpdate: (updated) {
              if (onSave != null) {
                onSave!(updated.copyWith(id: table.id));
              }
            },
          ),
        ),
      );
    } else if (table.type == TableType.staining) {
      final wizard = wizardState != null
          ? StainingWizard.fromJson(jsonDecode(wizardState))
          : StainingWizard();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StainingTableViewerScreen(
            wizard: wizard,
            isReadOnly: isReadOnly,
            onUpdate: (updated) {
              if (onSave != null) {
                onSave!(updated.copyWith(id: table.id));
              }
            },
          ),
        ),
      );
    } else if (table.type == TableType.reagentMix) {
      final wizard = wizardState != null
          ? ReagentMixWizard.fromJson(jsonDecode(wizardState))
          : ReagentMixWizard();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReagentViewerScreen(
            wizard: wizard,
            isReadOnly: isReadOnly,
            onUpdate: (updated) {
              if (onSave != null) {
                onSave!(updated.copyWith(id: table.id));
              }
            },
          ),
        ),
      );
    } else if (table.type == TableType.serialDilution) {
      final input = wizardState != null
          ? SerialDilutionInput.fromJson(jsonDecode(wizardState))
          : SerialDilutionInput();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SerialDilutionViewerScreen(
            input: input,
            isReadOnly: isReadOnly,
            onUpdate: (updated) {
              if (onSave != null) {
                onSave!(updated.copyWith(id: table.id));
              }
            },
          ),
        ),
      );
    } else if (table.type == TableType.plateLayout) {
      final wizard = wizardState != null
          ? PlateLayoutWizard.fromJson(jsonDecode(wizardState))
          : PlateLayoutWizard();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlateViewerScreen(
            wizard: wizard,
            plateId: table.id,
            originalMetadata: table.metadata,
            isReadOnly: isReadOnly,
            onUpdate: (updated) {
              if (onSave != null) {
                onSave!(updated);
              }
            },
          ),
        ),
      );
    } else {
      // Fallback to generic viewer for TableType.generic and others
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GenericViewerScreen(
            table: table,
            isReadOnly: isReadOnly,
            onUpdate: (updated) {
              if (onSave != null) {
                onSave!(updated.copyWith(id: table.id));
              }
            },
          ),
        ),
      );
    }
  }

  IconData _getTypeIcon(TableType type) {
    switch (type) {
      case TableType.plateLayout:
        return Icons.grid_on;
      case TableType.reagentMatrix:
        return Icons.biotech;
      case TableType.masterMix:
        return Icons.calculate;
      case TableType.checklist:
        return Icons.fact_check;
      case TableType.staining:
        return Icons.color_lens;
      case TableType.reagentMix:
        return Icons.science;
      case TableType.serialDilution:
        return Icons.water_drop;
      default:
        return Icons.table_chart;
    }
  }
}
