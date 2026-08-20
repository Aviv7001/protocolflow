import 'dart:convert';

import '../features/today_tasks/services/task_service.dart';
import '../features/measuring_tools/models/measuring_tool.dart';
import '../features/measuring_tools/services/measuring_tool_service.dart';
import '../models/active_protocol.dart';
import '../models/completed_protocol.dart';
import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../models/task.dart';
import '../models/protocol_run.dart';
import 'auth_service.dart';
import 'storage_service.dart';
import 'dashboard_activity_service.dart';
import 'drive_sync_service.dart';
import 'protocol_run_service.dart';

class DashboardFootprintSegment {
  final String label;
  final int localBytes;
  final int syncBytes;

  const DashboardFootprintSegment({
    required this.label,
    required this.localBytes,
    required this.syncBytes,
  });
}

class DashboardFootprint {
  final List<DashboardFootprintSegment> segments;
  final bool driveDataAvailable;
  final String? driveError;

  const DashboardFootprint({
    required this.segments,
    this.driveDataAvailable = false,
    this.driveError,
  });

  int get localBytes =>
      segments.fold(0, (sum, segment) => sum + segment.localBytes);
  int get syncBytes =>
      segments.fold(0, (sum, segment) => sum + segment.syncBytes);
}

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
  final DashboardFootprint footprint;
  final bool hasDriveAccount;

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
    required this.footprint,
    required this.hasDriveAccount,
  });
}

class DashboardService {
  final StorageService storageService;
  final TaskService taskService;
  final MeasuringToolService measuringToolService;
  final DashboardActivityService activityService;
  final Future<DriveAppDataFootprint> Function()? driveFootprintLoader;
  final bool Function()? hasDriveAccountResolver;

  DashboardService({
    StorageService? storageService,
    TaskService? taskService,
    MeasuringToolService? measuringToolService,
    DashboardActivityService? activityService,
    this.driveFootprintLoader,
    this.hasDriveAccountResolver,
  }) : storageService = storageService ?? StorageService(),
       taskService = taskService ?? TaskService(),
       measuringToolService =
           measuringToolService ?? MeasuringToolService.instance,
       activityService = activityService ?? DashboardActivityService();

  Future<DashboardData> load() async {
    final protocols = await storageService.loadProtocols();
    final runs = await ProtocolRunService.instance.loadRuns();
    final completed = runs
        .where((run) => run.status == ProtocolRunStatus.completed)
        .map((run) => run.toCompletedProtocol())
        .toList();
    final allRunning = runs
        .where((run) => run.status != ProtocolRunStatus.completed)
        .map((run) => run.toActiveProtocol())
        .toList();
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
    final hasDriveAccount =
        hasDriveAccountResolver?.call() ??
        AuthService.instance.hasAuthenticatedAccount;
    DriveAppDataFootprint? driveFootprint;
    String? driveError;
    if (hasDriveAccount) {
      try {
        driveFootprint =
            await (driveFootprintLoader?.call() ??
                DriveSyncService.instance.loadAppDataFootprint());
      } catch (error) {
        driveError = error.toString();
      }
    }

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
      footprint: _buildFootprint(
        protocols: protocols,
        completed: completed,
        projects: projects,
        savedTables: savedTables,
        measuringTools: measuringTools,
        todayTasks: todayTasks,
        taskHistory: taskHistory,
        driveFootprint: driveFootprint,
        driveError: driveError,
      ),
      hasDriveAccount: hasDriveAccount,
    );
  }

  DashboardFootprint _buildFootprint({
    required List<Protocol> protocols,
    required List<CompletedProtocol> completed,
    required List<Project> projects,
    required List<ProtocolTable> savedTables,
    required List<MeasuringTool> measuringTools,
    required List<Task> todayTasks,
    required List<Task> taskHistory,
    required DriveAppDataFootprint? driveFootprint,
    required String? driveError,
  }) {
    final protocolJson = protocols.map((item) => item.toJson()).toList();
    final projectJson = projects.map((item) => item.toJson()).toList();
    final completedJson = completed.map((item) => item.toJson()).toList();
    final tableJson = savedTables.map((item) => item.toJson()).toList();
    final todayJson = todayTasks.map((item) => item.toJson()).toList();
    final historyJson = taskHistory.map((item) => item.toJson()).toList();
    final toolJson = measuringTools.map((item) => item.toJson()).toList();

    return DashboardFootprint(
      segments: [
        DashboardFootprintSegment(
          label: 'Projects',
          localBytes: _compactBytes(projectJson),
          syncBytes: driveFootprint?.bytesFor('Projects') ?? 0,
        ),
        DashboardFootprintSegment(
          label: 'Protocols',
          localBytes: _compactBytes(protocolJson),
          syncBytes: driveFootprint?.bytesFor('Protocols') ?? 0,
        ),
        DashboardFootprintSegment(
          label: 'Completed',
          localBytes: _compactBytes(completedJson),
          syncBytes: driveFootprint?.bytesFor('Completed') ?? 0,
        ),
        DashboardFootprintSegment(
          label: 'Tables',
          localBytes: _compactBytes(tableJson),
          syncBytes: driveFootprint?.bytesFor('Tables') ?? 0,
        ),
        DashboardFootprintSegment(
          label: 'Tasks',
          localBytes: _compactBytes(todayJson) + _compactBytes(historyJson),
          syncBytes: driveFootprint?.bytesFor('Tasks') ?? 0,
        ),
        DashboardFootprintSegment(
          label: 'Measuring',
          localBytes: _compactBytes(toolJson),
          syncBytes: driveFootprint?.bytesFor('Measuring') ?? 0,
        ),
        if ((driveFootprint?.bytesFor('Sync metadata') ?? 0) > 0)
          DashboardFootprintSegment(
            label: 'Sync metadata',
            localBytes: 0,
            syncBytes: driveFootprint!.bytesFor('Sync metadata'),
          ),
      ],
      driveDataAvailable: driveFootprint != null,
      driveError: driveError,
    );
  }

  int _compactBytes(Object value) => utf8.encode(jsonEncode(value)).length;
}
