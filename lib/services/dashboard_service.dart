import '../features/today_tasks/services/task_service.dart';
import '../features/measuring_tools/models/measuring_tool.dart';
import '../features/measuring_tools/services/measuring_tool_service.dart';
import '../models/active_protocol.dart';
import '../models/completed_protocol.dart';
import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../models/task.dart';
import 'storage_service.dart';
import 'dashboard_activity_service.dart';

class DashboardData {
  final List<Protocol> protocols;
  final List<CompletedProtocol> completedProtocols;
  final List<ActiveProtocol> runningProtocols;
  final List<Project> projects;
  final List<ProtocolTable> savedTables;
  final List<MeasuringTool> measuringTools;
  final List<Task> todayTasks;
  final List<Task> taskHistory;
  final List<DashboardExportRecord> exports;
  final SavedTablesSyncState savedTablesSyncState;
  final SyncBundleState projectsSyncState;
  final SyncBundleState completedProtocolsSyncState;
  final SyncBundleState tasksSyncState;
  final SyncBundleState measuringToolsSyncState;

  const DashboardData({
    required this.protocols,
    required this.completedProtocols,
    required this.runningProtocols,
    required this.projects,
    required this.savedTables,
    required this.measuringTools,
    required this.todayTasks,
    required this.taskHistory,
    required this.exports,
    required this.savedTablesSyncState,
    required this.projectsSyncState,
    required this.completedProtocolsSyncState,
    required this.tasksSyncState,
    required this.measuringToolsSyncState,
  });
}

class DashboardService {
  final StorageService storageService;
  final TaskService taskService;
  final MeasuringToolService measuringToolService;
  final DashboardActivityService activityService;

  DashboardService({
    StorageService? storageService,
    TaskService? taskService,
    MeasuringToolService? measuringToolService,
    DashboardActivityService? activityService,
  }) : storageService = storageService ?? StorageService(),
       taskService = taskService ?? TaskService(),
       measuringToolService =
           measuringToolService ?? MeasuringToolService.instance,
       activityService = activityService ?? DashboardActivityService();

  Future<DashboardData> load() async {
    final protocols = await storageService.loadProtocols();
    final completed = await storageService.loadCompletedProtocols();
    final running = await storageService.loadRunningProtocols();
    final active = await storageService.loadActiveProtocol();
    final projects = await storageService.loadProjects();
    final savedTables = await storageService.loadSavedTables();
    final measuringTools = await measuringToolService.loadTools();
    final todayTasks = await taskService.loadTodayTasks();
    final taskHistory = await taskService.loadHistoryTasks();
    final exports = await activityService.loadExports();
    final savedTablesSyncState = await storageService
        .loadSavedTablesSyncState();
    final projectsSyncState = await storageService.loadSyncBundleState(
      SyncBundleType.projects,
    );
    final completedProtocolsSyncState = await storageService
        .loadSyncBundleState(SyncBundleType.completedProtocols);
    final tasksSyncState = await storageService.loadSyncBundleState(
      SyncBundleType.tasks,
    );
    final measuringToolsSyncState = await storageService.loadSyncBundleState(
      SyncBundleType.measuringTools,
    );

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
      projects: projects,
      savedTables: savedTables,
      measuringTools: measuringTools,
      todayTasks: todayTasks,
      taskHistory: taskHistory,
      exports: exports,
      savedTablesSyncState: savedTablesSyncState,
      projectsSyncState: projectsSyncState,
      completedProtocolsSyncState: completedProtocolsSyncState,
      tasksSyncState: tasksSyncState,
      measuringToolsSyncState: measuringToolsSyncState,
    );
  }
}
