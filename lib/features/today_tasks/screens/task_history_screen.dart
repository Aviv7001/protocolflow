import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../models/task.dart';
import '../services/task_service.dart';
import '../../../models/project.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/protocolflow_app_bar.dart';
import '../../../widgets/protocolflow_ui.dart';

class TaskHistoryScreen extends StatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  final TaskService _taskService = TaskService();
  final StorageService _storageService = StorageService();
  List<Task> _historyTasks = [];
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final results = await Future.wait([
      _taskService.loadHistoryTasks(),
      _storageService.loadProjects(),
    ]);
    final tasks = results[0] as List<Task>;
    final projects = results[1] as List<Project>;
    if (!mounted) return;
    setState(() {
      _historyTasks = tasks;
      _projects = projects;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProtocolFlowAppBar(
        title: 'Task History',
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: AppColors.error,
            ),
            tooltip: 'Clear history',
            onPressed: _historyTasks.isEmpty ? null : _confirmClearHistory,
          ),
        ],
      ),
      body: ProtocolFlowContentBoundary(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _historyTasks.isEmpty
            ? const ProtocolFlowEmptyState(message: 'No tasks in history.')
            : ListView.builder(
                itemCount: _historyTasks.length,
                itemBuilder: (context, index) {
                  final task = _historyTasks[index];
                  final dateStr = task.completedAt != null
                      ? _formatDate(task.completedAt!)
                      : 'Unknown date';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                      ),
                      title: Text(
                        task.title,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.description.isNotEmpty)
                            Text(task.description),
                          _buildProjectLabel(task.projectId),
                          Text(
                            'Completed: $dateStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildProjectLabel(String? projectId) {
    Project? project;
    for (final candidate in _projects) {
      if (candidate.id == projectId) project = candidate;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            project == null ? Icons.folder_off_outlined : Icons.folder_outlined,
            size: 14,
            color: project == null
                ? AppColors.textSecondary
                : Color(project.colorValue),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              project?.name ?? 'Unassigned',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Tasks History?'),
        content: const Text(
          'This will permanently remove all completed tasks from history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _taskService.clearHistoryTasks();
              if (!mounted) return;
              setState(() => _historyTasks = []);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
