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
import '../widgets/running_protocol_summary_card.dart';
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
          Tab(text: 'Completed', icon: Icon(Icons.check_circle, size: 20)),
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
          return _LibraryEntryCard(
            entryId: protocol.id,
            title: protocol.title,
            type: isTemplate
                ? _LibraryEntryType.template
                : _LibraryEntryType.protocol,
            firstLabel: 'Created by',
            firstValue: protocol.createdByName ?? 'Unknown user',
            secondLabel: 'Created on',
            secondValue: formatDate(protocol.createdAt),
            projectChip: _buildProjectChip(protocol.projectId),
            syncStatus: protocol.syncStatus,
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

  Project? _projectFor(String? projectId) {
    if (projectId == null || projectId.isEmpty) return null;
    for (final project in _projects) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  Widget _buildProjectChip(String? projectId) {
    final project = _projectFor(projectId);
    final color = project == null
        ? AppColors.textSecondary
        : Color(project.colorValue);
    return _LibraryBadge(
      label: project?.name ?? 'Unassigned',
      icon: project == null ? Icons.folder_off_outlined : Icons.folder_outlined,
      color: color,
    );
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

    final totalSteps = protocol.steps.length;
    final completedCount = activeProtocol!.completedStepIds.length;
    return RunningProtocolSummaryCard(
      state: activeProtocol!,
      detail: status,
      progressValue: '$completedCount of $totalSteps steps',
      project: _projectFor(protocol.projectId),
      phaseKeyPrefix: 'active-library',
      action: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        tooltip: 'Terminate progress',
        onPressed: () => _confirmRemoveRunningProtocol(activeProtocol!),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RunProtocolScreen(protocol: protocol),
        ),
      ).then((_) => setState(() {})),
    );
  }

  Widget _buildRunningProtocolItem(ActiveProtocol runningState) {
    final protocol = runningState.protocol;
    final completedCount = runningState.completedStepIds.length;
    final totalSteps = protocol.steps.length;
    final progress = totalSteps > 0 ? completedCount / totalSteps : 0.0;

    return RunningProtocolSummaryCard(
      state: runningState,
      detail: 'Steps completed: $completedCount/$totalSteps',
      progressValue: '${(progress * 100).toInt()}% complete',
      project: _projectFor(protocol.projectId),
      phaseKeyPrefix: 'running-library',
      action: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        tooltip: 'Remove progress',
        onPressed: () => _confirmRemoveRunningProtocol(runningState),
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
          Expanded(child: _refreshableEmpty('No completed protocols found.')),
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

          return _LibraryEntryCard(
            entryId: completed.id,
            title: completed.protocol.title,
            type: _LibraryEntryType.completed,
            firstLabel: 'Completed by',
            firstValue: completed.completedByName ?? 'Unknown user',
            secondLabel: 'Completed on',
            secondValue: dateStr,
            projectChip: _buildProjectChip(completed.protocol.projectId),
            syncStatus: completed.syncStatus,
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

enum _LibraryEntryType { template, protocol, running, completed }

class _LibraryEntryCard extends StatelessWidget {
  const _LibraryEntryCard({
    required this.entryId,
    required this.title,
    required this.type,
    required this.firstLabel,
    required this.firstValue,
    required this.secondLabel,
    required this.secondValue,
    required this.projectChip,
    required this.onTap,
    this.syncStatus,
  });

  final String entryId;
  final String title;
  final _LibraryEntryType type;
  final String firstLabel;
  final String firstValue;
  final String secondLabel;
  final String secondValue;
  final Widget projectChip;
  final ProtocolSyncStatus? syncStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              SizedBox(
                key: Key('library-tags-placeholder-$entryId'),
                height: 24,
              ),
              const Divider(height: 1),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final first = _LibraryMetadata(
                    label: firstLabel,
                    value: firstValue,
                    icon: Icons.person_outline,
                  );
                  final second = _LibraryMetadata(
                    label: secondLabel,
                    value: secondValue,
                    icon: Icons.calendar_today_outlined,
                    alignEnd: constraints.maxWidth >= 520,
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [first, const SizedBox(height: 14), second],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: first),
                      const SizedBox(width: 24),
                      Expanded(child: second),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'PROJECT',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  key: Key('library-project-badge-$entryId'),
                  child: projectChip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final badges = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _LibraryTypeBadge(key: Key('library-type-badge-$entryId'), type: type),
        if (syncStatus != null)
          SyncStatusChip(
            key: Key('library-sync-badge-$entryId'),
            status: syncStatus!,
            compact: true,
          ),
      ],
    );
    final heading = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: badges),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 16),
            Flexible(child: badges),
          ],
        );
      },
    );
  }
}

class _LibraryMetadata extends StatelessWidget {
  const _LibraryMetadata({
    required this.label,
    required this.value,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryTypeBadge extends StatelessWidget {
  const _LibraryTypeBadge({super.key, required this.type});

  final _LibraryEntryType type;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (type) {
      _LibraryEntryType.template => (
        'TEMPLATE',
        Icons.copy_all_outlined,
        AppColors.aiPrimary,
      ),
      _LibraryEntryType.protocol => (
        'PROTOCOL',
        Icons.article_outlined,
        AppColors.primary,
      ),
      _LibraryEntryType.running => (
        'RUNNING',
        Icons.play_circle_outline,
        AppColors.info,
      ),
      _LibraryEntryType.completed => (
        'COMPLETED',
        Icons.check_circle_outline,
        AppColors.success,
      ),
    };
    return _LibraryBadge(label: label, icon: icon, color: color);
  }
}

class _LibraryBadge extends StatelessWidget {
  const _LibraryBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
