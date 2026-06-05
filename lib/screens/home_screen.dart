import 'dart:async';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/task.dart';
import '../models/active_protocol.dart';
import '../data/completed_protocols_data.dart';
import '../features/today_tasks/services/task_service.dart';
import 'run_protocol_screen.dart';
import 'protocol_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User currentUser = User(
    id: 'u1',
    fullName: 'Aviv Yehuda',
    email: 'labuser@example.com',
  );

  final TaskService _taskService = TaskService();
  List<Task> _todayTasks = [];
  bool _isLoadingTasks = true;

  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await _taskService.loadTodayTasks();
    if (mounted) {
      setState(() {
        _todayTasks = tasks;
        _isLoadingTasks = false;
      });
    }
  }

  Future<void> _addTask(String title, String description) async {
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
    );
    setState(() {
      _todayTasks.add(newTask);
    });
    await _taskService.saveTodayTasks(_todayTasks);
  }

  Future<void> _toggleTaskDone(Task task) async {
    final index = _todayTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      setState(() {
        _todayTasks[index] = _todayTasks[index].copyWith(isDone: !task.isDone);
      });
      await _taskService.saveTodayTasks(_todayTasks);
    }
  }

  Future<void> _removeTask(Task task) async {
    setState(() {
      _todayTasks.removeWhere((t) => t.id == task.id);
    });
    await _taskService.saveTodayTasks(_todayTasks);
  }

  Future<void> _archiveTasks() async {
    await _taskService.archiveDoneTasks();
    await _loadTasks();
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _addTask(titleController.text, descController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (activeProtocol != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(activeProtocol!.startedAt);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  void _resumeProtocol() async {
    if (activeProtocol != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              RunProtocolScreen(protocol: activeProtocol!.protocol),
        ),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 90.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                expandedTitleScale: 1.0,
                background: Container(
                  color: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.only(
                    top: 12.0,
                    bottom: 0.0,
                    left: 48.0,
                    right: 48.0,
                  ),
                  child: Image.asset(
                    'assets/App_icons/PF_logo_flat_2.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.account_circle,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile features coming soon!'),
                      ),
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Today\'s Tasks'),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/task_history'),
                          child: const Text('Tasks History'),
                        ),
                      ],
                    ),
                    if (_isLoadingTasks)
                      const Center(child: CircularProgressIndicator())
                    else if (_todayTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No tasks for today.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ..._todayTasks.map((task) => _buildTaskItem(task)),

                    const SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _showAddTaskDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Task'),
                      ),
                    ),
                    if (_todayTasks.any((t) => t.isDone))
                      Center(
                        child: TextButton.icon(
                          onPressed: _archiveTasks,
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('Move done tasks to history'),
                        ),
                      ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(indent: 24, endIndent: 24, thickness: 1),
                    ),
                    _buildSectionTitle('Running Protocols'),
                    if (activeProtocol != null || runningProtocols.isNotEmpty)
                      Column(
                        children: [
                          if (activeProtocol != null)
                            _buildRunningProtocolCard(),
                          if (runningProtocols.isNotEmpty)
                            ...runningProtocols
                                .where(
                                  (p) =>
                                      activeProtocol == null ||
                                      p.protocol.id !=
                                          activeProtocol!.protocol.id,
                                )
                                .map((p) => _buildInProgressItem(p)),
                        ],
                      )
                    else
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No protocols currently running.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(indent: 24, endIndent: 24, thickness: 1),
                    ),
                    _buildSectionTitle('Quick Actions'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            Icons.add_box,
                            'Create',
                            () => Navigator.pushNamed(
                              context,
                              '/create',
                            ).then((_) => setState(() {})),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            Icons.library_books,
                            'Protocols',
                            () => Navigator.pushNamed(
                              context,
                              '/library',
                            ).then((_) => setState(() {})),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            Icons.science,
                            'Lab Tools',
                            () => Navigator.pushNamed(
                              context,
                              '/lab_tools',
                            ).then((_) => setState(() {})),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            Icons.table_chart,
                            'Saved Tables',
                            () => Navigator.pushNamed(
                              context,
                              '/saved_tables',
                            ).then((_) => setState(() {})),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: task.isDone,
            onChanged: (val) => _toggleTaskDone(task),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            decoration: task.isDone ? TextDecoration.lineThrough : null,
            color: task.isDone ? Colors.grey : null,
          ),
        ),
        subtitle: task.description.isNotEmpty
            ? Text(task.description, style: const TextStyle(fontSize: 12))
            : null,
        trailing: IconButton(
          icon: const Icon(
            Icons.remove_circle_outline,
            color: Colors.red,
            size: 18,
          ),
          onPressed: () => _removeTask(task),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }

  Widget _buildRunningProtocolCard() {
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
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    protocol.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDuration(_elapsedTime),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(color: Colors.blue)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _resumeProtocol,
                child: const Text('Resume Protocol'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInProgressItem(ActiveProtocol p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history, color: Colors.blue),
        title: Text(
          p.protocol.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${p.completedStepIds.length}/${p.protocol.steps.length} steps completed',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProtocolDetailScreen(protocol: p.protocol, activeState: p),
          ),
        ).then((_) => setState(() {})),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
