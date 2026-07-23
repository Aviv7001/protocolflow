import 'package:flutter/material.dart';
import '../models/protocol.dart';
import '../models/project.dart';
import '../models/active_protocol.dart';
import '../data/completed_protocols_data.dart';
import '../services/storage_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sync_status_chip.dart';
import '../utils/date_time_format.dart';
import 'protocol_detail_screen.dart';
import 'projects_screen.dart';
import 'completed_protocol_detail_screen.dart';
import 'run_protocol_screen.dart';
import 'create_protocol_screen.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? initialProjectId;
  final bool embedded;
  const LibraryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialProjectId,
    this.embedded = false,
  });

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
  List<Project> _projects = [];
  String? _selectedProjectId;
  bool _isLoading = true;
  static const String _allProjectsFilter = '__all__';
  static const String _unassignedProjectsFilter = '__unassigned__';

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
    _selectedProjectId = widget.initialProjectId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _protocols = await _storageService.loadProtocols();
    _projects = await _storageService.loadProjects();
    setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    await loadPersistentProtocols();
    await _loadData();
  }

  Widget _refreshableEmpty(String message) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: 320, child: Center(child: Text(message)))],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = ColoredBox(
      color: AppColors.scaffoldBackground,
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.outlineVariant,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.primary,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Templates', icon: Icon(Icons.copy_all, size: 20)),
          Tab(text: 'Protocols', icon: Icon(Icons.description, size: 20)),
          Tab(text: 'Running', icon: Icon(Icons.play_circle_outline, size: 20)),
          Tab(text: 'History', icon: Icon(Icons.history, size: 20)),
        ],
      ),
    );
    final body = SafeArea(
      top: false,
      child: Column(
        children: [
          if (widget.embedded) tabBar,
          Expanded(
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
        ],
      ),
    );

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Library'),
              actions: [
                IconButton(
                  tooltip: 'Projects',
                  icon: const Icon(Icons.folder_copy_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProjectsScreen(),
                    ),
                  ).then((_) => _loadData()),
                ),
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
                        title: Text('Import ProtocolFlow file'),
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: tabBar,
              ),
            ),
      body: body,
      floatingActionButton:
          (_tabController.index == 0 || _tabController.index == 1)
          ? FloatingActionButton(
              onPressed: () async {
                final result = await _openCreateProtocol();
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
        .where((p) => _matchesSelectedProject(p))
        .toList();

    if (filteredProtocols.isEmpty) {
      return Column(
        children: [
          _buildProjectFilter(),
          Expanded(
            child: _refreshableEmpty(
              isTemplate ? 'No templates found.' : 'No protocols found.',
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredProtocols.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildProjectFilter();
          final protocol = filteredProtocols[index - 1];
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
                const SizedBox(height: 3),
                Text(
                  'Created on: ${formatDate(protocol.createdAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Created by: ${protocol.createdByName ?? 'Unknown user'}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Project: ${_projectNameFor(protocol.projectId)}',
                  style: const TextStyle(fontSize: 12),
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
      ),
    );
  }

  Future<Object?> _openCreateProtocol() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProtocolScreen(
          initialProjectId: _selectedProjectId == '__unassigned__'
              ? null
              : _selectedProjectId,
        ),
      ),
    );
  }

  bool _matchesSelectedProject(Protocol protocol) {
    final selected = _selectedProjectId;
    if (selected == null) return true;
    final projectId = protocol.projectId;
    if (selected == _unassignedProjectsFilter) {
      return projectId == null ||
          projectId.isEmpty ||
          !_projects.any((project) => project.id == projectId);
    }
    return projectId == selected;
  }

  String _projectNameFor(String? projectId) {
    if (projectId == null || projectId.isEmpty) return 'Unassigned';
    for (final project in _projects) {
      if (project.id == projectId) return project.name;
    }
    return 'Unassigned';
  }

  Widget _buildProjectFilter() {
    final project = _selectedProject();
    final color = project == null
        ? AppColors.primary
        : Color(project.colorValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: PopupMenuButton<String>(
          tooltip: 'Filter by project',
          initialValue: _selectedProjectId ?? _allProjectsFilter,
          onSelected: (value) => setState(
            () =>
                _selectedProjectId = value == _allProjectsFilter ? null : value,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: _allProjectsFilter,
              child: ListTile(
                leading: Icon(Icons.all_inbox_outlined),
                title: Text('All projects'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            for (final project in _projects)
              PopupMenuItem<String>(
                value: project.id,
                child: ListTile(
                  leading: Icon(
                    Icons.folder_outlined,
                    color: Color(project.colorValue),
                  ),
                  title: Text(project.name),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: _unassignedProjectsFilter,
              child: ListTile(
                leading: Icon(Icons.folder_off_outlined),
                title: Text('Unassigned'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          child: Chip(
            avatar: Icon(_projectFilterIcon(), color: color, size: 18),
            label: Text(_projectFilterLabel()),
            side: BorderSide(color: color.withValues(alpha: 0.35)),
          ),
        ),
      ),
    );
  }

  Project? _selectedProject() {
    for (final project in _projects) {
      if (project.id == _selectedProjectId) return project;
    }
    return null;
  }

  IconData _projectFilterIcon() {
    if (_selectedProjectId == _unassignedProjectsFilter) {
      return Icons.folder_off_outlined;
    }
    if (_selectedProjectId == null) return Icons.all_inbox_outlined;
    return Icons.folder_outlined;
  }

  String _projectFilterLabel() {
    if (_selectedProjectId == null) return 'All projects';
    if (_selectedProjectId == _unassignedProjectsFilter) return 'Unassigned';
    return _selectedProject()?.name ?? 'Unassigned';
  }

  Widget _buildRunningTab() {
    final activeMatches =
        activeProtocol != null &&
        _matchesSelectedProject(activeProtocol!.protocol);
    final filteredRunning = runningProtocols
        .where(
          (p) =>
              (activeProtocol == null ||
                  p.protocol.id != activeProtocol!.protocol.id) &&
              _matchesSelectedProject(p.protocol),
        )
        .toList();

    if (!activeMatches && filteredRunning.isEmpty) {
      return Column(
        children: [
          _buildProjectFilter(),
          Expanded(child: _refreshableEmpty('No protocols currently running.')),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildProjectFilter(),
          if (activeMatches) ...[
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
          if (filteredRunning.isNotEmpty) ...[
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
            ...filteredRunning.map((p) => _buildRunningProtocolItem(p)),
          ],
        ],
      ),
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
      color: AppColors.primaryContainer,
      child: ListTile(
        leading: const Icon(
          Icons.play_circle_fill,
          color: AppColors.info,
          size: 40,
        ),
        title: Text(
          protocol.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: const TextStyle(color: AppColors.info)),
            Text(
              'Started: ${activeProtocol!.startedAt.toString().split('.')[0]}',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              'Project: ${_projectNameFor(protocol.projectId)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
              backgroundColor: AppColors.surfaceContainer,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Steps completed: $completedCount/$totalSteps'),
            Text(
              'Project: ${_projectNameFor(protocol.projectId)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(isActive ? 'Terminate' : 'Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final filteredCompleted = completedProtocols
        .where((completed) => _matchesSelectedProject(completed.protocol))
        .toList();

    if (filteredCompleted.isEmpty) {
      return Column(
        children: [
          _buildProjectFilter(),
          Expanded(child: _refreshableEmpty('No history found.')),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredCompleted.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildProjectFilter();
          final completed = filteredCompleted[index - 1];
          final dateStr = formatDate(completed.completedAt);

          return ListTile(
            leading: const Icon(Icons.check_circle, color: AppColors.success),
            title: Text(completed.protocol.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Completed on: $dateStr'),
                Text(
                  'Completed by: '
                  '${completed.completedByName ?? 'Unknown user'}',
                ),
                Text(
                  'Project: ${_projectNameFor(completed.protocol.projectId)}',
                ),
                const SizedBox(height: 4),
                SyncStatusChip(status: completed.syncStatus, compact: true),
              ],
            ),
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
      ),
    );
  }
}
