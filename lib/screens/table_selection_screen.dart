import 'package:flutter/material.dart';
import '../models/protocol_table.dart';
import '../models/master_mix_wizard.dart';
import '../features/staining_table/models/staining_wizard.dart';
import '../models/plate_wizard.dart';
import '../features/master_mix/screens/master_mix_manager_screen.dart';
import '../features/serial_dilution/models/serial_dilution_input.dart';
import '../features/serial_dilution/screens/serial_dilution_manager_screen.dart';
import '../features/staining_table/screens/staining_table_manager_screen.dart';
import '../services/storage_service.dart';
import '../services/generic_table_import_service.dart';
import '../widgets/protocolflow_app_bar.dart';
import 'plate_wizard_samples_screen.dart';
import 'saved_table_picker_screen.dart';
import 'table_data_editor_screen.dart';

class TableSelectionScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool standaloneMode;
  final bool embedded;

  const TableSelectionScreen({
    super.key,
    this.title = 'Add New Table',
    this.subtitle = 'Choose a specialized manager to create your table',
    this.standaloneMode = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
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
        'Serial Dilution',
        'Standard Curve',
        Icons.water_drop,
        Colors.cyan,
        onTap: () => _openSerialDilution(context),
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
      if (!standaloneMode)
        _buildTypeCard(
          context,
          'Saved Tables',
          'Choose Existing',
          Icons.folder_copy,
          Colors.green,
          onTap: () => _openSavedTables(context),
        ),
      _buildTypeCard(
        context,
        'Import Table',
        'From CSV/Excel',
        Icons.file_upload,
        Colors.purple,
        onTap: () => _importGenericTable(context),
      ),
    ];

    return Scaffold(
      appBar: embedded ? null : ProtocolFlowAppBar(title: title),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              standaloneMode ? 'Select Tool' : 'Select Table Type',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 180,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) => cards[index],
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
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isAvailable
              ? color.withValues(alpha: 0.2)
              : Colors.grey.shade300,
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
                  color: isAvailable
                      ? color.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isAvailable
                      ? Colors.grey.shade600
                      : Colors.grey.shade400,
                ),
              ),
              if (!isAvailable) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'COMING SOON',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
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
    if (!context.mounted) return;
    if (result != null && result is MasterMixWizard) {
      await _handleCreatedTable(context, result.generateTable());
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
    if (!context.mounted) return;
    if (result != null && result is StainingWizard) {
      await _handleCreatedTable(context, result.generateTable());
    }
  }

  void _openSerialDilution(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SerialDilutionManagerScreen(
          input: SerialDilutionInput(),
          onUpdate: (updated) {},
        ),
      ),
    );
    if (!context.mounted) return;
    if (result != null && result is SerialDilutionInput) {
      await _handleCreatedTable(context, result.generateTable());
    }
  }

  void _openGenericTable(BuildContext context) async {
    final newTable = ProtocolTable(
      id: 'table_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Generic Table',
      type: TableType.generic,
      metadata: {'needs_dimension_setup': 'true'},
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TableDataEditorScreen(tables: [newTable], onSave: (updated) {}),
      ),
    );

    if (!context.mounted) return;
    if (result != null && result is List<ProtocolTable> && result.isNotEmpty) {
      await _handleCreatedTable(context, result.first);
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
    if (!context.mounted) return;
    if (result != null && result is PlateLayoutWizard) {
      await _handleCreatedTable(context, result.toProtocolTable());
    }
  }

  void _openSavedTables(BuildContext context) async {
    final result = await Navigator.push<ProtocolTable>(
      context,
      MaterialPageRoute(builder: (context) => const SavedTablePickerScreen()),
    );
    if (!context.mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _importGenericTable(BuildContext context) async {
    final result = await const GenericTableImportService().importTable();
    if (!context.mounted) return;

    if (!result.success || result.table == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    await _handleCreatedTable(context, result.table!);
    if (!context.mounted || !standaloneMode) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _handleCreatedTable(
    BuildContext context,
    ProtocolTable table,
  ) async {
    if (!context.mounted) return;

    if (!standaloneMode) {
      Navigator.pop(context, table);
      return;
    }

    await StorageService().upsertSavedTable(table);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${table.title.isEmpty ? 'Untitled Table' : table.title}" saved',
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => Navigator.pushNamed(context, '/saved_tables'),
        ),
      ),
    );
  }
}
