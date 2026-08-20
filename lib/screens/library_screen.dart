import 'package:flutter/material.dart';
import '../models/protocol.dart';
import '../models/project.dart';
import '../models/active_protocol.dart';
import '../models/protocol_publication.dart';
import '../models/protocol_run.dart';
import '../data/completed_protocols_data.dart';
import '../services/protocol_run_service.dart';
import '../services/storage_service.dart';
import '../services/import_service.dart';
import '../theme/app_colors.dart';
import '../widgets/running_protocol_summary_card.dart';
import '../widgets/protocol_summary_card.dart';
import '../widgets/sync_status_chip.dart';
import '../widgets/publication_status_chip.dart';
import '../widgets/protocolflow_ui.dart';
import 'protocol_detail_screen.dart';
import 'projects_screen.dart';
import 'completed_protocol_detail_screen.dart';
import 'run_protocol_screen.dart';
import 'create_protocol_screen.dart';
import 'shared_protocol_import_screen.dart';
import 'shared_protocol_scanner_screen.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? initialProjectId;
  final bool embedded;
  final bool protocolsPrimaryMode;
  const LibraryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialProjectId,
    this.embedded = false,
    this.protocolsPrimaryMode = false,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageService _storageService = StorageService();
  final ImportService _importService = ImportService();
  final TextEditingController _searchController = TextEditingController();
  List<Protocol> _protocols = [];
  List<Project> _projects = [];
  String? _selectedProjectId;
  bool _isLoading = true;
  String _searchQuery = '';
  _LibraryDateSort _dateSort = _LibraryDateSort.newestFirst;
  static const String _allProjectsFilter = '__all__';
  static const String _unassignedProjectsFilter = '__unassigned__';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.protocolsPrimaryMode ? 2 : 4,
      vsync: this,
      initialIndex: widget.protocolsPrimaryMode
          ? (widget.initialTabIndex == 0 ? 1 : 0)
          : widget.initialTabIndex,
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
    final values = await Future.wait([
      _storageService.loadProtocols(),
      _storageService.loadProjects(),
      loadPersistentProtocols(),
    ]);
    _protocols = values[0] as List<Protocol>;
    _projects = values[1] as List<Project>;
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    await loadPersistentProtocols();
    await _loadData();
  }

  Future<void> _scanSharedProtocol() async {
    final link = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const SharedProtocolScannerScreen(),
      ),
    );
    if (!mounted || link == null || link.isEmpty) return;
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SharedProtocolImportScreen(shareUri: link),
      ),
    );
    if (imported == true) await _loadData();
  }

  Future<void> _importProtocolFile() async {
    final result = await _importService.importJson();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) await _loadData();
  }

  Future<void> _handleImportSelection(_LibraryImportOption selection) async {
    switch (selection) {
      case _LibraryImportOption.file:
        await _importProtocolFile();
      case _LibraryImportOption.qrCode:
        await _scanSharedProtocol();
    }
  }

  Widget _buildImportMenu({String label = 'Import', Key? key}) {
    return PopupMenuButton<_LibraryImportOption>(
      key: key,
      tooltip: 'Import protocol',
      position: PopupMenuPosition.under,
      onSelected: _handleImportSelection,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _LibraryImportOption.file,
          child: ListTile(
            leading: Icon(Icons.file_upload_outlined, color: AppColors.primary),
            title: Text('Import from file'),
            subtitle: Text('Choose a ProtocolFlow JSON file'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _LibraryImportOption.qrCode,
          child: ListTile(
            leading: Icon(Icons.qr_code_scanner, color: AppColors.primary),
            title: Text('Scan QR code'),
            subtitle: Text('Import a shared protocol'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.file_upload_outlined),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _refreshableEmpty(String message) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: ProtocolFlowEmptyState(message: message),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = ProtocolFlowTabBar(
      controller: _tabController,
      tabs: widget.protocolsPrimaryMode
          ? const [Tab(text: 'My Protocols'), Tab(text: 'Templates')]
          : const [
              Tab(text: 'Templates'),
              Tab(text: 'Protocols'),
              Tab(text: 'Running'),
              Tab(text: 'Completed'),
            ],
    );
    final body = SafeArea(
      top: !widget.embedded,
      child: ProtocolFlowContentBoundary(
        child: Column(
          children: [
            if (!widget.embedded) _buildLibraryBrandHeader(),
            _buildLibraryHeading(),
            tabBar,
            _buildLibraryControls(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  if (widget.protocolsPrimaryMode) ...[
                    _buildProtocolsTab(isTemplate: false),
                    _buildProtocolsTab(isTemplate: true),
                  ] else ...[
                    _buildProtocolsTab(isTemplate: true),
                    _buildProtocolsTab(isTemplate: false),
                    _buildRunningTab(),
                    _buildHistoryTab(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(body: body);
  }

  Widget _buildLibraryBrandHeader() {
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            if (Navigator.canPop(context)) ...[
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
            ],
            const Expanded(
              child: Text(
                'ProtocolFlow',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Projects',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProjectsScreen()),
              ).then((_) => _loadData()),
              icon: const CircleAvatar(
                backgroundColor: AppColors.surfaceContainer,
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryHeading() {
    final showActions =
        widget.protocolsPrimaryMode ||
        _tabController.index == 0 ||
        _tabController.index == 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Text(
            widget.protocolsPrimaryMode ? 'Protocols' : 'Library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final result = await _openCreateProtocol();
                  if (result != null) _loadData();
                },
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
              const SizedBox(width: 8),
              _buildImportMenu(key: const Key('library-import-button')),
            ],
          );
          if (showActions && constraints.maxWidth < 400) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              if (showActions) actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildProtocolsTab({required bool isTemplate}) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final filteredProtocols =
        _protocols
            .where((p) => p.isTemplate == isTemplate)
            .where((p) => _matchesSelectedProject(p))
            .where((p) => _matchesSearch(p.title, p.objective, p.description))
            .toList()
          ..sort((a, b) => _compareDates(a.createdAt, b.createdAt));

    if (filteredProtocols.isEmpty) {
      if (widget.protocolsPrimaryMode && !isTemplate) {
        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              const Icon(
                Icons.description_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No protocols yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a reusable procedure or import a shared protocol.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await _openCreateProtocol();
                      if (result != null) _loadData();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create protocol'),
                  ),
                  _buildImportMenu(label: 'Import protocol'),
                ],
              ),
            ],
          ),
        );
      }
      return _refreshableEmpty(
        isTemplate ? 'No templates found.' : 'No protocols found.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredProtocols.length,
        itemBuilder: (context, index) {
          final protocol = filteredProtocols[index];
          void openDetail() => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProtocolDetailScreen(protocol: protocol),
            ),
          ).then((_) => _loadData());
          return ProtocolSummaryCard(
            protocol: protocol,
            type: isTemplate
                ? ProtocolSummaryType.template
                : ProtocolSummaryType.protocol,
            project: _projectFor(protocol.projectId),
            syncStatus: protocol.syncStatus,
            publicationStatus: protocol.publication?.status,
            actionLabel: isTemplate ? 'Use template' : 'Run protocol',
            onAction: isTemplate
                ? () => _useTemplate(protocol)
                : () => _runProtocol(protocol),
            onTap: openDetail,
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

  Future<void> _useTemplate(Protocol template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProtocolScreen(initialProtocol: template),
      ),
    );
    await _loadData();
  }

  Future<void> _runProtocol(Protocol protocol) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RunProtocolScreen(protocol: protocol)),
    );
    await _refreshData();
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

  Widget _buildLibraryControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProtocolFlowSearchField(
            controller: _searchController,
            hintText: 'Search protocols...',
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildProjectFilter(),
              const Spacer(),
              PopupMenuButton<_LibraryDateSort>(
                tooltip: 'Sort by date',
                initialValue: _dateSort,
                onSelected: (value) => setState(() => _dateSort = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _LibraryDateSort.newestFirst,
                    child: ListTile(
                      leading: Icon(Icons.arrow_downward),
                      title: Text('Date (descending)'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _LibraryDateSort.oldestFirst,
                    child: ListTile(
                      leading: Icon(Icons.arrow_upward),
                      title: Text('Date (ascending)'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                child: const ProtocolFlowFilterPill(
                  icon: Icons.swap_vert,
                  label: 'Sort',
                  showDropdown: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectFilter() {
    final project = _selectedProject();
    final color = project == null
        ? AppColors.primary
        : Color(project.colorValue);

    return PopupMenuButton<String>(
      tooltip: 'Filter by project',
      initialValue: _selectedProjectId ?? _allProjectsFilter,
      onSelected: (value) => setState(
        () => _selectedProjectId = value == _allProjectsFilter ? null : value,
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
      child: ProtocolFlowFilterPill(
        icon: _projectFilterIcon(),
        iconColor: color,
        label: _selectedProjectId == null ? 'Project' : _projectFilterLabel(),
      ),
    );
  }

  bool _matchesSearch(String title, [String? secondary, String? tertiary]) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      title,
      secondary ?? '',
      tertiary ?? '',
    ].any((value) => value.toLowerCase().contains(query));
  }

  int _compareDates(DateTime a, DateTime b) {
    return _dateSort == _LibraryDateSort.newestFirst
        ? b.compareTo(a)
        : a.compareTo(b);
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
    final filteredRuns =
        protocolRuns
            .where((run) => run.status != ProtocolRunStatus.completed)
            .where((run) => _matchesSelectedProject(run.protocolSnapshot))
            .where((run) => _matchesSearch(run.protocolSnapshot.title))
            .toList()
          ..sort((a, b) => _compareDates(a.startedAt, b.startedAt));
    if (filteredRuns.isEmpty) {
      return _refreshableEmpty('No protocols currently running.');
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemCount: filteredRuns.length,
        itemBuilder: (context, index) {
          final run = filteredRuns[index];
          return run.status == ProtocolRunStatus.running
              ? _buildActiveProtocolItem(run.toActiveProtocol())
              : _buildRunningProtocolItem(run.toActiveProtocol());
        },
      ),
    );
  }

  Widget _buildActiveProtocolItem(ActiveProtocol state) {
    final protocol = state.protocol;
    final currentIdx = state.currentStepIndex;
    String status = 'Preparing';
    if (currentIdx >= 0 && currentIdx < protocol.steps.length) {
      final step = protocol.steps[currentIdx];
      status = 'Step ${currentIdx + 1}: ${step.title}';
      if (step.phaseName != null && step.phaseName!.isNotEmpty) {
        status = '${step.phaseName} - $status';
      }
    }

    final totalSteps = protocol.steps.length;
    final completedCount = state.completedStepIds.length;
    return RunningProtocolSummaryCard(
      state: state,
      detail: status,
      progressValue: '$completedCount of $totalSteps steps',
      project: _projectFor(protocol.projectId),
      phaseKeyPrefix: 'active-library',
      compact: true,
      paused: false,
      compactActionLabel: 'Resume',
      onCompactAction: () => _openRunningDetail(state),
      onTerminate: () => _confirmRemoveRunningProtocol(state),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ProtocolDetailScreen(protocol: protocol, activeState: state),
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
      compact: true,
      paused: true,
      compactActionLabel: 'Resume',
      onCompactAction: () => _openRunningDetail(runningState),
      onTerminate: () => _confirmRemoveRunningProtocol(runningState),
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

  Future<void> _openRunningDetail(ActiveProtocol state) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProtocolDetailScreen(protocol: state.protocol, activeState: state),
      ),
    );
    await _refreshData();
  }

  void _confirmRemoveRunningProtocol(ActiveProtocol state) {
    final isActive = protocolRuns.any(
      (run) => run.id == state.runId && run.status == ProtocolRunStatus.running,
    );
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
              final runId = state.runId;
              if (runId != null) {
                await ProtocolRunService.instance.discardRun(runId);
                await loadPersistentProtocols();
              } else {
                discardProtocolSession(state.protocol.id);
                await savePersistentProtocols();
              }
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
    final filteredCompleted =
        protocolRuns
            .where((run) => run.status == ProtocolRunStatus.completed)
            .where((run) => _matchesSelectedProject(run.protocolSnapshot))
            .where((run) => _matchesSearch(run.protocolSnapshot.title))
            .toList()
          ..sort(
            (a, b) => _compareDates(
              a.completedAt ?? a.updatedAt,
              b.completedAt ?? b.updatedAt,
            ),
          );

    if (filteredCompleted.isEmpty) {
      return _refreshableEmpty('No completed protocols found.');
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredCompleted.length,
        itemBuilder: (context, index) {
          final run = filteredCompleted[index];
          final completed = run.toCompletedProtocol();
          void review() => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CompletedProtocolDetailScreen.fromRun(run: run),
            ),
          ).then((_) => setState(() {}));
          return ProtocolSummaryCard(
            protocol: completed.protocol,
            type: ProtocolSummaryType.completed,
            project: _projectFor(completed.protocol.projectId),
            startedAt: completed.startedAt,
            completedAt: completed.completedAt,
            syncStatus: completed.syncStatus,
            publicationStatus: completed.protocol.publication?.status,
            actionLabel: 'Review',
            onAction: review,
            onTap: review,
          );
        },
      ),
    );
  }
}

enum _LibraryImportOption { file, qrCode }

enum _LibraryDateSort { newestFirst, oldestFirst }

enum LibraryEntryType { template, protocol, running, completed }

class LibraryEntryCard extends StatelessWidget {
  const LibraryEntryCard({
    super.key,
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
    this.publicationStatus,
  });

  final String entryId;
  final String title;
  final LibraryEntryType type;
  final String firstLabel;
  final String firstValue;
  final String secondLabel;
  final String secondValue;
  final Widget projectChip;
  final ProtocolSyncStatus? syncStatus;
  final ProtocolPublicationStatus? publicationStatus;
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
        if (publicationStatus != null)
          PublicationStatusChip(
            key: Key('library-publication-badge-$entryId'),
            status: publicationStatus!,
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

  final LibraryEntryType type;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (type) {
      LibraryEntryType.template => (
        'TEMPLATE',
        Icons.copy_all_outlined,
        AppColors.aiPrimary,
      ),
      LibraryEntryType.protocol => (
        'PROTOCOL',
        Icons.article_outlined,
        AppColors.primary,
      ),
      LibraryEntryType.running => (
        'RUNNING',
        Icons.play_circle_outline,
        AppColors.info,
      ),
      LibraryEntryType.completed => (
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
