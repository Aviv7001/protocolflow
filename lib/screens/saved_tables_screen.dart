import 'package:flutter/material.dart';

import '../models/protocol_table.dart';
import '../services/storage_service.dart';
import '../widgets/protocol_table_widget.dart';
import '../theme/app_colors.dart';
import '../widgets/protocolflow_app_bar.dart';
import '../widgets/table_workspace.dart';

class SavedTablesScreen extends StatefulWidget {
  final bool embedded;
  const SavedTablesScreen({super.key, this.embedded = false});

  @override
  State<SavedTablesScreen> createState() => _SavedTablesScreenState();
}

class _SavedTablesScreenState extends State<SavedTablesScreen> {
  final StorageService _storageService = StorageService();
  List<ProtocolTable> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    final tables = await _storageService.loadSavedTables();
    if (!mounted) return;
    setState(() {
      _tables = tables;
      _isLoading = false;
    });
  }

  Future<void> _openLabTools() async {
    await Navigator.pushNamed(context, '/lab_tools');
    if (mounted) _loadTables();
  }

  Future<void> _saveUpdatedTable(ProtocolTable table) async {
    await _storageService.upsertSavedTable(table);
    await _loadTables();
  }

  Future<void> _confirmDelete(ProtocolTable table) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Table?'),
        content: Text('Delete "${table.title}" from Saved Tables?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _storageService.deleteSavedTable(table.id);
      await _loadTables();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : ProtocolFlowAppBar(title: 'Saved Tables'),
      body: SafeArea(
        top: !widget.embedded,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadTables,
                child: _tables.isEmpty ? _buildEmptyState() : _buildTableList(),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLabTools,
        icon: const Icon(Icons.add),
        label: const Text('New Table'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        TableWorkspaceEmptyState(
          title: 'No saved tables yet',
          message: 'Use Lab Tools to generate a table and save it here.',
          icon: Icons.table_chart_outlined,
          action: ElevatedButton.icon(
            onPressed: _openLabTools,
            icon: const Icon(Icons.science),
            label: const Text('Open Lab Tools'),
          ),
        ),
      ],
    );
  }

  Widget _buildTableList() {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisExtent: 150,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _tables.length,
      itemBuilder: (context, index) {
        final table = _tables[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.outlineVariant),
          ),
          child: Stack(
            children: [
              Center(
                child: ProtocolTableWidget(
                  table: table,
                  isReadOnly: false,
                  onSave: _saveUpdatedTable,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete table',
                  onPressed: () => _confirmDelete(table),
                  color: Colors.red,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  _typeLabel(table.type),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _typeLabel(TableType type) {
    switch (type) {
      case TableType.masterMix:
        return 'Master mix';
      case TableType.staining:
        return 'Staining table';
      case TableType.serialDilution:
        return 'Serial dilution';
      case TableType.plateLayout:
        return 'Plate layout';
      case TableType.checklist:
        return 'Checklist';
      case TableType.materialList:
        return 'Material list';
      case TableType.generic:
        return 'Generic table';
    }
  }
}
