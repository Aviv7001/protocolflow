import '../features/today_tasks/services/task_service.dart';
import '../models/active_protocol.dart';
import '../models/completed_protocol.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../models/task.dart';
import 'storage_service.dart';
import 'dashboard_activity_service.dart';

class DashboardData {
  final List<Protocol> protocols;
  final List<CompletedProtocol> completedProtocols;
  final List<ActiveProtocol> runningProtocols;
  final List<ProtocolTable> savedTables;
  final List<Task> todayTasks;
  final List<Task> taskHistory;
  final List<DashboardExportRecord> exports;
  final SavedTablesSyncState savedTablesSyncState;

  const DashboardData({
    required this.protocols,
    required this.completedProtocols,
    required this.runningProtocols,
    required this.savedTables,
    required this.todayTasks,
    required this.taskHistory,
    required this.exports,
    required this.savedTablesSyncState,
  });
}

class DashboardService {
  final StorageService storageService;
  final TaskService taskService;
  final DashboardActivityService activityService;

  DashboardService({
    StorageService? storageService,
    TaskService? taskService,
    DashboardActivityService? activityService,
  }) : storageService = storageService ?? StorageService(),
       taskService = taskService ?? TaskService(),
       activityService = activityService ?? DashboardActivityService();

  Future<DashboardData> load() async {
    final protocols = await storageService.loadProtocols();
    final completed = await storageService.loadCompletedProtocols();
    final running = await storageService.loadRunningProtocols();
    final active = await storageService.loadActiveProtocol();
    final savedTables = await storageService.loadSavedTables();
    final todayTasks = await taskService.loadTodayTasks();
    final taskHistory = await taskService.loadHistoryTasks();
    final exports = await activityService.loadExports();
    final savedTablesSyncState = await storageService
        .loadSavedTablesSyncState();

    final allRunning = <ActiveProtocol>[
      ?active,
      ...running.where(
        (item) => active == null || item.protocol.id != active.protocol.id,
      ),
    ];

    return DashboardData(
      protocols: protocols,
      completedProtocols: completed,
      runningProtocols: allRunning,
      savedTables: savedTables,
      todayTasks: todayTasks,
      taskHistory: taskHistory,
      exports: exports,
      savedTablesSyncState: savedTablesSyncState,
    );
  }
}
