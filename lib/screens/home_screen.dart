import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/active_protocol.dart';
import '../models/protocol.dart';
import '../models/project.dart';
import '../data/completed_protocols_data.dart';
import '../features/today_tasks/services/task_service.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/running_protocol_summary_card.dart';
import '../widgets/sync_preview_dialog.dart';
import '../features/measuring_tools/screens/measuring_tools_manager_screen.dart';
import 'lab_tools_screen.dart';
import 'library_screen.dart';
import 'projects_screen.dart';
import 'run_protocol_screen.dart';
import 'protocol_detail_screen.dart';
import 'saved_tables_screen.dart';
import 'dashboard_screen.dart';
import 'user_guide_screen.dart';
import 'shared_protocol_import_screen.dart';
import 'shared_protocol_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialLibraryTabIndex});

  final int? initialLibraryTabIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService _taskService = TaskService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService.instance;
  final ExportService _exportService = ExportService();
  final ImportService _importService = ImportService();
  List<Task> _todayTasks = [];
  List<Project> _projects = [];
  bool _isLoadingTasks = true;
  bool _areTasksShrunk = false;
  bool _isSigningIn = false;
  bool _isSyncing = false;
  bool _hasAttemptedStartupSync = false;
  bool _syncHasErrors = false;
  bool _syncHasPendingChanges = false;
  DateTime? _lastSyncAt;
  int _selectedDesktopIndex = 0;
  int _selectedPrimaryIndex = 0;
  int _libraryInitialTabIndex = 1;
  String? _libraryInitialProjectId;
  bool _isSidebarOpen = false;
  AppUser? _signedInUser;
  StreamSubscription<AppUser?>? _userSubscription;

  @override
  void initState() {
    super.initState();
    final initialLibraryTabIndex = widget.initialLibraryTabIndex;
    if (initialLibraryTabIndex != null) {
      _libraryInitialTabIndex = initialLibraryTabIndex;
      _selectedDesktopIndex = 2;
      _selectedPrimaryIndex = initialLibraryTabIndex == 2 ? 3 : 1;
    }
    _loadTasks();
    _loadProjects();
    _loadSyncHealth();
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

  Future<void> _loadProjects() async {
    final projects = await _storageService.loadProjects();
    if (mounted) setState(() => _projects = projects);
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
        bottomNavigationBar: _buildResponsivePrimaryNavigation(),
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
        icon: Icons.menu_book_outlined,
        label: 'User Guide',
        onTap: () => _selectPage(7),
        selected: _selectedDesktopIndex == 7,
      ),
      _DesktopNavItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () => _selectPage(8),
        selected: _selectedDesktopIndex == 8,
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [for (final item in items) _buildSidebarButton(item)],
            ),
          ),
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
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: _isSidebarOpen ? 'Close sidebar' : 'Open sidebar',
            onPressed: _toggleSidebar,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: const EdgeInsets.all(8),
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ProtocolFlow',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Scan shared protocol',
            onPressed: _scanSharedProtocol,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: const EdgeInsets.all(8),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _selectPage(8),
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: const EdgeInsets.all(8),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: _signedInUser == null ? 'Sign in' : 'Account',
            onPressed: _isSigningIn ? null : _handleProfilePressed,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: const EdgeInsets.all(5),
            icon: _buildUserAvatar(_signedInUser, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryNavigation() {
    return NavigationBar(
      height: 68,
      selectedIndex: _selectedPrimaryIndex,
      onDestinationSelected: _selectPrimaryDestination,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.library_books_outlined),
          selectedIcon: Icon(Icons.library_books),
          label: 'Library',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: 'Projects',
        ),
        NavigationDestination(
          icon: Icon(Icons.play_circle_outline),
          selectedIcon: Icon(Icons.play_circle),
          label: 'Active',
        ),
      ],
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
        _selectPage(3);
        return;
      case 3:
        _openLibraryTab(2);
        return;
    }
  }

  void _toggleSidebar() {
    setState(() => _isSidebarOpen = !_isSidebarOpen);
  }

  void _selectPage(int index) {
    setState(() {
      _selectedDesktopIndex = index;
      if (index == 0) _selectedPrimaryIndex = 0;
      if (index == 3) _selectedPrimaryIndex = 2;
    });
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
      _selectedPrimaryIndex = tabIndex == 2 ? 3 : 1;
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
      return const UserGuideScreen(embedded: true);
    }
    if (_selectedDesktopIndex == 8) {
      return _buildSettingsWorkspace();
    }

    return RefreshIndicator(
      onRefresh: _refreshHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1800),
            child: _buildHomeWorkspace(),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final greeting = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello ${_signedInUser?.displayName ?? 'there'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Resume lab work, start common workflows, and keep your data in sync.',
              softWrap: true,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        );
        final primaryColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTasksSection(expanded: desktop),
            const SizedBox(height: 24),
            _buildResumeWorkSection(expanded: desktop),
          ],
        );
        final secondaryColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildQuickStartSection(expanded: desktop),
            const SizedBox(height: 24),
            _buildSyncStatusCard(expanded: desktop),
            const SizedBox(height: 20),
            _buildUserGuideCard(expanded: desktop),
          ],
        );

        if (!desktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              greeting,
              const SizedBox(height: 28),
              primaryColumn,
              const SizedBox(height: 24),
              secondaryColumn,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            greeting,
            const SizedBox(height: 40),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: primaryColumn),
                const SizedBox(width: 32),
                Expanded(flex: 2, child: secondaryColumn),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardWorkspace() {
    return const DashboardScreen();
  }

  Widget _buildResumeWorkSection({bool expanded = false}) {
    final visibleStates = <ActiveProtocol>[
      ?activeProtocol,
      ...runningProtocols.where(
        (state) =>
            activeProtocol == null ||
            state.protocol.id != activeProtocol!.protocol.id,
      ),
    ].take(3).toList();

    return _buildHomeSectionFrame(
      key: const Key('home-resume-work-section'),
      title: 'Resume Work',
      expanded: expanded,
      trailing: Text(
        '$_runningProtocolCount running ${_runningProtocolCount == 1 ? 'protocol' : 'protocols'}',
        key: const Key('home-running-count'),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: visibleStates.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < visibleStates.length; index++) ...[
                  _buildHomeRunningProtocolCard(
                    visibleStates[index],
                    isActive:
                        activeProtocol?.protocol.id ==
                        visibleStates[index].protocol.id,
                  ),
                  if (index < visibleStates.length - 1)
                    const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('home-view-all-running'),
                    onPressed: () => _openLibraryTab(2),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('View all running'),
                  ),
                ),
              ],
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 32 : 16,
                vertical: expanded ? 48 : 24,
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.surfaceContainer,
                    child: Icon(
                      Icons.science_outlined,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No protocols are currently running. Your active experiments will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _openLibraryTab(1),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open library'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTasksSection({bool expanded = false}) {
    final remaining = _todayTasks
        .where((task) => task.status != TaskStatus.completed)
        .length;
    return _buildHomeSectionFrame(
      key: const Key('home-today-tasks-section'),
      title: 'Today\'s Tasks',
      expanded: expanded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Task history',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/task_history'),
          ),
          IconButton(
            tooltip: _areTasksShrunk ? 'Expand tasks' : 'Shrink tasks',
            icon: Icon(_areTasksShrunk ? Icons.unfold_more : Icons.unfold_less),
            onPressed: () => setState(() => _areTasksShrunk = !_areTasksShrunk),
          ),
        ],
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'Today\'s Schedule',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '$remaining ${remaining == 1 ? 'task' : 'tasks'} remaining',
              ),
            ),
            if (!_areTasksShrunk) ...[
              const Divider(height: 1),
              if (_isLoadingTasks)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_todayTasks.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    expanded ? 58 : 30,
                    24,
                    expanded ? 42 : 18,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'No tasks for today. Start by adding a new laboratory action.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _showAddTaskDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Task'),
                      ),
                    ],
                  ),
                )
              else ...[
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
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartSection({bool expanded = false}) {
    return _buildHomeSectionFrame(
      key: const Key('home-quick-start-section'),
      title: 'Quick Start',
      expanded: expanded,
      child: _buildWorkspaceActions(expanded: expanded),
    );
  }

  Widget _buildWorkspaceActions({bool expanded = false}) {
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
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  height: expanded ? 156 : 128,
                  child: _buildWorkspaceAction(action, expanded: expanded),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildWorkspaceAction(
    _WorkspaceAction action, {
    required bool expanded,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: action.onTap,
        child: Padding(
          padding: EdgeInsets.all(expanded ? 20 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(action.icon, color: AppColors.primary, size: 26),
              SizedBox(height: expanded ? 20 : 14),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                action.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          onTap: _isSyncing
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

  Project? _projectFor(String? projectId) {
    if (projectId == null || projectId.isEmpty) return null;
    for (final project in _projects) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  Widget _buildHomeRunningProtocolCard(
    ActiveProtocol state, {
    required bool isActive,
  }) {
    final protocol = state.protocol;
    final steps = protocol.sortedSteps;
    final currentIdx = state.currentStepIndex;
    String status = 'Preparing';
    if (currentIdx >= 0 && currentIdx < steps.length) {
      final step = steps[currentIdx];
      status = 'Step ${currentIdx + 1}: ${step.title}';
      if (step.phaseName != null && step.phaseName!.isNotEmpty) {
        status = '${step.phaseName} - $status';
      }
    }
    final completedCount = state.completedStepIds.length;
    final totalSteps = steps.length;
    final progress = totalSteps == 0 ? 0.0 : completedCount / totalSteps;

    return RunningProtocolSummaryCard(
      state: state,
      detail: status,
      progressValue: '${(progress * 100).toInt()}% complete',
      project: _projectFor(protocol.projectId),
      keyPrefix: 'home-running',
      margin: EdgeInsets.zero,
      compact: true,
      compactActionLabel: isActive ? 'Resume' : null,
      onCompactAction: isActive ? _resumeProtocol : null,
      onTap: isActive
          ? _resumeProtocol
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProtocolDetailScreen(
                  protocol: protocol,
                  activeState: state,
                ),
              ),
            ).then((_) => setState(() {})),
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
