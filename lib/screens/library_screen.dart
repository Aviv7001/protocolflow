import 'package:flutter/material.dart';
import '../models/protocol.dart';
import '../models/active_protocol.dart';
import '../data/completed_protocols_data.dart';
import '../services/storage_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../data/mock_protocols.dart';
import '../widgets/sync_status_chip.dart';
import 'protocol_detail_screen.dart';
import 'completed_protocol_detail_screen.dart';
import 'run_protocol_screen.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTabIndex;
  const LibraryScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageService _storageService = StorageService();
  final ExportService _exportService = ExportService();
  final ImportService _importService = ImportService();
  List<Protocol> _protocols = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final loadedProtocols = await _storageService.loadProtocols();
    if (loadedProtocols.isEmpty) {
      _protocols = getMockProtocols();
      await _storageService.saveProtocols(_protocols);
    } else {
      _protocols = loadedProtocols;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export_all') {
                await _exportService.exportAllData();
              } else if (value == 'export_templates') {
                await _exportService.exportTemplates();
              } else if (value == 'export_history') {
                await _exportService.exportHistory();
              } else if (value == 'import') {
                final result = await _importService.importJson();
                if (!context.mounted) return;
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result.message)));
                  if (result.success) _loadData();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('Import JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export_all',
                child: ListTile(
                  leading: Icon(Icons.backup),
                  title: Text('Export All Data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_templates',
                child: ListTile(
                  leading: Icon(Icons.description),
                  title: Text('Export Templates'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Export History'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Templates', icon: Icon(Icons.copy_all, size: 20)),
            Tab(text: 'Protocols', icon: Icon(Icons.description, size: 20)),
            Tab(
              text: 'Running',
              icon: Icon(Icons.play_circle_outline, size: 20),
            ),
            Tab(text: 'History', icon: Icon(Icons.history, size: 20)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildProtocolsTab(isTemplate: true),
            _buildProtocolsTab(isTemplate: false),
            _buildRunningTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
      floatingActionButton:
          (_tabController.index == 0 || _tabController.index == 1)
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/create');
                if (result != null) _loadData();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildProtocolsTab({required bool isTemplate}) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final filteredProtocols = _protocols
        .where((p) => p.isTemplate == isTemplate)
        .toList();

    if (filteredProtocols.isEmpty) {
      return Center(
        child: Text(isTemplate ? 'No templates found.' : 'No protocols found.'),
      );
    }

    return ListView.builder(
      itemCount: filteredProtocols.length,
      itemBuilder: (context, index) {
        final protocol = filteredProtocols[index];
        return ListTile(
          leading: Icon(
            isTemplate ? Icons.copy_all : Icons.article_outlined,
            color: isTemplate ? Colors.purple : Colors.blue,
          ),
          title: Text(protocol.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                protocol.objective,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              SyncStatusChip(status: protocol.syncStatus, compact: true),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProtocolDetailScreen(protocol: protocol),
            ),
          ).then((_) => _loadData()),
        );
      },
    );
  }

  Widget _buildRunningTab() {
    if (activeProtocol == null && runningProtocols.isEmpty) {
      return const Center(child: Text('No protocols currently running.'));
    }

    return ListView(
      children: [
        if (activeProtocol != null) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'ACTIVE SESSION',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          _buildActiveProtocolItem(),
        ],
        if (runningProtocols.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'IN PROGRESS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          ...runningProtocols
              .where(
                (p) =>
                    activeProtocol == null ||
                    p.protocol.id != activeProtocol!.protocol.id,
              )
              .map((p) => _buildRunningProtocolItem(p)),
        ],
      ],
    );
  }

  Widget _buildActiveProtocolItem() {
    final protocol = activeProtocol!.protocol;
    final currentIdx = activeProtocol!.currentStepIndex;
    String status = 'Preparing';
    if (currentIdx >= 0 && currentIdx < protocol.steps.length) {
      final step = protocol.steps[currentIdx];
      status = 'Step ${currentIdx + 1}: ${step.title}';
      if (step.phaseName != null && step.phaseName!.isNotEmpty) {
        status = '${step.phaseName} - $status';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.blue.shade50,
      child: ListTile(
        leading: const Icon(
          Icons.play_circle_fill,
          color: Colors.blue,
          size: 40,
        ),
        title: Text(
          protocol.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: const TextStyle(color: Colors.blue)),
            Text(
              'Started: ${activeProtocol!.startedAt.toString().split('.')[0]}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Terminate progress',
              onPressed: () => _confirmRemoveRunningProtocol(activeProtocol!),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RunProtocolScreen(protocol: protocol),
          ),
        ).then((_) => setState(() {})),
      ),
    );
  }

  Widget _buildRunningProtocolItem(ActiveProtocol runningState) {
    final protocol = runningState.protocol;
    final completedCount = runningState.completedStepIds.length;
    final totalSteps = protocol.steps.length;
    final progress = totalSteps > 0 ? completedCount / totalSteps : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.grey.shade200,
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        title: Text(
          protocol.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Steps completed: $completedCount/$totalSteps'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Remove progress',
              onPressed: () => _confirmRemoveRunningProtocol(runningState),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProtocolDetailScreen(
              protocol: protocol,
              activeState: runningState,
            ),
          ),
        ).then((_) => setState(() {})),
      ),
    );
  }

  void _confirmRemoveRunningProtocol(ActiveProtocol state) {
    final isActive = activeProtocol?.protocol.id == state.protocol.id;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isActive ? 'Terminate Active Protocol?' : 'Remove Progress?',
        ),
        content: Text(
          isActive
              ? 'This will terminate the active protocol and delete its current progress.'
              : 'This will remove this protocol from the running tab and delete its saved progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (isActive) {
                activeProtocol = null;
              }
              runningProtocols.removeWhere(
                (p) => p.protocol.id == state.protocol.id,
              );
              await savePersistentProtocols();
              if (!mounted) return;
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isActive ? 'Terminate' : 'Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (completedProtocols.isEmpty) {
      return const Center(child: Text('No history found.'));
    }

    return ListView.builder(
      itemCount: completedProtocols.length,
      itemBuilder: (context, index) {
        final completed = completedProtocols[index];
        final date = completed.completedAt;
        final dateStr = '${date.year}-${date.month}-${date.day}';

        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(completed.protocol.title),
          subtitle: Text('Completed on: $dateStr'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CompletedProtocolDetailScreen(completedProtocol: completed),
            ),
          ).then((_) => setState(() {})),
        );
      },
    );
  }
}
