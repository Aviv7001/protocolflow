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
import 'auth_service.dart';
import 'storage_service.dart';
import 'dashboard_activity_service.dart';

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

  const DashboardFootprint({required this.segments});

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
      footprint: _buildFootprint(
        protocols: protocols,
        completed: completed,
        projects: projects,
        savedTables: savedTables,
        measuringTools: measuringTools,
        todayTasks: todayTasks,
        taskHistory: taskHistory,
      ),
      hasDriveAccount: AuthService.instance.hasAuthenticatedAccount,
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
  }) {
    final protocolJson = protocols.map((item) => item.toJson()).toList();
    final projectJson = projects.map((item) => item.toJson()).toList();
    final completedJson = completed.map((item) => item.toJson()).toList();
    final tableJson = savedTables.map((item) => item.toJson()).toList();
    final todayJson = todayTasks.map((item) => item.toJson()).toList();
    final historyJson = taskHistory.map((item) => item.toJson()).toList();
    final toolJson = measuringTools.map((item) => item.toJson()).toList();

    final taskPayload = {
      'updatedAt': DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toIso8601String(),
      'today': todayJson,
      'history': historyJson,
    };
    final measuringPayload = {
      'updatedAt': DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toIso8601String(),
      'tools': toolJson,
    };
    final projectPayload = {
      'updatedAt': DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toIso8601String(),
      'projects': projectJson,
    };

    return DashboardFootprint(
      segments: [
        DashboardFootprintSegment(
          label: 'Projects',
          localBytes: _compactBytes(projectJson),
          syncBytes: _prettyBytes(projectPayload),
        ),
        DashboardFootprintSegment(
          label: 'Protocols',
          localBytes: _compactBytes(protocolJson),
          syncBytes: protocolJson.fold<int>(
            0,
            (sum, item) => sum + _prettyBytes(item),
          ),
        ),
        DashboardFootprintSegment(
          label: 'Completed',
          localBytes: _compactBytes(completedJson),
          syncBytes: completedJson.fold<int>(
            0,
            (sum, item) => sum + _prettyBytes(item),
          ),
        ),
        DashboardFootprintSegment(
          label: 'Tables',
          localBytes: _compactBytes(tableJson),
          syncBytes: _prettyBytes(tableJson),
        ),
        DashboardFootprintSegment(
          label: 'Tasks',
          localBytes: _compactBytes(todayJson) + _compactBytes(historyJson),
          syncBytes: _prettyBytes(taskPayload),
        ),
        DashboardFootprintSegment(
          label: 'Measuring',
          localBytes: _compactBytes(toolJson),
          syncBytes: _prettyBytes(measuringPayload),
        ),
      ],
    );
  }

  int _compactBytes(Object value) => utf8.encode(jsonEncode(value)).length;

  int _prettyBytes(Object value) =>
      utf8.encode(const JsonEncoder.withIndent('  ').convert(value)).length;
}
