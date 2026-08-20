import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../models/project.dart';
import '../models/protocol_run.dart';
import '../data/completed_protocols_data.dart';
import '../features/today_tasks/services/task_service.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/storage_service.dart';
import '../services/app_data_reset_service.dart';
import '../theme/app_colors.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/running_protocol_summary_card.dart';
import '../widgets/sync_preview_dialog.dart';
import '../widgets/backup_restore_preview_dialog.dart';
import '../features/measuring_tools/screens/measuring_tools_manager_screen.dart';
import 'table_selection_screen.dart';
import 'library_screen.dart';
import 'projects_screen.dart';
import 'protocol_detail_screen.dart';
import 'saved_tables_screen.dart';
import 'dashboard_screen.dart';
import 'user_guide_screen.dart';
import 'shared_protocol_import_screen.dart';
import 'shared_protocol_scanner_screen.dart';
import 'more_screen.dart';
import 'project_detail_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialLibraryTabIndex});

  final int? initialLibraryTabIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _exploreLocallyKey = 'home_explore_locally_v1';
  static const _unassignedTaskFilter = '__unassigned__';
  final TaskService _taskService = TaskService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService.instance;
  final ExportService _exportService = ExportService();
  final ImportService _importService = ImportService();
  List<Task> _todayTasks = [];
  List<Project> _projects = [];
  List<Protocol> _protocols = [];
  List<ProtocolTable> _savedTables = [];
  bool _isLoadingTasks = true;
  bool _showAllQuickTools = false;
  bool _isSigningIn = false;
  bool _isSyncing = false;
  bool _isResettingData = false;
  bool _isManagingBackup = false;
  bool _hasAttemptedStartupSync = false;
  bool _homeDataReady = false;
  bool _authReady = false;
  bool _exploreLocally = false;
  String? _taskProjectFilter;
  bool _createProjectOnOpen = false;
  bool _syncHasErrors = false;
  bool _syncHasPendingChanges = false;
  DateTime? _lastSyncAt;
  int _selectedDesktopIndex = 0;
  int _selectedPrimaryIndex = 0;
  int _libraryInitialTabIndex = 1;
  String? _libraryInitialProjectId;
  String? _tasksInitialProjectId;
  int _tasksReturnPage = 0;
  String? _tablesInitialProjectId;
  int _tablesReturnPage = 1;
  AppUser? _signedInUser;
  StreamSubscription<AppUser?>? _userSubscription;

  @override
  void initState() {
    super.initState();
    final initialLibraryTabIndex = widget.initialLibraryTabIndex;
    if (initialLibraryTabIndex != null) {
      _libraryInitialTabIndex = initialLibraryTabIndex;
      _selectedDesktopIndex = 2;
      _selectedPrimaryIndex = 1;
    }
    _loadHomeExperience();
    _initializeAuth();
  }

  Future<void> _loadHomeExperience() async {
    final preferences = await SharedPreferences.getInstance();
    _exploreLocally = preferences.getBool(_exploreLocallyKey) ?? false;
    await _refreshHome();
    if (mounted) setState(() => _homeDataReady = true);
  }

  Future<void> _initializeAuth() async {
    try {
      await _authService.initialize();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _signedInUser = _authService.currentUser;
      _authReady = true;
    });
    if (_signedInUser != null && _authService.hasAuthenticatedAccount) {
      _hasAttemptedStartupSync = true;
    }
    _userSubscription = _authService.userChanges.listen((user) {
      if (mounted) {
        setState(() => _signedInUser = user);
        if (user != null &&
            _authService.hasAuthenticatedAccount &&
            !_hasAttemptedStartupSync) {
          _hasAttemptedStartupSync = true;
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

  Future<void> _addTask(
    String title,
    String description,
    String? projectId,
  ) async {
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      projectId: projectId,
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

  Future<void> _removeTask(Task task) async {
    setState(() {
      _todayTasks.removeWhere((t) => t.id == task.id);
    });
    await _taskService.saveTodayTasks(_todayTasks);
  }

  Future<void> _assignTaskProject(Task task, String? projectId) async {
    final index = _todayTasks.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    setState(() {
      _todayTasks[index] = projectId == null
          ? task.copyWith(clearProjectId: true)
          : task.copyWith(projectId: projectId);
    });
    await _taskService.saveTodayTasks(_todayTasks);
  }

  Future<void> _archiveTask(Task task) async {
    await _archiveTaskIds({task.id});
  }

  Future<void> _archiveVisibleCompletedTasks() async {
    await _archiveTaskIds(
      _todayTasks
          .where((task) => task.isDone && _taskMatchesSelectedProject(task))
          .map((task) => task.id)
          .toSet(),
    );
  }

  Future<void> _archiveTaskIds(Set<String> taskIds) async {
    if (taskIds.isEmpty) return;
    final todayBefore = List<Task>.from(_todayTasks);
    final historyBefore = await _taskService.loadHistoryTasks();
    final archivedCount = await _taskService.archiveTasks(taskIds);
    if (archivedCount == 0) return;
    await _loadTasks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          archivedCount == 1
              ? 'Task moved to history'
              : '$archivedCount tasks moved to history',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _taskService.saveTodayTasks(todayBefore);
            await _taskService.saveHistoryTasks(historyBefore);
            await _loadTasks();
          },
        ),
      ),
    );
  }

  bool _taskMatchesSelectedProject(Task task) {
    final filter = _taskProjectFilter;
    if (filter == null) return true;
    if (filter == _unassignedTaskFilter) {
      return task.projectId == null || task.projectId!.isEmpty;
    }
    return task.projectId == filter;
  }

  String _taskFilterLabel() {
    final filter = _taskProjectFilter;
    if (filter == null) return 'All projects';
    if (filter == _unassignedTaskFilter) return 'Unassigned';
    return _projectFor(filter)?.name ?? 'All projects';
  }

  Future<void> _refreshRunningProtocols() async {
    await loadPersistentProtocols();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProjects() async {
    final values = await Future.wait([
      _storageService.loadProjects(),
      _storageService.loadProtocols(),
      _storageService.loadSavedTables(),
    ]);
    if (mounted) {
      setState(() {
        _projects = values[0] as List<Project>;
        _protocols = values[1] as List<Protocol>;
        _savedTables = values[2] as List<ProtocolTable>;
      });
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _loadTasks(),
      _refreshRunningProtocols(),
      _loadProjects(),
      _loadSyncHealth(),
    ]);
  }

  Future<void> _loadSyncHealth() async {
    final protocols = await _storageService.loadProtocols();
    final active = await _storageService.loadActiveProtocol();
    final running = await _storageService.loadRunningProtocols();
    final bundleStates = await Future.wait([
      _storageService.loadSyncBundleState(SyncBundleType.projects),
      _storageService.loadSyncBundleState(SyncBundleType.completedProtocols),
      _storageService.loadSyncBundleState(SyncBundleType.tasks),
      _storageService.loadSyncBundleState(SyncBundleType.measuringTools),
    ]);
    final tableState = await _storageService.loadSavedTablesSyncState();
    final statuses = [
      ...protocols.map((protocol) => protocol.syncStatus),
      ...completedProtocols.map((protocol) => protocol.syncStatus),
      if (active != null) active.protocol.syncStatus,
      ...running.map((session) => session.protocol.syncStatus),
    ];
    final syncTimes = [
      ...protocols.map((protocol) => protocol.lastSyncedAt),
      ...completedProtocols.map((protocol) => protocol.lastSyncedAt),
      if (active != null) active.protocol.lastSyncedAt,
      ...running.map((session) => session.protocol.lastSyncedAt),
    ].whereType<DateTime>().toList();
    syncTimes.sort();

    if (!mounted) return;
    setState(() {
      _syncHasErrors =
          statuses.any(
            (status) =>
                status == ProtocolSyncStatus.error ||
                status == ProtocolSyncStatus.conflict,
          ) ||
          bundleStates.contains(SyncBundleState.error) ||
          tableState == SavedTablesSyncState.error;
      _syncHasPendingChanges =
          statuses.any((status) => status != ProtocolSyncStatus.synced) ||
          bundleStates.contains(SyncBundleState.pending) ||
          tableState == SavedTablesSyncState.pending;
      _lastSyncAt = syncTimes.isEmpty ? null : syncTimes.last;
    });
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    const unassignedProject = '__unassigned__';
    String selectedProjectId = unassignedProject;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedProjectId,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: unassignedProject,
                      child: Text('Unassigned'),
                    ),
                    ..._projects.map(
                      (project) => DropdownMenuItem<String>(
                        value: project.id,
                        child: Text(
                          project.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedProjectId = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  _addTask(
                    titleController.text.trim(),
                    descController.text.trim(),
                    selectedProjectId == unassignedProject
                        ? null
                        : selectedProjectId,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
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
    if (_isSyncing || _isResettingData || _isManagingBackup) return;
    if (mounted) setState(() => _isSyncing = true);
    final summary = await showDialog<DriveSyncSummary>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SyncPreviewDialog(
        syncService: DriveSyncService.instance,
        promptIfNecessary: promptIfNecessary,
      ),
    );
    if (!mounted) return;
    if (summary == null) {
      setState(() => _isSyncing = false);
      return;
    }
    await _loadTasks();
    await _loadProjects();
    await loadPersistentProtocols();
    await _loadSyncHealth();
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
            onPressed: _isSyncing || _isResettingData || _isManagingBackup
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

  // Retained for compatibility with older Home actions.
  // ignore: unused_element
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
    if (imported == true) await _refreshHome();
  }

  @override
  Widget build(BuildContext context) {
    if (!_homeDataReady || !_authReady) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: _selectedDesktopIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedDesktopIndex != 0) {
          _selectPage(0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        bottomNavigationBar: _buildResponsivePrimaryNavigation(),
        body: SafeArea(
          child: Column(
            children: [
              if (_selectedDesktopIndex != 0 || _shouldShowFirstUseLogin)
                _buildTopBar(),
              Expanded(child: _buildSelectedPage()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final firstUse = _selectedDesktopIndex == 0 && _shouldShowFirstUseLogin;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.scaffoldBackground,
      child: Row(
        children: [
          if (firstUse)
            IconButton(
              tooltip: 'Sign in',
              onPressed: _isSigningIn ? null : _handleProfilePressed,
              icon: _buildUserAvatar(null, size: 38),
            ),
          Expanded(
            child: Text(
              'ProtocolFlow',
              textAlign: firstUse ? TextAlign.center : TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: firstUse
                ? 'Sync'
                : _signedInUser == null
                ? 'Sign in'
                : 'Account',
            onPressed: firstUse
                ? () => _selectPage(3)
                : (_isSigningIn ? null : _handleProfilePressed),
            icon: firstUse
                ? const Icon(Icons.sync, color: AppColors.primary, size: 28)
                : _buildUserAvatar(_signedInUser, size: 38),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryNavigation() {
    return SizedBox(
      height: 68,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            NavigationBar(
              height: 68,
              indicatorColor: Colors.transparent,
              selectedIndex: _selectedPrimaryIndex,
              onDestinationSelected: _selectPrimaryDestination,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: AppColors.primary),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book, color: AppColors.primary),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder, color: AppColors.primary),
                  label: 'Projects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_outlined),
                  selectedIcon: Icon(Icons.menu, color: AppColors.primary),
                  label: 'More',
                ),
              ],
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              top: 0,
              left: constraints.maxWidth * _selectedPrimaryIndex / 4,
              width: constraints.maxWidth / 4,
              child: const SizedBox(
                height: 4,
                child: ColoredBox(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsivePrimaryNavigation() {
    final navigation = _buildPrimaryNavigation();
    if (MediaQuery.sizeOf(context).width < ProtocolFlowBreakpoints.desktop) {
      return navigation;
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: SizedBox(
          key: const Key('floating-primary-navigation'),
          width: 560,
          child: Material(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: navigation,
          ),
        ),
      ),
    );
  }

  void _selectPrimaryDestination(int index) {
    setState(() => _selectedPrimaryIndex = index);
    switch (index) {
      case 0:
        _selectPage(0);
        return;
      case 1:
        _openLibraryTab(1);
        return;
      case 2:
        _selectPage(1);
        return;
      case 3:
        _selectPage(3);
        return;
    }
  }

  void _selectPage(int index) {
    setState(() {
      _selectedDesktopIndex = index;
      _selectedPrimaryIndex = switch (index) {
        0 => 0,
        1 => 2,
        2 => 1,
        3 => 3,
        _ => _selectedPrimaryIndex,
      };
    });
    if (index == 0) {
      _refreshHome();
    }
  }

  void _openLibraryTab(int tabIndex, {String? projectId}) {
    setState(() {
      _libraryInitialTabIndex = tabIndex;
      _libraryInitialProjectId = projectId;
      _selectedDesktopIndex = 2;
      _selectedPrimaryIndex = 1;
    });
  }

  void _openTasksWorkspace({String? projectId, int returnPage = 0}) {
    setState(() {
      _tasksInitialProjectId = projectId;
      _tasksReturnPage = returnPage;
      _selectedDesktopIndex = 9;
      _selectedPrimaryIndex = returnPage == 1 ? 2 : 0;
    });
  }

  void _openSavedTablesWorkspace({String? projectId, int returnPage = 0}) {
    setState(() {
      _tablesInitialProjectId = projectId;
      _tablesReturnPage = returnPage;
      _selectedDesktopIndex = 4;
      _selectedPrimaryIndex = returnPage == 1 ? 2 : 0;
    });
  }

  void _openProjectTables(String? projectId) {
    _openSavedTablesWorkspace(projectId: projectId, returnPage: 1);
  }

  Widget _buildSelectedPage() {
    if (_selectedDesktopIndex == 0 && _shouldShowFirstUseLogin) {
      return _buildFirstUseScreen();
    }
    if (_selectedDesktopIndex == 1) {
      return ProjectsScreen(
        embedded: true,
        createOnOpen: _createProjectOnOpen,
        onCreatePromptShown: () => _createProjectOnOpen = false,
        onProjectSelected: (projectId) =>
            _openLibraryTab(1, projectId: projectId),
        onTasksSelected: (projectId) =>
            _openTasksWorkspace(projectId: projectId, returnPage: 1),
        onProtocolSelected: (tabIndex, projectId) =>
            _openLibraryTab(tabIndex, projectId: projectId),
        onTablesSelected: _openProjectTables,
      );
    }
    if (_selectedDesktopIndex == 2) {
      return LibraryScreen(
        key: ValueKey(
          'library-$_libraryInitialTabIndex-${_libraryInitialProjectId ?? 'all'}',
        ),
        embedded: true,
        initialTabIndex: _libraryInitialTabIndex,
        initialProjectId: _libraryInitialProjectId,
      );
    }
    if (_selectedDesktopIndex == 3) {
      return MoreScreen(onOpenSettings: () => _selectPage(8));
    }
    if (_selectedDesktopIndex == 4) {
      return SavedTablesScreen(
        key: ValueKey('tables-${_tablesInitialProjectId ?? 'all'}'),
        embedded: true,
        initialProjectId: _tablesInitialProjectId,
        onBack: () => _selectPage(_tablesReturnPage),
      );
    }
    if (_selectedDesktopIndex == 6) {
      return const MeasuringToolsManagerScreen(embedded: true);
    }
    if (_selectedDesktopIndex == 7) {
      return const UserGuideScreen(embedded: true);
    }
    if (_selectedDesktopIndex == 8) {
      return _buildSettingsWorkspace();
    }
    if (_selectedDesktopIndex == 9) {
      return TasksScreen(
        key: ValueKey('tasks-${_tasksInitialProjectId ?? 'all'}'),
        embedded: true,
        initialProjectId: _tasksInitialProjectId,
        onBack: () => _selectPage(_tasksReturnPage),
        onChanged: _loadTasks,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: _buildHomeWorkspace(),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeWorkspace() {
    final activeTasks = _todayTasks.where((task) => !task.isDone).length;
    final inProgressTasks = _todayTasks
        .where((task) => task.status == TaskStatus.inProgress)
        .length;
    final protocols = _protocols
        .where((protocol) => !protocol.isTemplate)
        .length;
    final templates = _protocols
        .where((protocol) => protocol.isTemplate)
        .length;
    final running = protocolRuns
        .where((run) => run.status != ProtocolRunStatus.completed)
        .length;
    final completed = protocolRuns
        .where((run) => run.status == ProtocolRunStatus.completed)
        .length;
    final projectNames =
        (List<Project>.from(_projects)
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
            .take(2)
            .map((project) => project.name)
            .join(' · ');

    final cards = <Widget>[
      _HomeSummaryCard(
        key: const Key('home-today-tasks-section'),
        icon: Icons.checklist_rounded,
        title: 'Tasks',
        onTap: () => _openTasksWorkspace(),
        child: _todayTasks.isEmpty
            ? _HomeEmptyAction(
                message: 'No tasks yet',
                label: 'Add Task',
                icon: Icons.add_task,
                onPressed: _showAddTaskDialog,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$activeTasks active ${activeTasks == 1 ? 'task' : 'tasks'}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$inProgressTasks in progress',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
      ),
      _HomeSummaryCard(
        key: const Key('home-resume-work-section'),
        icon: Icons.description_outlined,
        title: 'Protocols',
        onTap: () => _openLibraryTab(1),
        child:
            protocols == 0 && templates == 0 && running == 0 && completed == 0
            ? _HomeEmptyAction(
                message: 'No protocols yet',
                label: 'Create/Import Protocol',
                icon: Icons.add,
                onPressed: () => _openLibraryTab(1),
              )
            : _ProtocolCounts(
                protocols: protocols,
                templates: templates,
                running: running,
                completed: completed,
                onOpenTab: _openLibraryTab,
              ),
      ),
      _HomeSummaryCard(
        key: const Key('home-projects-section'),
        icon: Icons.folder_outlined,
        title: 'Projects',
        onTap: () => _selectPage(1),
        child: _projects.isEmpty
            ? _HomeEmptyAction(
                message: 'No projects yet',
                label: 'Create Project',
                icon: Icons.create_new_folder_outlined,
                onPressed: _openProjectCreation,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_projects.length} ${_projects.length == 1 ? 'project' : 'projects'}',
                  ),
                  if (projectNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      projectNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
      ),
    ];

    final utilities = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _HomeUtilityCard(
            key: const Key('home-quick-start-section'),
            icon: Icons.science_outlined,
            title: 'Lab Tools',
            subtitle: 'Calculators and layouts',
            onTap: () => showTableToolPicker(
              context,
              standaloneMode: true,
            ).then((_) => _refreshHome()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HomeUtilityCard(
            key: const Key('home-saved-tables-section'),
            icon: Icons.table_chart_outlined,
            title: 'Saved Tables',
            subtitle:
                '${_savedTables.length} saved ${_savedTables.length == 1 ? 'table' : 'tables'}',
            onTap: _openSavedTablesWorkspace,
            actionLabel: _savedTables.isEmpty ? 'Create Table' : null,
            onAction: _savedTables.isEmpty
                ? () => showTableToolPicker(
                    context,
                    standaloneMode: true,
                  ).then((_) => _refreshHome())
                : null,
          ),
        ),
      ],
    );
    final utilitiesHeight = _savedTables.isEmpty ? 146.0 : 138.0;

    return Column(
      key: const Key('home-stable-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHomeHeader(),
        const SizedBox(height: 14),
        _buildHomeSyncStatus(),
        if (_syncHasErrors) ...[
          const SizedBox(height: 12),
          _buildSyncWarning(),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 14),
                  ],
                  SizedBox(height: utilitiesHeight, child: utilities),
                ],
              );
            }
            final cardWidth = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final card in cards)
                  SizedBox(width: cardWidth, child: card),
                SizedBox(
                  width: cardWidth,
                  height: utilitiesHeight,
                  child: utilities,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  bool get _shouldShowFirstUseLogin =>
      _signedInUser == null && !_exploreLocally && !_hasMeaningfulLocalData;

  bool get _hasMeaningfulLocalData =>
      _projects.isNotEmpty ||
      _protocols.isNotEmpty ||
      _savedTables.isNotEmpty ||
      _todayTasks.isNotEmpty ||
      protocolRuns.isNotEmpty ||
      completedProtocols.isNotEmpty;

  Widget _buildFirstUseScreen() {
    return ColoredBox(
      key: const Key('first-use-login-screen'),
      color: AppColors.scaffoldBackground,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome to ProtocolFlow',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Organize, build and run your lab protocols.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 42),
                SizedBox(
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: _isSigningIn ? null : _handleProfilePressed,
                    icon: _isSigningIn
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login, size: 28),
                    label: const Text('Continue with Google'),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: _continueLocally,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 28),
                    label: const Text('Explore locally'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueLocally() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_exploreLocallyKey, true);
    if (mounted) setState(() => _exploreLocally = true);
  }

  void _openProjectCreation() {
    _createProjectOnOpen = true;
    _selectPage(1);
  }

  Widget _buildHomeHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final displayName = _signedInUser?.displayName?.trim();
    final firstName = displayName == null || displayName.isEmpty
        ? null
        : displayName.split(RegExp(r'\s+')).first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName == null ? greeting : '$greeting, $firstName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your lab workspace',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          key: const Key('home-profile-button'),
          borderRadius: BorderRadius.circular(28),
          onTap: _isSigningIn ? null : _handleProfilePressed,
          child: _buildUserAvatar(_signedInUser, size: 48),
        ),
      ],
    );
  }

  Widget _buildHomeSyncStatus() {
    final (icon, label, color) = _syncHasErrors
        ? (Icons.error_outline, 'Sync needs attention', AppColors.error)
        : _signedInUser == null
        ? (
            Icons.offline_bolt_outlined,
            'Working locally',
            AppColors.textSecondary,
          )
        : _syncHasPendingChanges
        ? (
            Icons.cloud_upload_outlined,
            'Changes waiting to sync',
            AppColors.warning,
          )
        : (Icons.check_circle, 'Synced', AppColors.primary);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _selectPage(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncWarning() {
    return Material(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined, color: AppColors.error),
        title: const Text('Sync needs attention'),
        subtitle: const Text(
          'Review the issue before relying on Drive backup.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _selectPage(3),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDashboardWorkspace() {
    return const DashboardScreen();
  }

  // ignore: unused_element
  Widget _buildResumeWorkSection({bool expanded = false}) {
    final visibleRuns =
        protocolRuns
            .where((run) => run.status != ProtocolRunStatus.completed)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return _buildHomeSectionFrame(
      key: const Key('home-resume-work-section'),
      title: 'Running Protocols',
      expanded: expanded,
      trailing: TextButton(
        key: const Key('home-show-running-library'),
        onPressed: () => _openLibraryTab(2),
        child: const Text('Show in Library'),
      ),
      child: visibleRuns.isNotEmpty
          ? LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 760;
                final width = twoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final run in visibleRuns)
                      SizedBox(
                        width: width,
                        child: _buildHomeRunningProtocolCard(run),
                      ),
                  ],
                );
              },
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: const Text(
                'No protocols running.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
    );
  }

  // ignore: unused_element
  Widget _buildTasksSection({bool expanded = false}) {
    final sortedTasks = List<Task>.from(_todayTasks)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final visibleTasks = sortedTasks
        .where(_taskMatchesSelectedProject)
        .toList();
    final remaining = visibleTasks
        .where((task) => task.status != TaskStatus.completed)
        .length;
    final completed = visibleTasks.where((task) => task.isDone).length;
    return _buildHomeSectionFrame(
      key: const Key('home-today-tasks-section'),
      title: 'Tasks',
      expanded: expanded,
      trailing: TextButton.icon(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add task'),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$remaining ${remaining == 1 ? 'task' : 'tasks'} remaining',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: const Key('home-task-project-filter'),
                    tooltip: 'Filter tasks by project',
                    initialValue: _taskProjectFilter ?? '__all__',
                    onSelected: (value) => setState(
                      () => _taskProjectFilter = value == '__all__'
                          ? null
                          : value,
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
                        value: _unassignedTaskFilter,
                        child: ListTile(
                          leading: Icon(Icons.folder_off_outlined),
                          title: Text('Unassigned'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      ..._projects.map(
                        (project) => PopupMenuItem(
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
                      ),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.filter_list, size: 16),
                      label: Text(_taskFilterLabel()),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoadingTasks)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_todayTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No tasks yet.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Add something to do in the lab.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else if (visibleTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 14, 12, 18),
                child: Text(
                  'No tasks in this project.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else ...[
              ...visibleTasks.asMap().entries.map((entry) {
                return Column(
                  children: [
                    _buildTaskItem(entry.value, entry.key),
                    if (entry.key < visibleTasks.length - 1)
                      const Divider(height: 1, indent: 54),
                  ],
                );
              }),
              if (completed > 0) ...[
                const Divider(height: 1),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('home-archive-completed-tasks'),
                    onPressed: _archiveVisibleCompletedTasks,
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    label: Text('Move completed to history ($completed)'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildQuickStartSection({bool expanded = false}) {
    return _buildHomeSectionFrame(
      key: const Key('home-quick-start-section'),
      title: 'Quick Tools',
      expanded: expanded,
      child: _buildWorkspaceActions(expanded: expanded),
    );
  }

  Widget _buildWorkspaceActions({bool expanded = false}) {
    final actions = [
      _WorkspaceAction(
        icon: Icons.biotech,
        label: 'Master Mix',
        subtitle: 'Calculator',
        color: Colors.blue,
        onTap: () => _openQuickTool(TableTool.masterMix),
      ),
      _WorkspaceAction(
        icon: Icons.water_drop,
        label: 'Serial Dilution',
        subtitle: 'Standard curve',
        color: Colors.cyan,
        onTap: () => _openQuickTool(TableTool.serialDilution),
      ),
      _WorkspaceAction(
        icon: Icons.grid_on,
        label: 'Plate Layout',
        subtitle: 'Well designer',
        color: Colors.orange,
        onTap: () => _openQuickTool(TableTool.plateLayout),
      ),
      _WorkspaceAction(
        icon: Icons.color_lens,
        label: 'Staining',
        subtitle: 'Panel generator',
        color: Colors.indigo,
        onTap: () => _openQuickTool(TableTool.staining),
      ),
      _WorkspaceAction(
        icon: Icons.table_chart,
        label: 'Generic Table',
        subtitle: 'Custom grid',
        color: Colors.grey,
        onTap: () => _openQuickTool(TableTool.generic),
      ),
      _WorkspaceAction(
        icon: Icons.file_upload_outlined,
        label: 'Import Table',
        subtitle: 'From CSV or Excel',
        color: AppColors.primary,
        onTap: () => _openQuickTool(TableTool.importTable),
      ),
    ];
    final visibleActions = _showAllQuickTools ? actions : actions.take(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (var index = 0; index < visibleActions.length; index++) ...[
                _buildWorkspaceAction(visibleActions.elementAt(index)),
                if (index < visibleActions.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('home-toggle-quick-tools'),
            onPressed: () =>
                setState(() => _showAllQuickTools = !_showAllQuickTools),
            icon: Icon(
              _showAllQuickTools ? Icons.expand_less : Icons.expand_more,
            ),
            label: Text(_showAllQuickTools ? 'Show less' : 'More tools'),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceAction(_WorkspaceAction action) {
    return ListTile(
      leading: Icon(action.icon, color: action.color),
      title: Text(action.label),
      subtitle: Text(action.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: action.onTap,
    );
  }

  Future<void> _openQuickTool(TableTool tool) async {
    await openTableTool(context, tool, standaloneMode: true);
    await _loadProjects();
  }

  // ignore: unused_element
  Widget _buildProjectsSection({bool expanded = false}) {
    final projects = List<Project>.from(_projects)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _buildHomeSectionFrame(
      key: const Key('home-projects-section'),
      title: 'Projects',
      expanded: expanded,
      trailing: TextButton.icon(
        onPressed: _openProjectCreation,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('New project'),
      ),
      child: projects.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Organize your work into projects.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => SizedBox(
                        width: 180,
                        child: _buildProjectTile(projects[index]),
                      ),
                    ),
                  );
                }
                final columns = constraints.maxWidth >= 1000 ? 4 : 3;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final project in projects)
                      SizedBox(
                        width: width,
                        height: 64,
                        child: _buildProjectTile(project),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildProjectTile(Project project) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Color(project.colorValue).withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(project: project),
          ),
        ).then((_) => _refreshHome()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              project.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSyncStatusCard({bool expanded = false}) {
    final signedIn =
        _signedInUser != null && _authService.hasAuthenticatedAccount;
    final label = _isSyncing
        ? 'SYNCING NOW'
        : !signedIn
        ? 'LOCAL DATA ONLY'
        : _syncHasErrors
        ? 'SYNC NEEDS ATTENTION'
        : _syncHasPendingChanges
        ? 'CHANGES READY TO SYNC'
        : 'ALL SYSTEMS ONLINE';
    final statusColor = _syncHasErrors ? AppColors.warning : AppColors.success;
    final detail = !signedIn
        ? 'Sign in to keep protocols and lab data backed up in Google Drive.'
        : _lastSyncAt == null
        ? 'Google Drive is connected and ready to keep your data secure.'
        : 'Last cloud sync ${_relativeTime(_lastSyncAt!)}. Your ProtocolFlow data is backed up.';

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: expanded ? 210 : 0),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isSyncing || _isResettingData || _isManagingBackup
              ? null
              : () => _runDriveSync(promptIfNecessary: true),
          child: Padding(
            padding: EdgeInsets.all(expanded ? 32 : 22),
            child: Stack(
              children: [
                Positioned(
                  right: -8,
                  bottom: -14,
                  child: Icon(
                    Icons.cloud_done_outlined,
                    size: 100,
                    color: AppColors.onPrimary.withValues(alpha: 0.11),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sync Status',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_isSyncing)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        else
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      detail,
                      style: TextStyle(
                        color: AppColors.onPrimary.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildUserGuideCard({bool expanded = false}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _selectPage(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: expanded ? 240 : 150,
              child: _buildUserGuideBanner(expanded: expanded),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 24 : 18,
                expanded ? 22 : 16,
                expanded ? 24 : 18,
                expanded ? 24 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ProtocolFlow User Guide',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Explore protocols, lab tools, data management, and sync workflows.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _selectPage(7),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Read Guide'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGuideBanner({required bool expanded}) {
    return ColoredBox(
      key: const Key('user-guide-banner'),
      color: AppColors.primary,
      child: Stack(
        children: [
          Positioned(
            right: expanded ? 24 : 10,
            bottom: expanded ? -28 : -20,
            child: Icon(
              Icons.menu_book_outlined,
              size: expanded ? 190 : 125,
              color: AppColors.onPrimary.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(expanded ? 32 : 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: expanded ? 64 : 52,
                  height: expanded ? 64 : 52,
                  decoration: BoxDecoration(
                    color: AppColors.onPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.onPrimary.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: AppColors.onPrimary,
                    size: expanded ? 34 : 28,
                  ),
                ),
                SizedBox(height: expanded ? 20 : 14),
                const Text(
                  'USER GUIDE',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.cloud_sync_outlined),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Drive synchronization keeps protocols, tables, and history available across devices.',
                                softWrap: true,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Drive sync is currently in limited testing. Your Google account must be approved before you can connect. Contact Aviv at Aviv7001@gmail.com and ask for access.',
                                softWrap: true,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    final action = FilledButton.icon(
                      onPressed:
                          _isSyncing || _isResettingData || _isManagingBackup
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
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const information = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.import_export_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backup and restore',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Export all local app data or private Google Drive sync data, and restore ProtocolFlow backup files.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    final action = FilledButton.icon(
                      onPressed:
                          _isManagingBackup || _isSyncing || _isResettingData
                          ? null
                          : _showImportExportMenu,
                      icon: const Icon(Icons.backup_outlined),
                      label: Text(
                        _isManagingBackup ? 'Working' : 'Manage backups',
                      ),
                    );
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          information,
                          const SizedBox(height: 16),
                          action,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        const Expanded(child: information),
                        const SizedBox(width: 16),
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
                    const information = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.warning_amber_outlined,
                            color: AppColors.error,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset app data',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Permanently clear ProtocolFlow data stored locally, in the private Google Drive sync area, or both.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    final action = OutlinedButton.icon(
                      onPressed:
                          _isResettingData || _isSyncing || _isManagingBackup
                          ? null
                          : _showResetDataDialog,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        _isResettingData ? 'Resetting' : 'Reset data',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    );
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          information,
                          const SizedBox(height: 16),
                          action,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        const Expanded(child: information),
                        const SizedBox(width: 16),
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

  Future<void> _showResetDataDialog() async {
    final target = await showDialog<AppDataResetTarget>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose data to reset'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, AppDataResetTarget.local),
            child: const ListTile(
              leading: Icon(
                Icons.phone_android_outlined,
                color: AppColors.error,
              ),
              title: Text('Clear local data'),
              subtitle: Text('Keep Google Drive sync files'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, AppDataResetTarget.drive),
            child: const ListTile(
              leading: Icon(Icons.cloud_off_outlined, color: AppColors.error),
              title: Text('Clear Drive data'),
              subtitle: Text('Keep data on this device'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, AppDataResetTarget.both),
            child: const ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: AppColors.error,
              ),
              title: Text('Clear local and Drive data'),
              subtitle: Text('Remove both copies'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined, color: AppColors.error),
        title: const Text('Permanently reset data?'),
        content: Text(_resetWarning(target)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reset permanently'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _resetAppData(target);
  }

  String _resetWarning(AppDataResetTarget target) {
    const local =
        'Local reset deletes protocols, templates, completed and running protocols, tasks, projects, saved tables, Measuring Tools, and app settings on this device. Your signed-in Google account remains connected.';
    const drive =
        'Drive reset permanently deletes ProtocolFlow private synchronization files. Published protocol share files and QR links are not deleted.';
    return switch (target) {
      AppDataResetTarget.local =>
        '$local\n\nDrive data remains and may be downloaded by a later sync.',
      AppDataResetTarget.drive =>
        '$drive\n\nLocal data remains and may be uploaded again by a later sync.',
      AppDataResetTarget.both => '$local\n\n$drive\n\nThis cannot be undone.',
    };
  }

  Future<void> _resetAppData(AppDataResetTarget target) async {
    setState(() => _isResettingData = true);
    try {
      final result = await AppDataResetService().reset(target);
      if (target != AppDataResetTarget.drive) {
        activeProtocol = null;
        runningProtocols.clear();
        completedProtocols.clear();
        protocolRuns.clear();
        _todayTasks = [];
        _projects = [];
        await _refreshHome();
      }
      if (!mounted) return;
      final driveDetail = result.deletedDriveFiles == 0
          ? ''
          : ' ${result.deletedDriveFiles} Drive file(s) deleted.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ProtocolFlow data reset complete.$driveDetail'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset failed: $error')));
    } finally {
      if (mounted) setState(() => _isResettingData = false);
    }
  }

  Future<void> _handleImportExportAction(String value) async {
    setState(() => _isManagingBackup = true);
    try {
      if (value == 'export_local') {
        await _exportService.exportLocalData(
          userInitials: _signedInUser?.initials,
        );
      } else if (value == 'export_drive') {
        await _exportService.exportDriveData();
      } else if (value == 'export_templates') {
        await _exportService.exportTemplates();
      } else if (value == 'export_history') {
        await _exportService.exportHistory();
      } else if (value == 'import') {
        final result = await _importService.importJson(
          confirmRestore: _confirmBackupRestore,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
        if (result.success) await _refreshHome();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup operation failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isManagingBackup = false);
    }
  }

  Future<bool> _confirmBackupRestore(BackupRestorePreview preview) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BackupRestorePreviewDialog(preview: preview),
    );
    return confirmed == true;
  }

  Future<void> _showImportExportMenu() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('manage-backups-dialog'),
        title: const Row(
          children: [
            Icon(Icons.backup_outlined, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(child: Text('Manage backups')),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBackupMenuItem(
                    dialogContext,
                    value: 'import',
                    icon: Icons.file_upload_outlined,
                    title: 'Import backup or data file',
                    subtitle: 'Preview contents before restoring',
                  ),
                  const Divider(height: 1),
                  _buildBackupMenuItem(
                    dialogContext,
                    value: 'export_local',
                    icon: Icons.phone_android_outlined,
                    title: 'Export local backup',
                    subtitle: 'All app data and settings on this device',
                  ),
                  const Divider(height: 1),
                  _buildBackupMenuItem(
                    dialogContext,
                    value: 'export_drive',
                    icon: Icons.cloud_download_outlined,
                    title: 'Export Drive backup',
                    subtitle: 'All private ProtocolFlow sync files',
                  ),
                  const Divider(height: 1),
                  _buildBackupMenuItem(
                    dialogContext,
                    value: 'export_templates',
                    icon: Icons.description_outlined,
                    title: 'Export templates',
                  ),
                  const Divider(height: 1),
                  _buildBackupMenuItem(
                    dialogContext,
                    value: 'export_history',
                    icon: Icons.history,
                    title: 'Export history',
                  ),
                ],
              ),
            ),
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
    if (selected != null) await _handleImportExportAction(selected);
  }

  Widget _buildBackupMenuItem(
    BuildContext dialogContext, {
    required String value,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(dialogContext, value),
    );
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
        if (constraints.maxWidth < 300) {
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

  Widget _buildHomeSectionFrame({
    required Key key,
    required String title,
    required Widget child,
    required bool expanded,
    Widget trailing = const SizedBox.shrink(),
  }) {
    return Container(
      key: key,
      padding: EdgeInsets.all(expanded ? 20 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(title, trailing: trailing),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
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
    final project = _projectFor(task.projectId);
    Protocol? linkedProtocol;
    if (task.protocolId != null) {
      for (final item in _protocols) {
        if (item.id == task.protocolId) {
          linkedProtocol = item;
          break;
        }
      }
    }
    final contextChips = <Widget>[
      if (project != null)
        Chip(
          avatar: Icon(
            Icons.folder_outlined,
            size: 15,
            color: Color(project.colorValue),
          ),
          label: Text(project.name),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      if (linkedProtocol != null)
        Chip(
          avatar: const Icon(Icons.description_outlined, size: 15),
          label: Text(linkedProtocol.title),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
    ];
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
                      if (contextChips.isNotEmpty) const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [_buildTaskStatusMenu(task), ...contextChips],
                      ),
                    ],
                  ),
                ),
                _buildTaskActions(task),
              ],
            ),
          );
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: number,
          title: title,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [?description, ...contextChips],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [_buildTaskStatusMenu(task), _buildTaskActions(task)],
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
              child: ListTile(
                leading: Icon(
                  _taskStatusIcon(status),
                  color: _taskStatusColor(status),
                ),
                title: Text(_taskStatusLabel(status)),
                contentPadding: EdgeInsets.zero,
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

  Widget _buildTaskActions(Task task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.isDone)
          IconButton(
            key: Key('archive-task-${task.id}'),
            tooltip: 'Move to history',
            onPressed: () => _archiveTask(task),
            icon: const Icon(Icons.archive_outlined),
          ),
        _buildTaskOptions(task),
      ],
    );
  }

  Widget _buildTaskOptions(Task task) {
    return PopupMenuButton<String>(
      tooltip: 'Task options',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'delete') _removeTask(task);
        if (value == 'project:') _assignTaskProject(task, null);
        if (value.startsWith('project:') && value != 'project:') {
          _assignTaskProject(task, value.substring('project:'.length));
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            leading: Icon(Icons.folder_outlined),
            title: Text('Assign project'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'project:',
          child: ListTile(
            leading: Icon(Icons.folder_off_outlined),
            title: Text('Unassigned'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        for (final project in _projects)
          PopupMenuItem<String>(
            value: 'project:${project.id}',
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
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.error),
            title: Text('Delete task'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
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

  Project? _projectFor(String? projectId) {
    if (projectId == null || projectId.isEmpty) return null;
    for (final project in _projects) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  Widget _buildHomeRunningProtocolCard(ProtocolRun run) {
    final state = run.toActiveProtocol();
    final protocol = state.protocol;
    final steps = protocol.sortedSteps;
    final currentIdx = state.currentStepIndex;
    final isPaused = run.status == ProtocolRunStatus.paused;
    final currentStep = currentIdx >= 0 && currentIdx < steps.length
        ? steps[currentIdx]
        : null;
    String detail;
    if (isPaused) {
      final phase = currentStep?.phaseName?.trim();
      final step = currentStep == null
          ? 'Preparing'
          : 'Step ${currentIdx + 1}: ${currentStep.title}';
      detail = phase == null || phase.isEmpty
          ? 'Current step: $step'
          : 'Current phase: $phase\nCurrent step: $step';
    } else {
      final currentPhase = currentStep?.phaseName?.trim();
      String? nextPhase;
      for (var index = currentIdx + 1; index < steps.length; index++) {
        final candidate = steps[index].phaseName?.trim();
        if (candidate != null &&
            candidate.isNotEmpty &&
            candidate != currentPhase) {
          nextPhase = candidate;
          break;
        }
      }
      if (nextPhase != null) {
        detail = 'Next phase: $nextPhase';
      } else if (currentPhase != null && currentPhase.isNotEmpty) {
        detail = 'Current phase: $currentPhase';
      } else if (currentIdx + 1 < steps.length) {
        detail = 'Next step: ${steps[currentIdx + 1].title}';
      } else {
        detail = currentStep == null ? 'Preparing' : currentStep.title;
      }
    }
    final completedCount = state.completedStepIds.length;
    final totalSteps = steps.length;
    final progress = totalSteps == 0 ? 0.0 : completedCount / totalSteps;
    void openState() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ProtocolDetailScreen(protocol: protocol, activeState: state),
        ),
      ).then((_) => setState(() {}));
    }

    return RunningProtocolSummaryCard(
      state: state,
      detail: detail,
      progressValue: '${(progress * 100).toInt()}% complete',
      keyPrefix: 'home-running',
      margin: EdgeInsets.zero,
      dashboardCompact: true,
      paused: isPaused,
      onTap: openState,
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DefaultTextStyle.merge(
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        height: 1.35,
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.outline,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeUtilityCard extends StatelessWidget {
  const _HomeUtilityCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 24),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.outline,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (actionLabel == null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(actionLabel!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeEmptyAction extends StatelessWidget {
  const _HomeEmptyAction({
    required this.message,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String message;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      ],
    );
  }
}

class _ProtocolCounts extends StatelessWidget {
  const _ProtocolCounts({
    required this.protocols,
    required this.templates,
    required this.running,
    required this.completed,
    required this.onOpenTab,
  });

  final int protocols;
  final int templates;
  final int running;
  final int completed;
  final void Function(int tabIndex) onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ProtocolCount(
                value: protocols,
                label: 'Protocols',
                onTap: () => onOpenTab(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProtocolCount(
                value: templates,
                label: 'Templates',
                onTap: () => onOpenTab(0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ProtocolCount(
                value: running,
                label: 'Running',
                highlighted: true,
                onTap: () => onOpenTab(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProtocolCount(
                value: completed,
                label: 'Completed',
                onTap: () => onOpenTab(3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProtocolCount extends StatelessWidget {
  const _ProtocolCount({
    required this.value,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final int value;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      key: Key('home-protocol-count-${label.toLowerCase()}'),
      color: highlighted ? AppColors.primaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlighted
            ? BorderSide(color: AppColors.primary.withValues(alpha: 0.25))
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(highlighted ? 10 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: highlighted
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: highlighted
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!highlighted) return content;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 130),
        child: content,
      ),
    );
  }
}

class _WorkspaceAction {
  const _WorkspaceAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}
