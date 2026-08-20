import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../models/protocol_run.dart';
import '../models/task.dart';
import '../data/completed_protocols_data.dart';
import '../services/storage_service.dart';
import '../features/today_tasks/services/task_service.dart';
import '../theme/app_colors.dart';
import '../widgets/protocolflow_ui.dart';
import 'library_screen.dart';
import 'saved_tables_screen.dart';
import 'tasks_screen.dart';

class ProjectsScreen extends StatefulWidget {
  final bool embedded;
  final void Function(String? projectId)? onProjectSelected;
  final void Function(String? projectId)? onTasksSelected;
  final void Function(int tabIndex, String? projectId)? onProtocolSelected;
  final void Function(String? projectId)? onTablesSelected;
  final bool createOnOpen;
  final VoidCallback? onCreatePromptShown;

  const ProjectsScreen({
    super.key,
    this.embedded = false,
    this.onProjectSelected,
    this.onTasksSelected,
    this.onProtocolSelected,
    this.onTablesSelected,
    this.createOnOpen = false,
    this.onCreatePromptShown,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  static const String _unassignedFilterId = '__unassigned__';

  final StorageService _storageService = StorageService();
  final TaskService _taskService = TaskService();
  List<Project> _projects = [];
  List<Protocol> _protocols = [];
  List<Task> _tasks = [];
  List<ProtocolTable> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCreatePromptShown?.call();
        _createProject();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final values = await Future.wait([
      _storageService.loadProjects(),
      _storageService.loadProtocols(),
      _taskService.loadTodayTasks(),
      _storageService.loadSavedTables(),
      loadPersistentProtocols(),
    ]);
    if (!mounted) return;
    setState(() {
      _projects = values[0] as List<Project>;
      _protocols = values[1] as List<Protocol>;
      _tasks = values[2] as List<Task>;
      _tables = values[3] as List<ProtocolTable>;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ProtocolFlowScreenHeader(
                        title: 'Projects',
                        subtitle:
                            'Workspaces for research activities and experiment areas',
                        actions: [
                          FilledButton.icon(
                            key: const Key('projects-create-button'),
                            onPressed: _createProject,
                            icon: const Icon(Icons.add),
                            label: const Text('New Project'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 560,
                          mainAxisExtent: 330,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    delegate: SliverChildListDelegate([
                      _buildUnassignedCard(),
                      ..._projects.map(_buildProjectCard),
                    ]),
                  ),
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Scaffold(body: ProtocolFlowContentBoundary(child: body));
    }

    return Scaffold(
      body: SafeArea(child: ProtocolFlowContentBoundary(child: body)),
    );
  }

  Widget _buildUnassignedCard() {
    final counts = _countsFor(null);
    return _ProjectWorkspaceCard(
      projectKey: _unassignedFilterId,
      icon: Icons.folder_off_outlined,
      color: Colors.grey,
      title: 'Unassigned',
      description: 'Work that has not been assigned to a project.',
      counts: counts,
      onOpenTasks: () => _openTasks(_unassignedFilterId),
      onOpenProtocolType: (tabIndex) =>
          _openProtocolType(tabIndex, _unassignedFilterId),
      onOpenTables: () => _openTables(_unassignedFilterId),
    );
  }

  Widget _buildProjectCard(Project project) {
    final counts = _countsFor(project.id);
    return _ProjectWorkspaceCard(
      projectKey: project.id,
      icon: Icons.folder_outlined,
      color: Color(project.colorValue),
      title: project.name,
      description: project.description.trim(),
      counts: counts,
      trailing: PopupMenuButton<String>(
        tooltip: 'Project options',
        onSelected: (value) {
          if (value == 'rename') _renameProject(project);
          if (value == 'delete') _confirmDeleteProject(project);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Rename'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete project'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onOpenTasks: () => _openTasks(project.id),
      onOpenProtocolType: (tabIndex) => _openProtocolType(tabIndex, project.id),
      onOpenTables: () => _openTables(project.id),
    );
  }

  ({
    int protocols,
    int templates,
    int tasks,
    int tables,
    int running,
    int completed,
  })
  _countsFor(String? projectId) {
    var protocols = 0;
    var templates = 0;
    for (final protocol in _protocols) {
      final assigned = protocol.projectId;
      final matches = projectId == null
          ? assigned == null ||
                assigned.isEmpty ||
                !_projects.any((project) => project.id == assigned)
          : assigned == projectId;
      if (!matches) continue;
      if (protocol.isTemplate) {
        templates++;
      } else {
        protocols++;
      }
    }
    bool matches(String? assigned) => projectId == null
        ? assigned == null ||
              assigned.isEmpty ||
              !_projects.any((project) => project.id == assigned)
        : assigned == projectId;
    final tasks = _tasks.where((task) => matches(task.projectId)).length;
    final tables = _tables.where((table) => matches(table.projectId)).length;
    final running = protocolRuns
        .where(
          (run) =>
              run.status != ProtocolRunStatus.completed &&
              matches(run.projectId),
        )
        .length;
    final completed = protocolRuns
        .where(
          (run) =>
              run.status == ProtocolRunStatus.completed &&
              matches(run.projectId),
        )
        .length;
    return (
      protocols: protocols,
      templates: templates,
      tasks: tasks,
      tables: tables,
      running: running,
      completed: completed,
    );
  }

  Future<void> _openTasks(String? projectId) async {
    if (widget.onTasksSelected != null) {
      widget.onTasksSelected!(projectId);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TasksScreen(initialProjectId: projectId),
      ),
    );
    await _loadData();
  }

  Future<void> _openProtocolType(int tabIndex, String? projectId) async {
    if (widget.onProtocolSelected != null) {
      widget.onProtocolSelected!(tabIndex, projectId);
      return;
    }
    if (widget.onProjectSelected != null) {
      widget.onProjectSelected!(projectId);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LibraryScreen(
          initialTabIndex: tabIndex,
          initialProjectId: projectId,
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _openTables(String? projectId) async {
    if (widget.onTablesSelected != null) {
      widget.onTablesSelected!(projectId);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SavedTablesScreen(initialProjectId: projectId),
      ),
    );
    await _loadData();
  }

  Future<void> _createProject() async {
    await _editProjectName();
  }

  Future<void> _renameProject(Project project) async {
    await _editProjectName(project: project);
  }

  Future<void> _editProjectName({Project? project}) async {
    final controller = TextEditingController(text: project?.name ?? '');
    final descriptionController = TextEditingController(
      text: project?.description ?? '',
    );
    var selectedColor = Color(
      project?.colorValue ?? AppColors.primary.toARGB32(),
    );
    try {
      final result = await showDialog<_ProjectEditResult>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(project == null ? 'New Project' : 'Edit Project'),
            content: _ProjectEditorFields(
              controller: controller,
              descriptionController: descriptionController,
              selectedColor: selectedColor,
              onColorChanged: (color) =>
                  setDialogState(() => selectedColor = color),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _ProjectEditResult(
                    name: controller.text.trim(),
                    description: descriptionController.text.trim(),
                    color: selectedColor,
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (result == null || result.name.isEmpty) return;
      final name = result.name;
      final lowerName = name.toLowerCase();
      final duplicate = _projects.any(
        (item) =>
            item.id != project?.id && item.name.toLowerCase() == lowerName,
      );
      if (duplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A project with this name exists.')),
        );
        return;
      }

      final saved = project == null
          ? Project(
              id: 'project_${DateTime.now().microsecondsSinceEpoch}',
              name: name,
              description: result.description,
              colorValue: result.color.toARGB32(),
            )
          : project.copyWith(
              name: name,
              description: result.description,
              colorValue: result.color.toARGB32(),
              updatedAt: DateTime.now(),
            );
      await _storageService.upsertProject(saved);
      await _loadData();
    } finally {
      controller.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _confirmDeleteProject(Project project) async {
    final counts = _countsFor(project.id);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
          'This will keep ${counts.protocols + counts.templates} protocol item(s). Assigned protocols, tasks, and saved tables will move to Unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await _storageService.deleteProject(project.id);
    await _taskService.unassignProject(project.id);
    await _loadData();
  }
}

class _ProjectWorkspaceCard extends StatelessWidget {
  final String projectKey;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final ({
    int protocols,
    int templates,
    int tasks,
    int tables,
    int running,
    int completed,
  })
  counts;
  final Widget? trailing;
  final VoidCallback onOpenTasks;
  final ValueChanged<int> onOpenProtocolType;
  final VoidCallback onOpenTables;

  const _ProjectWorkspaceCard({
    required this.projectKey,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.counts,
    this.trailing,
    required this.onOpenTasks,
    required this.onOpenProtocolType,
    required this.onOpenTables,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('project-card-$projectKey'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(icon, size: 30, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 38,
                        child: Text(
                          description.isEmpty
                              ? 'No project description'
                              : description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const Divider(height: 12),
            _ProjectCategoryRow(
              key: Key('project-$projectKey-tasks'),
              icon: Icons.checklist_outlined,
              label: 'Tasks',
              count: counts.tasks,
              onTap: onOpenTasks,
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Protocols',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${counts.templates + counts.protocols + counts.running + counts.completed}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.outline),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _ProtocolTypeAction(
                    key: Key('project-$projectKey-templates'),
                    icon: Icons.copy_all_outlined,
                    label: 'Templates',
                    count: counts.templates,
                    color: AppColors.textSecondary,
                    onTap: () => onOpenProtocolType(0),
                  ),
                  _ProtocolTypeAction(
                    key: Key('project-$projectKey-protocols'),
                    icon: Icons.description_outlined,
                    label: 'Protocols',
                    count: counts.protocols,
                    color: AppColors.primary,
                    onTap: () => onOpenProtocolType(1),
                  ),
                  _ProtocolTypeAction(
                    key: Key('project-$projectKey-running'),
                    icon: Icons.play_circle_outline,
                    label: 'Running',
                    count: counts.running,
                    color: AppColors.info,
                    onTap: () => onOpenProtocolType(2),
                  ),
                  _ProtocolTypeAction(
                    key: Key('project-$projectKey-completed'),
                    icon: Icons.check_circle_outline,
                    label: 'Completed',
                    count: counts.completed,
                    color: AppColors.success,
                    onTap: () => onOpenProtocolType(3),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _ProjectCategoryRow(
              key: Key('project-$projectKey-tables'),
              icon: Icons.table_chart_outlined,
              label: 'Tables',
              count: counts.tables,
              onTap: onOpenTables,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCategoryRow extends StatelessWidget {
  const _ProjectCategoryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _ProtocolTypeAction extends StatelessWidget {
  const _ProtocolTypeAction({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectEditResult {
  final String name;
  final String description;
  final Color color;

  const _ProjectEditResult({
    required this.name,
    required this.description,
    required this.color,
  });
}

class _ProjectEditorFields extends StatelessWidget {
  static const _colors = [
    AppColors.primary,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.blueGrey,
  ];

  final TextEditingController controller;
  final TextEditingController descriptionController;
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  const _ProjectEditorFields({
    required this.controller,
    required this.descriptionController,
    required this.selectedColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
          ),
        ),
        const SizedBox(height: 18),
        const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in _colors)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onColorChanged(color),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == color
                          ? Colors.black87
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: selectedColor == color
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
