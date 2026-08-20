import 'package:flutter/material.dart';

import '../data/completed_protocols_data.dart';
import '../features/today_tasks/services/task_service.dart';
import '../models/active_protocol.dart';
import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_run.dart';
import '../models/protocol_table.dart';
import '../models/task.dart';
import '../services/storage_service.dart';
import '../services/protocol_run_service.dart';
import '../theme/app_colors.dart';
import '../widgets/protocol_table_widget.dart';
import '../widgets/running_protocol_summary_card.dart';
import '../widgets/protocol_summary_card.dart';
import '../widgets/protocolflow_app_bar.dart';
import '../widgets/protocolflow_ui.dart';
import 'create_protocol_screen.dart';
import 'protocol_detail_screen.dart';
import 'protocols_screen.dart';
import 'run_protocol_screen.dart';
import 'table_selection_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final StorageService _storageService = StorageService();
  final TaskService _taskService = TaskService();
  late Project _project;
  List<Task> _tasks = const [];
  List<Protocol> _protocols = const [];
  List<ProtocolTable> _tables = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadData();
  }

  Future<void> _loadData() async {
    final values = await Future.wait([
      _taskService.loadTodayTasks(),
      _storageService.loadProtocols(),
      _storageService.loadSavedTables(),
      _storageService.loadProjects(),
      loadPersistentProtocols(),
    ]);
    if (!mounted) return;
    final projects = values[3] as List<Project>;
    setState(() {
      _project = projects.firstWhere(
        (item) => item.id == _project.id,
        orElse: () => _project,
      );
      _tasks = (values[0] as List<Task>)
          .where((task) => task.projectId == _project.id)
          .toList();
      _protocols = (values[1] as List<Protocol>)
          .where((protocol) => protocol.projectId == _project.id)
          .toList();
      _tables = (values[2] as List<ProtocolTable>)
          .where((table) => table.projectId == _project.id)
          .toList();
      _loading = false;
    });
  }

  List<ActiveProtocol> get _running {
    return protocolRuns
        .where(
          (run) =>
              run.status != ProtocolRunStatus.completed &&
              run.projectId == _project.id,
        )
        .map((run) => run.toActiveProtocol())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_project.colorValue);
    return Scaffold(
      appBar: ProtocolFlowAppBar(
        title: _project.name,
        actions: [
          IconButton(
            tooltip: 'Edit project',
            onPressed: _editProject,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ProtocolFlowContentBoundary(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        border: Border.all(
                          color: color.withValues(alpha: 0.28),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.folder_outlined, color: color, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _project.name,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (_project.description.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(_project.description),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_projectIsEmpty)
                      _buildEmptyProjectPrompt()
                    else ...[
                      if (_running.isNotEmpty) ...[
                        _ProjectSection(
                          title: 'Running',
                          actionLabel: 'Start protocol',
                          onAction: _openProtocols,
                          child: Column(
                            children: [
                              for (final state in _running)
                                RunningProtocolSummaryCard(
                                  state: state,
                                  detail: _runningDetail(state),
                                  progressValue:
                                      '${state.completedStepIds.length} of ${state.protocol.steps.length} steps',
                                  project: _project,
                                  compact: true,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  compactActionLabel: 'Resume',
                                  onCompactAction: () => _openRun(state),
                                  onTerminate: () => _confirmTerminate(state),
                                  onTap: () => _openRun(state),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_tasks.isNotEmpty) ...[
                        _ProjectSection(
                          title: 'Tasks',
                          actionLabel: 'Task',
                          onAction: _addTask,
                          child: Column(
                            children: [
                              for (final task in _tasks.take(6))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    task.status == TaskStatus.completed
                                        ? Icons.check_circle_outline
                                        : task.status == TaskStatus.inProgress
                                        ? Icons.play_circle_outline
                                        : Icons.radio_button_unchecked,
                                    color: task.status == TaskStatus.completed
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                  title: Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(_taskStatus(task.status)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_protocols.isNotEmpty) ...[
                        _ProjectSection(
                          title: 'Protocols',
                          actionLabel: 'Protocol',
                          onAction: _addProtocol,
                          child: Column(
                            children: [
                              for (final protocol in _protocols.take(6))
                                ProtocolSummaryCard(
                                  protocol: protocol,
                                  type: protocol.isTemplate
                                      ? ProtocolSummaryType.template
                                      : ProtocolSummaryType.protocol,
                                  project: _project,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  actionLabel: protocol.isTemplate
                                      ? 'Use template'
                                      : 'Run protocol',
                                  onAction: () => protocol.isTemplate
                                      ? _useTemplate(protocol)
                                      : _startProtocol(protocol),
                                  onTap: () => _openProtocolDetail(protocol),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_tables.isNotEmpty)
                        _ProjectSection(
                          title: 'Tables & Calculations',
                          actionLabel: 'Tool',
                          onAction: _openTool,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final table in _tables.take(8))
                                ProtocolTableWidget(
                                  table: table,
                                  isReadOnly: false,
                                  onSave: (updated) async {
                                    await _storageService.upsertSavedTable(
                                      updated,
                                    );
                                    await _loadData();
                                  },
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PopupMenuButton<String>(
                          tooltip: 'Add to project',
                          onSelected: (value) {
                            if (value == 'protocol') _addProtocol();
                            if (value == 'task') _addTask();
                            if (value == 'tool') _openTool();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'protocol',
                              child: ListTile(
                                leading: Icon(Icons.description_outlined),
                                title: Text('Protocol'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'task',
                              child: ListTile(
                                leading: Icon(Icons.checklist_outlined),
                                title: Text('Task'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'tool',
                              child: ListTile(
                                leading: Icon(Icons.science_outlined),
                                title: Text('Quick Tool'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18),
                                SizedBox(width: 6),
                                Text('Add to project'),
                              ],
                            ),
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

  bool get _projectIsEmpty =>
      _running.isEmpty &&
      _tasks.isEmpty &&
      _protocols.isEmpty &&
      _tables.isEmpty;

  Widget _buildEmptyProjectPrompt() {
    return Container(
      key: const Key('empty-project-prompt'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This project is empty.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add the first piece of work when you are ready.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _addProtocol,
                icon: const Icon(Icons.add),
                label: const Text('Add protocol'),
              ),
              OutlinedButton.icon(
                onPressed: _addTask,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('Add task'),
              ),
              TextButton.icon(
                onPressed: _openTool,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Quick Tool'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _runningDetail(ActiveProtocol state) {
    final steps = state.protocol.sortedSteps;
    if (state.currentStepIndex < 0 || state.currentStepIndex >= steps.length) {
      return 'Ready to continue';
    }
    final step = steps[state.currentStepIndex];
    final phase = step.phaseName?.trim();
    return [
      if (phase != null && phase.isNotEmpty) phase,
      'Step ${state.currentStepIndex + 1}: ${step.title}',
    ].join(' - ');
  }

  String _taskStatus(TaskStatus status) => switch (status) {
    TaskStatus.notStarted => 'Not started',
    TaskStatus.inProgress => 'In progress',
    TaskStatus.completed => 'Completed',
  };

  Future<void> _openRun(ActiveProtocol state) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProtocolDetailScreen(protocol: state.protocol, activeState: state),
      ),
    );
    await _loadData();
  }

  Future<void> _confirmTerminate(ActiveProtocol state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terminate run?'),
        content: const Text(
          'This permanently deletes the saved progress and notes for this run.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Terminate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final runId = state.runId;
    if (runId != null) {
      await ProtocolRunService.instance.discardRun(runId);
      await loadPersistentProtocols();
    } else {
      discardProtocolSession(state.protocol.id);
      await savePersistentProtocols();
    }
    await _loadData();
  }

  Future<void> _openProtocolDetail(Protocol protocol) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProtocolDetailScreen(protocol: protocol),
      ),
    );
    await _loadData();
  }

  Future<void> _useTemplate(Protocol protocol) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProtocolScreen(initialProtocol: protocol),
      ),
    );
    await _loadData();
  }

  Future<void> _startProtocol(Protocol protocol) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RunProtocolScreen(protocol: protocol)),
    );
    await _loadData();
  }

  void _openProtocols() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProtocolsScreen(initialProjectId: _project.id),
      ),
    );
  }

  Future<void> _addProtocol() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProtocolScreen(initialProjectId: _project.id),
      ),
    );
    await _loadData();
  }

  Future<void> _openTool() async {
    await showTableToolPicker(
      context,
      standaloneMode: true,
      initialProjectId: _project.id,
    );
    await _loadData();
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Task title'),
          onSubmitted: (value) => Navigator.pop(
            dialogContext,
            value.trim().isEmpty ? null : value.trim(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().isEmpty ? null : controller.text.trim(),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null) return;
    final allTasks = await _taskService.loadTodayTasks();
    allTasks.add(
      Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: '',
        createdAt: DateTime.now(),
        projectId: _project.id,
      ),
    );
    await _taskService.saveTodayTasks(allTasks);
    await _loadData();
  }

  Future<void> _editProject() async {
    final name = TextEditingController(text: _project.name);
    final description = TextEditingController(text: _project.description);
    final result = await showDialog<Project>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Project'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Project name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                dialogContext,
                _project.copyWith(
                  name: name.text.trim(),
                  description: description.text.trim(),
                  updatedAt: DateTime.now(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    description.dispose();
    if (result == null) return;
    await _storageService.upsertProject(result);
    await _loadData();
  }
}

class _ProjectSection extends StatelessWidget {
  const _ProjectSection({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
