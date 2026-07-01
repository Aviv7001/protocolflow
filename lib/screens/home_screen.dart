import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/active_protocol.dart';
import '../data/completed_protocols_data.dart';
import '../features/today_tasks/services/task_service.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/google_sign_in_button.dart';
import 'library_screen.dart';
import 'run_protocol_screen.dart';
import 'protocol_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService _taskService = TaskService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService.instance;
  List<Task> _todayTasks = [];
  int _templateCount = 0;
  int _protocolCount = 0;
  int _savedTableCount = 0;
  bool _isLoadingTasks = true;
  bool _isLoadingOverview = true;
  bool _isSigningIn = false;
  bool _isSyncing = false;
  bool _hasAttemptedStartupSync = false;
  AppUser? _signedInUser;
  StreamSubscription<AppUser?>? _userSubscription;

  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadTasks();
    _loadOverview();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      await _authService.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_googleSignInErrorMessage(e))));
      }
    }
    if (!mounted) return;
    setState(() => _signedInUser = _authService.currentUser);
    if (_signedInUser != null && _authService.hasAuthenticatedAccount) {
      _runDriveSync(promptIfNecessary: false, showSnackBar: false);
      _hasAttemptedStartupSync = true;
    }
    _userSubscription = _authService.userChanges.listen((user) {
      if (mounted) {
        setState(() => _signedInUser = user);
        if (user != null &&
            _authService.hasAuthenticatedAccount &&
            !_hasAttemptedStartupSync) {
          _hasAttemptedStartupSync = true;
          _runDriveSync(promptIfNecessary: false, showSnackBar: false);
        }
      }
    });
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

  Future<void> _loadOverview() async {
    final protocols = await _storageService.loadProtocols();
    final savedTables = await _storageService.loadSavedTables();
    if (!mounted) return;

    setState(() {
      _templateCount = protocols.where((p) => p.isTemplate).length;
      _protocolCount = protocols.where((p) => !p.isTemplate).length;
      _savedTableCount = savedTables.length;
      _isLoadingOverview = false;
    });
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

  Future<void> _refreshRunningProtocols() async {
    await loadPersistentProtocols();
    await _loadOverview();
    if (mounted) {
      setState(() {});
    }
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
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleProfilePressed() async {
    final user = _signedInUser;
    if (user == null) {
      if (!_authService.supportsDirectAuthenticate) {
        await _showWebSignInDialog();
        return;
      }
      setState(() => _isSigningIn = true);
      try {
        final signedIn = await _authService.signIn();
        if (signedIn != null) {
          await _runDriveSync(promptIfNecessary: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_googleSignInErrorMessage(e))));
        }
      } finally {
        if (mounted) setState(() => _isSigningIn = false);
      }
      return;
    }

    await _showProfileDialog(user);
  }

  Future<void> _showWebSignInDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in'),
        content: SizedBox(
          width: 280,
          child: _authService.initializationError == null
              ? buildGoogleSignInButton()
              : Text(
                  _googleSignInErrorMessage(_authService.initializationError!),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _runDriveSync({
    required bool promptIfNecessary,
    bool showSnackBar = true,
  }) async {
    if (_isSyncing) return;
    if (mounted) setState(() => _isSyncing = true);
    final summary = await DriveSyncService.instance.syncNow(
      promptIfNecessary: promptIfNecessary,
    );
    if (mounted) {
      setState(() => _isSyncing = false);
      if (!showSnackBar) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary.message),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _showProfileDialog(AppUser user) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Google Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildUserAvatar(user, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'Google user',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              'Google ID: ${user.googleUserId}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: _isSyncing
                ? null
                : () async {
                    Navigator.pop(dialogContext);
                    await _runDriveSync(promptIfNecessary: true);
                  },
            child: Text(_isSyncing ? 'Syncing...' : 'Sync now'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _authService.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  String _googleSignInErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('ClientID not set') ||
        raw.contains('google-signin-client_id') ||
        raw.contains('web client ID is missing') ||
        raw.contains('Null check operator used on a null value')) {
      return 'Google Sign-In web client ID is missing. Run with GOOGLE_WEB_CLIENT_ID or add google-signin-client_id to web/index.html.';
    }
    if (raw.contains('serverClientId is not supported on Web')) {
      return 'Google Sign-In web setup is using a server client ID. Use GOOGLE_WEB_CLIENT_ID for the web OAuth client.';
    }
    if (raw.contains('clientConfigurationError')) {
      return 'Google Sign-In needs an Android OAuth client. Add google-services.json or run with GOOGLE_SERVER_CLIENT_ID.';
    }
    if (raw.contains('28444') ||
        raw.contains('Developer console is not set up correctly')) {
      return 'Google Sign-In config mismatch. Check package name, release SHA-1, and Web client ID.';
    }
    return 'Google Sign-In failed: $error';
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
              pinned: true,
              centerTitle: true,
              title: const Text('ProtocolFlow'),
              leading: IconButton(
                tooltip: 'User profile',
                icon: _isSigningIn
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : _buildUserAvatar(_signedInUser, size: 30),
                onPressed: _isSigningIn ? null : _handleProfilePressed,
              ),
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
                          style: TextStyle(color: AppColors.textSecondary),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Running Protocols'),
                        IconButton(
                          tooltip: 'Refresh running protocols',
                          onPressed: _refreshRunningProtocols,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
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
                    _buildSectionTitle('Overview'),
                    _buildOverviewGrid(),
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

  Widget _buildOverviewGrid() {
    final runningCount = _runningProtocolCount;
    final items = [
      _OverviewItem(
        icon: Icons.copy_all,
        label: 'Templates',
        value: _templateCount,
        onTap: () => _openLibraryTab(0),
      ),
      _OverviewItem(
        icon: Icons.article_outlined,
        label: 'Protocols',
        value: _protocolCount,
        onTap: () => _openLibraryTab(1),
      ),
      _OverviewItem(
        icon: Icons.play_circle_outline,
        label: 'Running',
        value: runningCount,
        onTap: () => _openLibraryTab(2),
      ),
      _OverviewItem(
        icon: Icons.check_circle_outline,
        label: 'Completed',
        value: completedProtocols.length,
        onTap: () => _openLibraryTab(3),
      ),
      _OverviewItem(
        icon: Icons.table_chart,
        label: 'Saved Tables',
        value: _savedTableCount,
        onTap: () => Navigator.pushNamed(context, '/saved_tables').then((_) {
          _loadOverview();
        }),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720
            ? 5
            : constraints.maxWidth >= 420
            ? 3
            : 2;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
            crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) =>
                    SizedBox(width: itemWidth, child: _buildOverviewCard(item)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildOverviewCard(_OverviewItem item) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: AppColors.primary),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _isLoadingOverview ? '-' : item.value.toString(),
                  key: ValueKey(
                    '${item.label}_${item.value}_$_isLoadingOverview',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _runningProtocolCount {
    final activeId = activeProtocol?.protocol.id;
    final inactiveRunning = runningProtocols.where(
      (p) => activeId == null || p.protocol.id != activeId,
    );
    return (activeProtocol == null ? 0 : 1) + inactiveRunning.length;
  }

  void _openLibraryTab(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LibraryScreen(initialTabIndex: index),
      ),
    ).then((_) => _refreshRunningProtocols());
  }

  Widget _buildUserAvatar(AppUser? user, {required double size}) {
    final photoUrl = user?.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: AppColors.surface,
      );
    }

    final name = user?.displayName ?? user?.email;
    final initial = name != null && name.isNotEmpty
        ? name[0].toUpperCase()
        : '';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.primary,
      child: initial.isEmpty
          ? Icon(Icons.account_circle, size: size)
          : Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            color: task.isDone ? AppColors.textDisabled : null,
          ),
        ),
        subtitle: task.description.isNotEmpty
            ? Text(task.description, style: const TextStyle(fontSize: 12))
            : null,
        trailing: IconButton(
          icon: const Icon(
            Icons.remove_circle_outline,
            color: AppColors.error,
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
      color: AppColors.primaryContainer,
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
                  style: TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(status, style: TextStyle(color: AppColors.info)),
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
        leading: Icon(Icons.history, color: AppColors.info),
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
}

class _OverviewItem {
  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final VoidCallback onTap;
}
