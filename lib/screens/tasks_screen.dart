import 'package:flutter/material.dart';

import '../features/today_tasks/services/task_service.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/protocolflow_ui.dart';

enum _TaskView { active, archive }

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onChanged,
    this.initialProjectId,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onChanged;
  final String? initialProjectId;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  static const _unassignedProject = '__unassigned__';

  final TaskService _taskService = TaskService();
  final StorageService _storageService = StorageService();
  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;
  List<Task> _activeTasks = [];
  List<Task> _archivedTasks = [];
  List<Project> _projects = [];
  bool _loading = true;
  bool _sortNewestFirst = false;
  String? _projectFilter;

  @override
  void initState() {
    super.initState();
    _projectFilter = widget.initialProjectId;
    _tabController = TabController(length: _TaskView.values.length, vsync: this)
      ..addListener(_handleTabChanged);
    _searchController.addListener(_handleSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    final values = await Future.wait([
      _taskService.loadTodayTasks(),
      _taskService.loadHistoryTasks(),
      _storageService.loadProjects(),
    ]);
    if (!mounted) return;
    setState(() {
      _activeTasks = values[0] as List<Task>;
      _archivedTasks = values[1] as List<Task>;
      _projects = values[2] as List<Project>;
      _loading = false;
    });
  }

  Future<void> _notifyChanged() async {
    await _loadData();
    widget.onChanged?.call();
  }

  _TaskView get _selectedView => _TaskView.values[_tabController.index];

  List<Task> get _visibleTasks {
    final source = _selectedView == _TaskView.archive
        ? _archivedTasks
        : _activeTasks;
    final query = _searchController.text.trim().toLowerCase();
    final tasks = source.where((task) {
      final matchesProject = switch (_projectFilter) {
        null => true,
        _unassignedProject => task.projectId == null || task.projectId!.isEmpty,
        final projectId => task.projectId == projectId,
      };
      if (!matchesProject) return false;
      if (query.isEmpty) return true;
      final projectName = _projectFor(task.projectId)?.name ?? '';
      return task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query) ||
          projectName.toLowerCase().contains(query);
    }).toList();
    tasks.sort(
      (a, b) => _sortNewestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: !widget.embedded,
      child: ProtocolFlowContentBoundary(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildTabs(),
              const SizedBox(height: 20),
              _buildSearch(),
              const SizedBox(height: 14),
              _buildFilters(),
              const SizedBox(height: 22),
              Expanded(child: _buildTaskList()),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(body: content);
  }

  Widget _buildHeader() {
    return ProtocolFlowScreenHeader(
      title: 'Tasks',
      onBack: widget.onBack,
      actions: [
        FilledButton.icon(
          key: const Key('tasks-create-button'),
          onPressed: () => _showTaskEditor(),
          icon: const Icon(Icons.add),
          label: const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return ProtocolFlowTabBar(
      controller: _tabController,
      tabs: const [
        Tab(key: Key('tasks-tab-active'), text: 'Active'),
        Tab(key: Key('tasks-tab-archive'), text: 'Archive'),
      ],
    );
  }

  Widget _buildSearch() {
    return ProtocolFlowSearchField(
      fieldKey: const Key('tasks-search-field'),
      controller: _searchController,
      hintText: 'Search tasks...',
    );
  }

  Widget _buildFilters() {
    final completedCount = _activeTasks
        .where(
          (task) =>
              task.status == TaskStatus.completed && _matchesProject(task),
        )
        .length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<String>(
          key: const Key('home-task-project-filter'),
          tooltip: 'Filter tasks by project',
          initialValue: _projectFilter ?? '__all__',
          onSelected: (value) => setState(
            () => _projectFilter = value == '__all__' ? null : value,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: '__all__',
              child: ListTile(
                leading: Icon(Icons.all_inbox_outlined),
                title: Text('All projects'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: _unassignedProject,
              child: ListTile(
                leading: Icon(Icons.folder_off_outlined),
                title: Text('Unassigned'),
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
          ],
          child: ProtocolFlowFilterPill(
            icon: Icons.folder_outlined,
            label: _projectFilterLabel,
          ),
        ),
        PopupMenuButton<bool>(
          key: const Key('tasks-sort-button'),
          tooltip: 'Sort tasks',
          initialValue: _sortNewestFirst,
          onSelected: (value) => setState(() => _sortNewestFirst = value),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: false,
              child: ListTile(
                leading: Icon(Icons.arrow_upward),
                title: Text('Oldest first'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: true,
              child: ListTile(
                leading: Icon(Icons.arrow_downward),
                title: Text('Newest first'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          child: ProtocolFlowFilterPill(
            icon: Icons.swap_vert,
            label: _sortNewestFirst ? 'Newest' : 'Oldest',
            showDropdown: false,
          ),
        ),
        if (_selectedView == _TaskView.active && completedCount > 0)
          TextButton.icon(
            key: const Key('home-archive-completed-tasks'),
            onPressed: _archiveVisibleCompleted,
            icon: const Icon(Icons.archive_outlined),
            label: Text('Archive all ($completedCount)'),
          ),
      ],
    );
  }

  Widget _buildTaskList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final tasks = _visibleTasks;
    if (tasks.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _TaskSummaryCard(
          key: Key('task-card-${tasks[index].id}'),
          task: tasks[index],
          project: _projectFor(tasks[index].projectId),
          archived: _selectedView == _TaskView.archive,
          onTap: () => _showTaskEditor(
            task: tasks[index],
            archived: _selectedView == _TaskView.archive,
          ),
          onPrimaryAction: () => _runPrimaryAction(tasks[index]),
          onDelete: () => _deleteTask(
            tasks[index],
            archived: _selectedView == _TaskView.archive,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = switch (_selectedView) {
      _TaskView.active => 'No active tasks.',
      _TaskView.archive => 'Archive is empty.',
    };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        SizedBox(height: 240, child: ProtocolFlowEmptyState(message: message)),
      ],
    );
  }

  Future<void> _runPrimaryAction(Task task) async {
    if (_selectedView == _TaskView.archive) {
      await _taskService.restoreTasks([task.id]);
      await _notifyChanged();
      return;
    }
    if (task.status == TaskStatus.completed) {
      await _taskService.archiveTasks([task.id]);
      await _notifyChanged();
      return;
    }
    final status = task.status == TaskStatus.notStarted
        ? TaskStatus.inProgress
        : TaskStatus.completed;
    final updated = task.copyWith(
      status: status,
      completedAt: status == TaskStatus.completed ? DateTime.now() : null,
    );
    await _replaceTask(updated, archived: false);
  }

  Future<void> _archiveVisibleCompleted() async {
    final ids = _activeTasks
        .where(
          (task) =>
              task.status == TaskStatus.completed && _matchesProject(task),
        )
        .map((task) => task.id);
    await _taskService.archiveTasks(ids);
    await _notifyChanged();
  }

  Future<void> _replaceTask(Task updated, {required bool archived}) async {
    final tasks = archived
        ? List<Task>.from(_archivedTasks)
        : List<Task>.from(_activeTasks);
    final index = tasks.indexWhere((task) => task.id == updated.id);
    if (index == -1) return;
    tasks[index] = updated;
    if (archived) {
      await _taskService.saveHistoryTasks(tasks);
    } else {
      await _taskService.saveTodayTasks(tasks);
    }
    await _notifyChanged();
  }

  Future<void> _deleteTask(Task task, {required bool archived}) async {
    final tasks = archived
        ? List<Task>.from(_archivedTasks)
        : List<Task>.from(_activeTasks);
    tasks.removeWhere((item) => item.id == task.id);
    if (archived) {
      await _taskService.saveHistoryTasks(tasks);
    } else {
      await _taskService.saveTodayTasks(tasks);
    }
    await _notifyChanged();
  }

  Future<void> _showTaskEditor({Task? task, bool archived = false}) async {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    var selectedProject = task?.projectId ?? _unassignedProject;
    var selectedStatus = task?.status ?? TaskStatus.notStarted;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(task == null ? 'Create task' : 'Edit task'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('task-title-field'),
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Task title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedProject,
                    decoration: const InputDecoration(labelText: 'Project'),
                    items: [
                      const DropdownMenuItem(
                        value: _unassignedProject,
                        child: Text('Unassigned'),
                      ),
                      for (final project in _projects)
                        DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name),
                        ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => selectedProject = value ?? _unassignedProject,
                    ),
                  ),
                  if (!archived) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TaskStatus>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: TaskStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => selectedStatus = value ?? selectedStatus,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final projectId = selectedProject == _unassignedProject
        ? null
        : selectedProject;
    if (task == null) {
      final created = Task(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        status: selectedStatus,
        createdAt: DateTime.now(),
        completedAt: selectedStatus == TaskStatus.completed
            ? DateTime.now()
            : null,
        projectId: projectId,
      );
      await _taskService.saveTodayTasks([..._activeTasks, created]);
    } else {
      final updated = task.copyWith(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        status: selectedStatus,
        projectId: projectId,
        clearProjectId: projectId == null,
        completedAt: selectedStatus == TaskStatus.completed
            ? task.completedAt ?? DateTime.now()
            : null,
      );
      await _replaceTask(updated, archived: archived);
      return;
    }
    await _notifyChanged();
  }

  bool _matchesProject(Task task) {
    if (_projectFilter == null) return true;
    if (_projectFilter == _unassignedProject) {
      return task.projectId == null || task.projectId!.isEmpty;
    }
    return task.projectId == _projectFilter;
  }

  Project? _projectFor(String? projectId) {
    if (projectId == null || projectId.isEmpty) return null;
    for (final project in _projects) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  String get _projectFilterLabel {
    if (_projectFilter == null) return 'Project';
    if (_projectFilter == _unassignedProject) return 'Unassigned';
    return _projectFor(_projectFilter)?.name ?? 'Project';
  }
}

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({
    super.key,
    required this.task,
    required this.project,
    required this.archived,
    required this.onTap,
    required this.onPrimaryAction,
    required this.onDelete,
  });

  final Task task;
  final Project? project;
  final bool archived;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final projectColor = project == null
        ? AppColors.textSecondary
        : Color(project!.colorValue);
    final statusColor = archived
        ? AppColors.textSecondary
        : _statusColor(task.status);
    final statusIcon = archived
        ? Icons.archive_outlined
        : _statusIcon(task.status);
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(task.createdAt);
    final statusLabel = archived ? 'Archived' : _statusLabel(task.status);

    return ProtocolFlowEntityCard(
      margin: EdgeInsets.zero,
      icon: statusIcon,
      iconColor: projectColor,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key(
              archived
                  ? 'restore-task-${task.id}'
                  : task.status == TaskStatus.completed
                  ? 'archive-task-${task.id}'
                  : 'advance-task-${task.id}',
            ),
            tooltip: archived
                ? 'Restore task'
                : task.status == TaskStatus.notStarted
                ? 'Start task'
                : task.status == TaskStatus.inProgress
                ? 'Complete task'
                : 'Archive task',
            onPressed: onPrimaryAction,
            icon: Icon(
              archived
                  ? Icons.restore
                  : task.status == TaskStatus.notStarted
                  ? Icons.play_arrow
                  : task.status == TaskStatus.inProgress
                  ? Icons.check
                  : Icons.archive_outlined,
              color: AppColors.primary,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Task options',
            onSelected: (value) {
              if (value == 'edit') onTap();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit task'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.error),
                  title: Text('Delete task'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (task.description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (project != null)
                Text(
                  project!.name,
                  style: TextStyle(
                    color: projectColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                'Created $date',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _statusLabel(TaskStatus status) {
  return switch (status) {
    TaskStatus.notStarted => 'Not started',
    TaskStatus.inProgress => 'In progress',
    TaskStatus.completed => 'Completed',
  };
}

IconData _statusIcon(TaskStatus status) {
  return switch (status) {
    TaskStatus.notStarted => Icons.radio_button_unchecked,
    TaskStatus.inProgress => Icons.play_circle_outline,
    TaskStatus.completed => Icons.check_circle_outline,
  };
}

Color _statusColor(TaskStatus status) {
  return switch (status) {
    TaskStatus.notStarted => AppColors.textSecondary,
    TaskStatus.inProgress => AppColors.info,
    TaskStatus.completed => AppColors.success,
  };
}
