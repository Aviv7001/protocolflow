import 'package:flutter/material.dart';

import '../models/protocol_table.dart';
import '../services/storage_service.dart';
import '../widgets/protocol_table_widget.dart';
import '../theme/app_colors.dart';
import '../widgets/protocolflow_ui.dart';
import '../models/project.dart';
import 'table_selection_screen.dart';
import '../widgets/project_assignment_menu.dart';
import '../utils/date_time_format.dart';

class SavedTablesScreen extends StatefulWidget {
  final bool embedded;
  final String? initialProjectId;
  final VoidCallback? onBack;

  const SavedTablesScreen({
    super.key,
    this.embedded = false,
    this.initialProjectId,
    this.onBack,
  });

  @override
  State<SavedTablesScreen> createState() => _SavedTablesScreenState();
}

class _SavedTablesScreenState extends State<SavedTablesScreen> {
  static const _allProjects = '__all__';
  static const _unassignedProject = '__unassigned__';
  final StorageService _storageService = StorageService();
  final TextEditingController _searchController = TextEditingController();
  List<ProtocolTable> _tables = [];
  List<Project> _projects = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedProjectId;
  TableType? _selectedType;
  _SavedTableSort _sort = _SavedTableSort.newestFirst;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    _loadTables();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _storageService.loadSavedTables(),
      _storageService.loadProjects(),
    ]);
    final tables = results[0] as List<ProtocolTable>;
    final projects = results[1] as List<Project>;
    if (!mounted) return;
    setState(() {
      _tables = tables;
      _projects = projects;
      _isLoading = false;
    });
  }

  Future<void> _openLabTools() async {
    await showTableToolPicker(context, standaloneMode: true);
    if (mounted) _loadTables();
  }

  Future<void> _saveUpdatedTable(ProtocolTable table) async {
    await _storageService.upsertSavedTable(table);
    await _loadTables();
  }

  Future<void> _assignProject(ProtocolTable table, String? projectId) async {
    await _storageService.upsertSavedTable(
      projectId == null
          ? table.copyWith(clearProjectId: true)
          : table.copyWith(projectId: projectId),
    );
    await _loadTables();
  }

  Future<void> _createProjectForTable(ProtocolTable table) async {
    final details = await showNewProjectDialog(context);
    if (details == null || !mounted) return;
    for (final existing in _projects) {
      if (existing.name.toLowerCase() == details.name.toLowerCase()) {
        await _assignProject(table, existing.id);
        return;
      }
    }
    final project = Project(
      id: 'project_${DateTime.now().microsecondsSinceEpoch}',
      name: details.name,
      colorValue: details.color.toARGB32(),
    );
    await _storageService.upsertProject(project);
    await _assignProject(table, project.id);
  }

  Project? _projectFor(String? projectId) {
    if (projectId == null || projectId.isEmpty) return null;
    for (final project in _projects) {
      if (project.id == projectId) return project;
    }
    return null;
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
    final visibleTables = _visibleTables;
    return Scaffold(
      body: SafeArea(
        top: !widget.embedded,
        child: ProtocolFlowContentBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildControls(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadTables,
                        child: visibleTables.isEmpty
                            ? _buildEmptyState()
                            : _buildTableList(visibleTables),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ProtocolTable> get _visibleTables {
    final query = _searchQuery.trim().toLowerCase();
    final tables = _tables.where((table) {
      final projectId = _selectedProjectId;
      if (projectId == _unassignedProject &&
          table.projectId != null &&
          table.projectId!.isNotEmpty) {
        return false;
      }
      if (projectId != null &&
          projectId != _unassignedProject &&
          table.projectId != projectId) {
        return false;
      }
      if (_selectedType != null && table.type != _selectedType) return false;
      if (query.isEmpty) return true;
      final projectName = _projectFor(table.projectId)?.name ?? '';
      return table.title.toLowerCase().contains(query) ||
          _typeLabel(table.type).toLowerCase().contains(query) ||
          projectName.toLowerCase().contains(query);
    }).toList();

    tables.sort((a, b) {
      if (_sort == _SavedTableSort.title) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      final aDate = _createdAtFor(a);
      final bDate = _createdAtFor(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return _sort == _SavedTableSort.newestFirst
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });
    return tables;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: ProtocolFlowScreenHeader(
        title: 'Saved Tables',
        onBack:
            widget.onBack ??
            (Navigator.canPop(context) ? () => Navigator.pop(context) : null),
        actions: [
          FilledButton.icon(
            key: const Key('saved-tables-create'),
            onPressed: _openLabTools,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProtocolFlowSearchField(
            fieldKey: const Key('saved-tables-search'),
            controller: _searchController,
            hintText: 'Search saved tables...',
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildProjectFilter(),
              _buildTypeFilter(),
              _buildSortControl(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectFilter() {
    final project = _projectFor(_selectedProjectId);
    final color = project == null
        ? AppColors.primary
        : Color(project.colorValue);
    return PopupMenuButton<String>(
      key: const Key('saved-tables-project-filter'),
      tooltip: 'Filter by project',
      initialValue: _selectedProjectId ?? _allProjects,
      onSelected: (value) => setState(
        () => _selectedProjectId = value == _allProjects ? null : value,
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _allProjects,
          child: ListTile(
            leading: Icon(Icons.all_inbox_outlined),
            title: Text('All projects'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        for (final project in _projects)
          PopupMenuItem(
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
        const PopupMenuItem(
          value: _unassignedProject,
          child: ListTile(
            leading: Icon(Icons.folder_off_outlined),
            title: Text('Unassigned'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: _filterButton(
        icon: project == null ? Icons.folder_outlined : Icons.folder,
        iconColor: color,
        label:
            project?.name ??
            (_selectedProjectId == _unassignedProject
                ? 'Unassigned'
                : 'Project'),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return PopupMenuButton<String>(
      key: const Key('saved-tables-type-filter'),
      tooltip: 'Filter by table type',
      initialValue: _selectedType?.name ?? '__all_types__',
      onSelected: (value) => setState(
        () => _selectedType = value == '__all_types__'
            ? null
            : TableType.values.byName(value),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: '__all_types__',
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text('All table types'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        for (final type in TableType.values)
          PopupMenuItem<String>(
            value: type.name,
            child: ListTile(
              leading: Icon(_typeIcon(type), color: AppColors.primary),
              title: Text(_typeLabel(type)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
      child: _filterButton(
        icon: _selectedType == null
            ? Icons.category_outlined
            : _typeIcon(_selectedType!),
        label: _selectedType == null
            ? 'Table type'
            : _typeLabel(_selectedType!),
      ),
    );
  }

  Widget _buildSortControl() {
    return PopupMenuButton<_SavedTableSort>(
      key: const Key('saved-tables-sort'),
      tooltip: 'Sort saved tables',
      initialValue: _sort,
      onSelected: (value) => setState(() => _sort = value),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _SavedTableSort.newestFirst,
          child: ListTile(
            leading: Icon(Icons.arrow_downward),
            title: Text('Date (descending)'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _SavedTableSort.oldestFirst,
          child: ListTile(
            leading: Icon(Icons.arrow_upward),
            title: Text('Date (ascending)'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _SavedTableSort.title,
          child: ListTile(
            leading: Icon(Icons.sort_by_alpha),
            title: Text('Title (A-Z)'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: const ProtocolFlowFilterPill(
        icon: Icons.swap_vert,
        label: 'Sort',
        showDropdown: false,
      ),
    );
  }

  Widget _filterButton({
    required IconData icon,
    required String label,
    Color iconColor = AppColors.textPrimary,
  }) {
    return ProtocolFlowFilterPill(
      icon: icon,
      iconColor: iconColor,
      label: label,
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.trim().isNotEmpty ||
        _selectedType != null ||
        _selectedProjectId != null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 260,
          child: ProtocolFlowEmptyState(
            message: hasFilters
                ? 'No matching tables.'
                : 'No saved tables yet.',
          ),
        ),
      ],
    );
  }

  Widget _buildTableList(List<ProtocolTable> tables) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 28),
      itemCount: tables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final table = tables[index];
        final project = _projectFor(table.projectId);
        final projectColor = project == null
            ? AppColors.textSecondary
            : Color(project.colorValue);
        final createdAt = _createdAtFor(table);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ProtocolFlowEntityCard(
              key: Key('saved-table-card-${table.id}'),
              margin: EdgeInsets.zero,
              icon: _typeIcon(table.type),
              iconColor: projectColor,
              badgeKey: Key('saved-table-project-badge-${table.id}'),
              iconKey: Key('saved-table-type-icon-${table.id}'),
              onTap: () => ProtocolTableWidget.openTableViewer(
                context,
                table: table,
                isReadOnly: false,
                onSave: _saveUpdatedTable,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Table options',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') _confirmDelete(table);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          title: Text('Delete table'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.outline,
                    size: 28,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    table.title.isEmpty ? 'Untitled Table' : table.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeLabel(table.type),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    createdAt == null
                        ? 'Created date unavailable'
                        : 'Created on ${formatDate(createdAt)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ProjectAssignmentMenu(
                    projects: _projects,
                    selectedProjectId: project?.id,
                    onSelected: (projectId) => _assignProject(table, projectId),
                    onCreateProject: () => _createProjectForTable(table),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  DateTime? _createdAtFor(ProtocolTable table) {
    if (table.createdAt != null) return table.createdAt;
    final match = RegExp(r'\d{13}').firstMatch(table.id);
    if (match == null) return null;
    final milliseconds = int.tryParse(match.group(0)!);
    if (milliseconds == null) return null;
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final latestReasonableDate = DateTime.now().add(const Duration(days: 366));
    if (value.year < 2000 || value.isAfter(latestReasonableDate)) return null;
    return value;
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

  IconData _typeIcon(TableType type) {
    return switch (type) {
      TableType.masterMix => Icons.biotech_outlined,
      TableType.staining => Icons.color_lens_outlined,
      TableType.serialDilution => Icons.water_drop_outlined,
      TableType.plateLayout => Icons.grid_on_outlined,
      TableType.checklist => Icons.checklist_outlined,
      TableType.materialList => Icons.inventory_2_outlined,
      TableType.generic => Icons.table_chart_outlined,
    };
  }
}

enum _SavedTableSort { newestFirst, oldestFirst, title }
