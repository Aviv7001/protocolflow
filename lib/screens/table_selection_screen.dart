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
import '../theme/app_colors.dart';
import '../widgets/save_table_dialog.dart';
import 'plate_wizard_samples_screen.dart';
import 'saved_table_picker_screen.dart';
import 'table_data_editor_screen.dart';

Future<ProtocolTable?> showTableToolPicker(
  BuildContext context, {
  bool standaloneMode = false,
  String? initialProjectId,
}) {
  return showDialog<ProtocolTable>(
    context: context,
    builder: (dialogContext) => _TableToolPickerDialog(
      standaloneMode: standaloneMode,
      initialProjectId: initialProjectId,
    ),
  );
}

enum TableTool {
  masterMix,
  staining,
  serialDilution,
  plateLayout,
  generic,
  importTable,
}

Future<void> openTableTool(
  BuildContext context,
  TableTool tool, {
  bool standaloneMode = true,
  String? initialProjectId,
}) async {
  final launcher = TableSelectionScreen(
    standaloneMode: standaloneMode,
    popAfterStandaloneCreate: false,
    initialProjectId: initialProjectId,
  );
  switch (tool) {
    case TableTool.masterMix:
      await launcher._openMasterMix(context);
    case TableTool.staining:
      await launcher._openStaining(context);
    case TableTool.serialDilution:
      await launcher._openSerialDilution(context);
    case TableTool.plateLayout:
      await launcher._openPlateLayout(context);
    case TableTool.generic:
      await launcher._openGenericTable(context);
    case TableTool.importTable:
      await launcher._importGenericTable(context);
  }
}

class TableSelectionScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool standaloneMode;
  final bool embedded;
  final bool popAfterStandaloneCreate;
  final String? initialProjectId;

  const TableSelectionScreen({
    super.key,
    this.title = 'Add New Table',
    this.subtitle = 'Choose a specialized manager to create your table',
    this.standaloneMode = false,
    this.embedded = false,
    this.popAfterStandaloneCreate = false,
    this.initialProjectId,
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
        padding: const EdgeInsets.all(16),
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
      clipBehavior: Clip.antiAlias,
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

  Future<void> _openMasterMix(
    BuildContext context, {
    MasterMixWizard? initialWizard,
  }) async {
    final result = await Navigator.push<MasterMixWizard>(
      context,
      MaterialPageRoute(
        builder: (context) => MasterMixManagerScreen(
          wizard: initialWizard ?? MasterMixWizard(),
          onUpdate: (updated) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    final saved = await _handleCreatedTable(context, result.generateTable());
    if (!context.mounted || saved) return;
    await _openMasterMix(context, initialWizard: result);
  }

  Future<void> _openStaining(
    BuildContext context, {
    StainingWizard? initialWizard,
  }) async {
    final result = await Navigator.push<StainingWizard>(
      context,
      MaterialPageRoute(
        builder: (context) => StainingTableManagerScreen(
          wizard: initialWizard ?? StainingWizard(),
          onUpdate: (updated) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    final saved = await _handleCreatedTable(context, result.generateTable());
    if (!context.mounted || saved) return;
    await _openStaining(context, initialWizard: result);
  }

  Future<void> _openSerialDilution(
    BuildContext context, {
    SerialDilutionInput? initialInput,
  }) async {
    final result = await Navigator.push<SerialDilutionInput>(
      context,
      MaterialPageRoute(
        builder: (context) => SerialDilutionManagerScreen(
          input: initialInput ?? SerialDilutionInput(),
          onUpdate: (updated) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    final saved = await _handleCreatedTable(context, result.generateTable());
    if (!context.mounted || saved) return;
    await _openSerialDilution(context, initialInput: result);
  }

  Future<void> _openGenericTable(
    BuildContext context, {
    ProtocolTable? initialTable,
  }) async {
    final table =
        initialTable ??
        ProtocolTable(
          id: 'table_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Generic Table',
          type: TableType.generic,
          metadata: {'needs_dimension_setup': 'true'},
        );
    final result = await Navigator.push<List<ProtocolTable>>(
      context,
      MaterialPageRoute(
        builder: (context) => TableDataEditorScreen(
          tables: [table],
          onSave: (updated) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    if (!context.mounted || result == null || result.isEmpty) return;
    final updatedTable = result.first;
    final saved = await _handleCreatedTable(context, updatedTable);
    if (!context.mounted || saved) return;
    await _openGenericTable(context, initialTable: updatedTable);
  }

  Future<void> _openPlateLayout(
    BuildContext context, {
    PlateLayoutWizard? initialWizard,
  }) async {
    final result = await Navigator.push<PlateLayoutWizard>(
      context,
      MaterialPageRoute(
        builder: (context) => PlateWizardSamplesScreen(
          wizard: initialWizard ?? PlateLayoutWizard(),
          onUpdate: (updated) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    final saved = await _handleCreatedTable(context, result.toProtocolTable());
    if (!context.mounted || saved) return;
    await _openPlateLayout(context, initialWizard: result);
  }

  Future<void> _openSavedTables(BuildContext context) async {
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

  Future<bool> _handleCreatedTable(
    BuildContext context,
    ProtocolTable table,
  ) async {
    if (!context.mounted) return false;

    final details = await showSaveTableDialog(
      context,
      suggestedName: table.title.isEmpty ? 'Untitled Table' : table.title,
      initialProjectId: table.projectId ?? initialProjectId,
    );
    if (details == null || !context.mounted) return false;
    final savedTable = details.projectId == null
        ? table.copyWith(title: details.name, clearProjectId: true)
        : table.copyWith(title: details.name, projectId: details.projectId);

    if (!standaloneMode) {
      Navigator.pop(context, savedTable);
      return true;
    }

    await StorageService().upsertSavedTable(savedTable);
    if (!context.mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${savedTable.title}" saved'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => Navigator.pushNamed(context, '/saved_tables'),
        ),
      ),
    );
    if (popAfterStandaloneCreate && context.mounted) {
      Navigator.pop(context, savedTable);
    }
    return true;
  }
}

class _TableToolPickerDialog extends StatelessWidget {
  const _TableToolPickerDialog({
    required this.standaloneMode,
    this.initialProjectId,
  });

  final bool standaloneMode;
  final String? initialProjectId;

  @override
  Widget build(BuildContext context) {
    final launcher = TableSelectionScreen(
      standaloneMode: standaloneMode,
      popAfterStandaloneCreate: true,
      initialProjectId: initialProjectId,
    );
    return KeyedSubtree(
      key: ValueKey(
        'table-tool-project-context-${initialProjectId ?? 'unassigned'}',
      ),
      child: AlertDialog(
        key: const Key('table-tool-picker-dialog'),
        title: Row(
          children: [
            const Icon(Icons.science_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(standaloneMode ? 'Lab tools' : 'Add table')),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
          child: SingleChildScrollView(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolMenuItem(
                    icon: Icons.biotech,
                    color: Colors.blue,
                    title: 'Master Mix',
                    subtitle: 'Calculator',
                    onTap: () => launcher._openMasterMix(context),
                  ),
                  const Divider(height: 1),
                  _ToolMenuItem(
                    icon: Icons.color_lens,
                    color: Colors.indigo,
                    title: 'Staining',
                    subtitle: 'Panel generator',
                    onTap: () => launcher._openStaining(context),
                  ),
                  const Divider(height: 1),
                  _ToolMenuItem(
                    icon: Icons.water_drop,
                    color: Colors.cyan,
                    title: 'Serial Dilution',
                    subtitle: 'Standard curve',
                    onTap: () => launcher._openSerialDilution(context),
                  ),
                  const Divider(height: 1),
                  _ToolMenuItem(
                    icon: Icons.grid_on,
                    color: Colors.orange,
                    title: 'Plate Layout',
                    subtitle: 'Well designer',
                    onTap: () => launcher._openPlateLayout(context),
                  ),
                  const Divider(height: 1),
                  _ToolMenuItem(
                    icon: Icons.table_chart,
                    color: Colors.grey,
                    title: 'Generic Table',
                    subtitle: 'Custom grid',
                    onTap: () => launcher._openGenericTable(context),
                  ),
                  if (!standaloneMode) ...[
                    const Divider(height: 1),
                    _ToolMenuItem(
                      icon: Icons.folder_copy_outlined,
                      color: Colors.green,
                      title: 'Saved Tables',
                      subtitle: 'Choose existing',
                      onTap: () => launcher._openSavedTables(context),
                    ),
                  ],
                  const Divider(height: 1),
                  _ToolMenuItem(
                    icon: Icons.file_upload_outlined,
                    color: AppColors.primary,
                    title: 'Import Table',
                    subtitle: 'From CSV or Excel',
                    onTap: () => launcher._importGenericTable(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ToolMenuItem extends StatelessWidget {
  const _ToolMenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
