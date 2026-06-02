import 'package:flutter/material.dart';
import '../models/protocol_table.dart';
import '../models/master_mix_wizard.dart';
import '../features/staining_table/models/staining_wizard.dart';
import '../models/reagent_mix_wizard.dart';
import '../models/plate_wizard.dart';
import '../features/master_mix/screens/master_mix_manager_screen.dart';
import '../features/staining_table/screens/staining_table_manager_screen.dart';
import 'reagent_manager_screen.dart';
import 'plate_wizard_samples_screen.dart';
import 'table_data_editor_screen.dart';

class TableSelectionScreen extends StatelessWidget {
  const TableSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Table'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Table Type',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a specialized manager to create your table',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  _buildTypeCard(
                    context,
                    'Master Mix',
                    'Calculator',
                    Icons.biotech,
                    Colors.blue,
                    onTap: () => _openMasterMix(context),
                  ),
                  _buildTypeCard(
                    context,
                    'Staining',
                    'Panel Generator',
                    Icons.color_lens,
                    Colors.indigo,
                    onTap: () => _openStaining(context),
                  ),
                  _buildTypeCard(
                    context,
                    'Reagent Mix',
                    'Dilution Manager',
                    Icons.science,
                    Colors.teal,
                    onTap: () => _openReagentMix(context),
                  ),
                  _buildTypeCard(
                    context,
                    'Plate Layout',
                    'Well Designer',
                    Icons.grid_on,
                    Colors.orange,
                    onTap: () => _openPlateLayout(context),
                  ),
                  _buildTypeCard(
                    context,
                    'Generic Table',
                    'Custom Grid',
                    Icons.table_chart,
                    Colors.grey,
                    onTap: () => _openGenericTable(context),
                  ),
                  _buildTypeCard(
                    context,
                    'Import Table',
                    'From CSV/Excel',
                    Icons.file_upload,
                    Colors.purple,
                    isAvailable: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    bool isAvailable = true,
  }) {
    return Card(
      elevation: isAvailable ? 2 : 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAvailable ? color.withValues(alpha: 0.2) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      color: isAvailable ? Colors.white : Colors.grey.shade50,
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAvailable ? color.withValues(alpha: 0.1) : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isAvailable ? color : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isAvailable ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
              if (!isAvailable) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'COMING SOON',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openMasterMix(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MasterMixManagerScreen(
          wizard: MasterMixWizard(),
          onUpdate: (updated) {},
        ),
      ),
    );
    if (result != null && result is MasterMixWizard) {
      if (context.mounted) Navigator.pop(context, result.generateTable());
    }
  }

  void _openStaining(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StainingTableManagerScreen(
          wizard: StainingWizard(),
          onUpdate: (updated) {},
        ),
      ),
    );
    if (result != null && result is StainingWizard) {
      if (context.mounted) Navigator.pop(context, result.generateTable());
    }
  }

  void _openReagentMix(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReagentManagerScreen(
          wizard: ReagentMixWizard(),
          onUpdate: (updated) {},
        ),
      ),
    );
    if (result != null && result is ReagentMixWizard) {
      if (context.mounted) Navigator.pop(context, result.generateTable());
    }
  }

  void _openGenericTable(BuildContext context) async {
    final newTable = ProtocolTable(
      id: 'table_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Generic Table',
      type: TableType.generic,
      columnHeaders: List.generate(5, (i) => String.fromCharCode(65 + i)),
      rowHeaders: List.generate(10, (i) => (i + 1).toString()),
      data: List.generate(10, (_) => List.generate(5, (_) => '')),
      cellColors: List.generate(10, (_) => List.generate(5, (_) => '')),
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableDataEditorScreen(
          tables: [newTable],
          onSave: (updated) {},
        ),
      ),
    );

    if (result != null && result is List<ProtocolTable> && result.isNotEmpty) {
      if (context.mounted) Navigator.pop(context, result.first);
    }
  }

  void _openPlateLayout(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(),
          onUpdate: (updated) {},
        ),
      ),
    );
    if (result != null && result is PlateLayoutWizard) {
      if (context.mounted) Navigator.pop(context, result.toProtocolTable());
    }
  }
}
