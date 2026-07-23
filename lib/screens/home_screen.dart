import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/active_protocol.dart';
import '../data/completed_protocols_data.dart';
import '../features/today_tasks/services/task_service.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../theme/app_colors.dart';
import '../widgets/google_sign_in_button.dart';
import '../features/measuring_tools/screens/measuring_tools_manager_screen.dart';
import 'lab_tools_screen.dart';
import 'library_screen.dart';
import 'projects_screen.dart';
import 'run_protocol_screen.dart';
import 'protocol_detail_screen.dart';
import 'saved_tables_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService.instance;
  final ExportService _exportService = ExportService();
  final ImportService _importService = ImportService();
  List<Task> _todayTasks = [];
  bool _isLoadingTasks = true;
  bool _areTasksShrunk = false;
  bool _isSigningIn = false;
  bool _isSyncing = false;
  bool _hasAttemptedStartupSync = false;
  int _selectedDesktopIndex = 0;
  int _libraryInitialTabIndex = 1;
  String? _libraryInitialProjectId;
  bool _isSidebarOpen = false;
  AppUser? _signedInUser;
  StreamSubscription<AppUser?>? _userSubscription;

  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadTasks();
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

  Future<void> _updateTaskStatus(Task task, TaskStatus status) async {
    final index = _todayTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      setState(() {
        _todayTasks[index] = _todayTasks[index].copyWith(status: status);
      });
      await _taskService.saveTodayTasks(_todayTasks);
    }
  }

  Future<void> _moveTask(Task task, int direction) async {
    final index = _todayTasks.indexWhere((item) => item.id == task.id);
    final targetIndex = index + direction;
    if (index == -1 || targetIndex < 0 || targetIndex >= _todayTasks.length) {
      return;
    }

    setState(() {
      final movedTask = _todayTasks.removeAt(index);
      _todayTasks.insert(targetIndex, movedTask);
    });
    await _taskService.saveTodayTasks(_todayTasks);
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
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([_loadTasks(), _refreshRunningProtocols()]);
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
    await _loadTasks();
    await loadPersistentProtocols();
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
    return PopScope(
      canPop: _selectedDesktopIndex == 0 && !_isSidebarOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSidebarOpen) {
          setState(() => _isSidebarOpen = false);
          return;
        }
        if (_selectedDesktopIndex != 0) {
          _selectPage(0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildSelectedPage()),
                ],
              ),
              if (_isSidebarOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleSidebar,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                  ),
                ),
                Align(alignment: Alignment.centerLeft, child: _buildSidebar()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = ((screenWidth * 0.82).clamp(248.0, 320.0) * 0.8).toDouble();
    final items = [
      _DesktopNavItem(
        icon: Icons.home_outlined,
        label: 'Home',
        onTap: () => _selectPage(0),
        selected: _selectedDesktopIndex == 0,
      ),
      _DesktopNavItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        onTap: () => _selectPage(1),
        selected: _selectedDesktopIndex == 1,
      ),
      _DesktopNavItem(
        icon: Icons.library_books_outlined,
        label: 'Library',
        onTap: () => _openLibraryTab(1),
        selected: _selectedDesktopIndex == 2,
      ),
      _DesktopNavItem(
        icon: Icons.folder_copy_outlined,
        label: 'Projects',
        onTap: () => _selectPage(3),
        selected: _selectedDesktopIndex == 3,
      ),
      _DesktopNavItem(
        icon: Icons.table_chart_outlined,
        label: 'Tables',
        onTap: () => _selectPage(4),
        selected: _selectedDesktopIndex == 4,
      ),
      _DesktopNavItem(
        icon: Icons.science_outlined,
        label: 'Lab Tools',
        onTap: () => _selectPage(5),
        selected: _selectedDesktopIndex == 5,
      ),
      _DesktopNavItem(
        icon: Icons.straighten,
        label: 'Measuring',
        onTap: () => _selectPage(6),
        selected: _selectedDesktopIndex == 6,
      ),
      _DesktopNavItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () => _selectPage(7),
        selected: _selectedDesktopIndex == 7,
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ProtocolFlow',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close sidebar',
                    color: AppColors.onPrimary,
                    onPressed: _toggleSidebar,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          for (final item in items) _buildSidebarButton(item),
          const Spacer(),
          const Divider(color: AppColors.onPrimary),
          _buildSidebarAction(
            icon: _isSyncing
                ? Icons.hourglass_empty
                : Icons.cloud_sync_outlined,
            label: _isSyncing ? 'Syncing' : 'Sync',
            onTap: _isSyncing
                ? null
                : () => _runDriveSync(promptIfNecessary: true),
          ),
          _buildSidebarAction(
            icon: Icons.import_export,
            label: 'Import / Export',
            onTap: _showImportExportMenu,
          ),
          _buildSidebarAction(
            icon: Icons.account_circle_outlined,
            label: _signedInUser == null ? 'Sign in' : 'Account',
            onTap: _isSigningIn ? null : _handleProfilePressed,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSidebarButton(_DesktopNavItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: item.selected
            ? AppColors.onPrimary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon, color: AppColors.onPrimary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap == null
              ? null
              : () {
                  setState(() => _isSidebarOpen = false);
                  onTap();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.onPrimary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: _isSidebarOpen ? 'Close sidebar' : 'Open sidebar',
            onPressed: _toggleSidebar,
            icon: const Icon(Icons.menu),
          ),
          const Expanded(child: SizedBox.shrink()),
          const Text(
            'ProtocolFlow',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: _signedInUser == null ? 'Sign in' : 'Account',
                onPressed: _isSigningIn ? null : _handleProfilePressed,
                icon: const Icon(Icons.account_circle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSidebar() {
    setState(() => _isSidebarOpen = !_isSidebarOpen);
  }

  void _selectPage(int index) {
    setState(() => _selectedDesktopIndex = index);
    if (index == 0) {
      _refreshRunningProtocols();
    }
    if (_isSidebarOpen) setState(() => _isSidebarOpen = false);
  }

  void _openLibraryTab(int tabIndex, {String? projectId}) {
    setState(() {
      _libraryInitialTabIndex = tabIndex;
      _libraryInitialProjectId = projectId;
      _selectedDesktopIndex = 2;
      _isSidebarOpen = false;
    });
  }

  Widget _buildSelectedPage() {
    if (_selectedDesktopIndex == 1) {
      return _buildDashboardWorkspace();
    }
    if (_selectedDesktopIndex == 2) {
      return LibraryScreen(
        key: ValueKey('$_libraryInitialTabIndex-$_libraryInitialProjectId'),
        initialTabIndex: _libraryInitialTabIndex,
        initialProjectId: _libraryInitialProjectId,
        embedded: true,
      );
    }
    if (_selectedDesktopIndex == 3) {
      return ProjectsScreen(
        embedded: true,
        onProjectSelected: (projectId) =>
            _openLibraryTab(1, projectId: projectId),
      );
    }
    if (_selectedDesktopIndex == 4) {
      return const SavedTablesScreen(embedded: true);
    }
    if (_selectedDesktopIndex == 5) {
      return const LabToolsScreen(embedded: true);
    }
    if (_selectedDesktopIndex == 6) {
      return const MeasuringToolsManagerScreen(embedded: true);
    }
    if (_selectedDesktopIndex == 7) {
      return _buildSettingsWorkspace();
    }

    return RefreshIndicator(
      onRefresh: _refreshHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: _buildHomeWorkspace(),
        ),
      ),
    );
  }

  Widget _buildHomeWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello ${_signedInUser?.displayName ?? 'there'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Resume lab work, start common workflows, and keep your data in sync.',
          softWrap: true,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _buildResumeWorkSection(),
        const SizedBox(height: 20),
        _buildTasksSection(),
        const SizedBox(height: 20),
        _buildSectionTitle('Quick Start'),
        _buildWorkspaceActions(),
      ],
    );
  }

  Widget _buildDashboardWorkspace() {
    return const DashboardScreen();
  }

  Widget _buildResumeWorkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Resume Work'),
        if (activeProtocol != null || runningProtocols.isNotEmpty)
          Column(
            children: [
              if (activeProtocol != null) _buildRunningProtocolCard(),
              if (runningProtocols.isNotEmpty)
                ...runningProtocols
                    .where(
                      (p) =>
                          activeProtocol == null ||
                          p.protocol.id != activeProtocol!.protocol.id,
                    )
                    .take(3)
                    .map((p) => _buildInProgressItem(p)),
              if (_runningProtocolCount > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openLibraryTab(2),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('View all running'),
                  ),
                ),
            ],
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 360;
                  final content = [
                    const Icon(
                      Icons.play_circle_outline,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 14, height: 12),
                    const Expanded(
                      child: Text(
                        'No protocols are currently running.',
                        softWrap: true,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openLibraryTab(1),
                      child: const Text(
                        'Open library',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ];

                  if (!narrow) return Row(children: content);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: content.take(3).toList()),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => _openLibraryTab(1),
                          child: const Text('Open library'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTasksSection() {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.today_outlined, color: AppColors.primary),
            title: Text(
              'Today\'s Tasks',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_todayTasks.length} '
              '${_todayTasks.length == 1 ? 'task' : 'tasks'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Task history',
                  icon: const Icon(Icons.history),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/task_history'),
                ),
                IconButton(
                  tooltip: _areTasksShrunk ? 'Expand tasks' : 'Shrink tasks',
                  icon: Icon(
                    _areTasksShrunk ? Icons.unfold_more : Icons.unfold_less,
                  ),
                  onPressed: () =>
                      setState(() => _areTasksShrunk = !_areTasksShrunk),
                ),
              ],
            ),
          ),
          if (!_areTasksShrunk) ...[
            const Divider(height: 1),
            if (_isLoadingTasks)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_todayTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Text(
                  'No tasks for today.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ..._todayTasks.asMap().entries.map((entry) {
                return Column(
                  children: [
                    _buildTaskItem(entry.value, entry.key),
                    if (entry.key < _todayTasks.length - 1)
                      const Divider(height: 1, indent: 54),
                  ],
                );
              }),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showAddTaskDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                  ),
                  if (_todayTasks.any(
                    (task) => task.status == TaskStatus.completed,
                  ))
                    TextButton.icon(
                      onPressed: _archiveTasks,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Move completed to history'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspaceActions() {
    final actions = [
      _WorkspaceAction(
        icon: Icons.edit_note,
        label: 'New protocol',
        description: 'Create a protocol or template',
        onTap: () async {
          final result = await Navigator.pushNamed(context, '/create');
          if (result != null) _refreshRunningProtocols();
        },
      ),
      _WorkspaceAction(
        icon: Icons.folder_open_outlined,
        label: 'Library',
        description: 'Browse protocols',
        onTap: () => _openLibraryTab(1),
      ),
      _WorkspaceAction(
        icon: Icons.folder_copy_outlined,
        label: 'Projects',
        description: 'Organize protocols and templates',
        onTap: () => _selectPage(3),
      ),
      _WorkspaceAction(
        icon: Icons.table_chart_outlined,
        label: 'Tables',
        description: 'Saved and reusable tables',
        onTap: () => _selectPage(4),
      ),
      _WorkspaceAction(
        icon: Icons.science_outlined,
        label: 'Lab tools',
        description: 'Plates, mixes, staining, calculators',
        onTap: () => _selectPage(5),
      ),
      _WorkspaceAction(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        description: 'Protocol activity and lab data',
        onTap: () => _selectPage(1),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: constraints.maxWidth,
                child: _buildWorkspaceAction(action),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWorkspaceAction(_WorkspaceAction action) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(action.icon, color: AppColors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsWorkspace() {
    final user = _signedInUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Settings'),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 420;
                    final account = Row(
                      children: [
                        _buildUserAvatar(user, size: 52),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Google account',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                user?.email ?? 'Not signed in',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    final action = TextButton.icon(
                      onPressed: _handleProfilePressed,
                      icon: Icon(
                        user == null
                            ? Icons.login
                            : Icons.manage_accounts_outlined,
                      ),
                      label: Text(user == null ? 'Sign in' : 'Manage'),
                    );

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          account,
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: action),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: account),
                        const SizedBox(width: 12),
                        action,
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 460;
                    final content = Row(
                      children: const [
                        Icon(Icons.cloud_sync_outlined),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Google Drive synchronization keeps protocols, tables, and history available across devices.',
                            softWrap: true,
                          ),
                        ),
                      ],
                    );
                    final action = ElevatedButton.icon(
                      onPressed: _isSyncing
                          ? null
                          : () => _runDriveSync(promptIfNecessary: true),
                      icon: const Icon(Icons.sync),
                      label: Text(_isSyncing ? 'Syncing' : 'Sync now'),
                    );

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          content,
                          const SizedBox(height: 14),
                          SizedBox(width: double.infinity, child: action),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: content),
                        const SizedBox(width: 12),
                        action,
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImportExportAction(String value) async {
    if (value == 'export_all') {
      await _exportService.exportAllData();
    } else if (value == 'export_templates') {
      await _exportService.exportTemplates();
    } else if (value == 'export_history') {
      await _exportService.exportHistory();
    } else if (value == 'import') {
      final result = await _importService.importJson();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      if (result.success) {
        await _refreshRunningProtocols();
      }
    }
  }

  Future<void> _showImportExportMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('Import ProtocolFlow file'),
              onTap: () => Navigator.pop(context, 'import'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Export All Data'),
              onTap: () => Navigator.pop(context, 'export_all'),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Export Templates'),
              onTap: () => Navigator.pop(context, 'export_templates'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Export History'),
              onTap: () => Navigator.pop(context, 'export_history'),
            ),
          ],
        ),
      ),
    );
    if (selected != null) await _handleImportExportAction(selected);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    Widget trailing = const SizedBox.shrink(),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle(title),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildSectionTitle(title)),
            Flexible(
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        );
      },
    );
  }

  int get _runningProtocolCount {
    final activeId = activeProtocol?.protocol.id;
    final inactiveRunning = runningProtocols.where(
      (p) => activeId == null || p.protocol.id != activeId,
    );
    return (activeProtocol == null ? 0 : 1) + inactiveRunning.length;
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

  Widget _buildTaskItem(Task task, int index) {
    final isCompleted = task.status == TaskStatus.completed;
    final title = Text(
      task.title,
      style: TextStyle(
        fontSize: 14,
        decoration: isCompleted ? TextDecoration.lineThrough : null,
        color: isCompleted ? AppColors.textDisabled : null,
      ),
    );
    final description = task.description.isEmpty
        ? null
        : Text(task.description, style: const TextStyle(fontSize: 12));
    final number = CircleAvatar(
      radius: 14,
      child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                number,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      ?description,
                      const SizedBox(height: 6),
                      _buildTaskStatusMenu(task),
                    ],
                  ),
                ),
                _buildTaskOptions(task, index),
              ],
            ),
          );
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: number,
          title: title,
          subtitle: description,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTaskStatusMenu(task),
              _buildTaskOptions(task, index),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskStatusMenu(Task task) {
    final color = _taskStatusColor(task.status);
    return PopupMenuButton<TaskStatus>(
      tooltip: 'Change task status',
      onSelected: (status) => _updateTaskStatus(task, status),
      itemBuilder: (context) => TaskStatus.values
          .map(
            (status) => PopupMenuItem(
              value: status,
              child: Row(
                children: [
                  Icon(
                    _taskStatusIcon(status),
                    color: _taskStatusColor(status),
                  ),
                  const SizedBox(width: 10),
                  Text(_taskStatusLabel(status)),
                ],
              ),
            ),
          )
          .toList(),
      child: Chip(
        avatar: Icon(_taskStatusIcon(task.status), size: 16, color: color),
        label: Text(
          _taskStatusLabel(task.status),
          style: TextStyle(fontSize: 12, color: color),
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
      ),
    );
  }

  Widget _buildTaskOptions(Task task, int index) {
    return PopupMenuButton<String>(
      tooltip: 'Task options',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'moveUp') _moveTask(task, -1);
        if (value == 'moveDown') _moveTask(task, 1);
        if (value == 'delete') _removeTask(task);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'moveUp',
          enabled: index > 0,
          child: const Text('Move up'),
        ),
        PopupMenuItem(
          value: 'moveDown',
          enabled: index < _todayTasks.length - 1,
          child: const Text('Move down'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Delete task')),
      ],
    );
  }

  String _taskStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.notStarted:
        return 'Not started';
      case TaskStatus.inProgress:
        return 'In progress';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  IconData _taskStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.notStarted:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline;
      case TaskStatus.completed:
        return Icons.check_circle_outline;
    }
  }

  Color _taskStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.notStarted:
        return AppColors.textSecondary;
      case TaskStatus.inProgress:
        return AppColors.info;
      case TaskStatus.completed:
        return AppColors.success;
    }
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

class _DesktopNavItem {
  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
}

class _WorkspaceAction {
  const _WorkspaceAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
}
