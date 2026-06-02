import 'package:flutter/material.dart';
import '../../../models/task.dart';
import '../services/task_service.dart';

class TaskHistoryScreen extends StatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  final TaskService _taskService = TaskService();
  List<Task> _historyTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final tasks = await _taskService.loadHistoryTasks();
    setState(() {
      _historyTasks = tasks;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyTasks.isEmpty
              ? const Center(child: Text('No tasks in history.'))
              : ListView.builder(
                  itemCount: _historyTasks.length,
                  itemBuilder: (context, index) {
                    final task = _historyTasks[index];
                    final dateStr = task.completedAt != null 
                        ? _formatDate(task.completedAt!)
                        : 'Unknown date';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.grey),
                        title: Text(task.title, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.description.isNotEmpty) Text(task.description),
                            Text('Completed: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
