import 'package:flutter/material.dart';

import '../models/protocol_table.dart';
import '../services/storage_service.dart';

class SavedTablePickerScreen extends StatefulWidget {
  const SavedTablePickerScreen({super.key});

  @override
  State<SavedTablePickerScreen> createState() => _SavedTablePickerScreenState();
}

class _SavedTablePickerScreenState extends State<SavedTablePickerScreen> {
  final StorageService _storageService = StorageService();
  List<ProtocolTable> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final tables = await _storageService.loadSavedTables();
    if (!mounted) return;
    setState(() {
      _tables = tables;
      _isLoading = false;
    });
  }

  void _selectTable(ProtocolTable table) {
    Navigator.pop(
      context,
      table.copyWith(id: 'table_${DateTime.now().millisecondsSinceEpoch}'),
    );
  }

  Future<void> _openLabTools() async {
    await Navigator.pushNamed(context, '/lab_tools');
    if (mounted) _loadTables();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Saved Table')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _tables.isEmpty
            ? _buildEmptyState()
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 170,
                  mainAxisExtent: 142,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _tables.length,
                itemBuilder: (context, index) {
                  final table = _tables[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _selectTable(table),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: _typeColor(
                                  table.type,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _typeColor(
                                    table.type,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(
                                _typeIcon(table.type),
                                size: 34,
                                color: _typeColor(table.type),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              table.title.isEmpty
                                  ? 'Untitled Table'
                                  : table.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _typeLabel(table.type),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 56,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved tables yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create one in Lab Tools, then attach it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openLabTools,
              icon: const Icon(Icons.science),
              label: const Text('Open Lab Tools'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(TableType type) {
    switch (type) {
      case TableType.masterMix:
        return Icons.biotech;
      case TableType.staining:
        return Icons.color_lens;
      case TableType.reagentMix:
      case TableType.reagentMatrix:
        return Icons.science;
      case TableType.serialDilution:
        return Icons.water_drop;
      case TableType.plateLayout:
        return Icons.grid_on;
      case TableType.checklist:
        return Icons.checklist;
      case TableType.generic:
        return Icons.table_chart;
    }
  }

  Color _typeColor(TableType type) {
    switch (type) {
      case TableType.masterMix:
        return Colors.blue;
      case TableType.staining:
        return Colors.indigo;
      case TableType.reagentMix:
      case TableType.reagentMatrix:
        return Colors.teal;
      case TableType.serialDilution:
        return Colors.cyan;
      case TableType.plateLayout:
        return Colors.orange;
      case TableType.checklist:
        return Colors.green;
      case TableType.generic:
        return Colors.grey;
    }
  }

  String _typeLabel(TableType type) {
    switch (type) {
      case TableType.masterMix:
        return 'Master mix';
      case TableType.staining:
        return 'Staining table';
      case TableType.reagentMix:
      case TableType.reagentMatrix:
        return 'Reagent mix';
      case TableType.serialDilution:
        return 'Serial dilution';
      case TableType.plateLayout:
        return 'Plate layout';
      case TableType.checklist:
        return 'Checklist';
      case TableType.generic:
        return 'Generic table';
    }
  }
}
