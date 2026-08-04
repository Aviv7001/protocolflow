import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/measuring_tools/services/measuring_tool_service.dart';
import 'package:protocolflow/features/today_tasks/services/task_service.dart';
import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/task.dart';
import 'package:protocolflow/services/drive_sync_service.dart';
import 'package:protocolflow/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('damaged local bundle data stops sync validation', () async {
    SharedPreferences.setMockInitialValues({
      'projects_json': '{not-json',
      'today_tasks_json': '{}',
      'measuring_tools_json': 'null',
    });

    expect(StorageService().validateLocalSyncData(), throwsFormatException);
    expect(TaskService().validateLocalSyncData(), throwsFormatException);
    expect(
      MeasuringToolService.instance.validateLocalSyncData(),
      throwsFormatException,
    );
  });

  test('damaged running protocol data stops sync validation', () async {
    SharedPreferences.setMockInitialValues({'running_protocols_json': '{}'});

    expect(StorageService().validateLocalSyncData(), throwsFormatException);
  });

  test('damaged active protocol data stops sync validation', () async {
    SharedPreferences.setMockInitialValues({'active_protocol_json': '[]'});

    expect(StorageService().validateLocalSyncData(), throwsFormatException);
  });

  test('active run progress is included in the local sync journal', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final protocol = Protocol(
      id: 'running-protocol',
      title: 'Running protocol',
      objective: '',
      description: '',
      syncStatus: ProtocolSyncStatus.modified,
      steps: const [],
    );
    await storage.saveRunningProtocols([
      ActiveProtocol(
        protocol: protocol,
        currentStepIndex: 0,
        notes: const [],
        startedAt: DateTime(2026, 8, 4, 9),
      ),
    ]);
    await storage.saveActiveProtocol(
      ActiveProtocol(
        protocol: protocol,
        currentStepIndex: 2,
        notes: const [],
        startedAt: DateTime(2026, 8, 4, 9),
      ),
    );

    final records = await DriveSyncService.instance
        .buildLocalSyncRecordsForTesting();
    final run = records['runningProtocol::running-protocol'];

    expect(run, isNotNull);
    expect(run!.data!['currentStepIndex'], 2);
    expect((run.data!['protocol'] as Map).containsKey('syncStatus'), isFalse);
  });

  test('task sync payload replaces both task collections', () async {
    SharedPreferences.setMockInitialValues({});
    final service = TaskService();
    final local = Task(
      id: 'local',
      title: 'Local task',
      description: '',
      createdAt: DateTime(2026, 7, 23, 8),
    );
    await service.saveTodayTasks([local]);

    await service.replaceFromSyncPayload({
      'updatedAt': '2026-07-23T12:00:00.000Z',
      'today': [
        {
          'id': 'remote',
          'title': 'Remote task',
          'description': '',
          'status': TaskStatus.inProgress.name,
          'createdAt': '2026-07-23T10:00:00.000Z',
        },
      ],
      'history': [
        {
          'id': 'history',
          'title': 'Finished task',
          'description': '',
          'status': TaskStatus.completed.name,
          'createdAt': '2026-07-22T10:00:00.000Z',
          'completedAt': '2026-07-22T11:00:00.000Z',
        },
      ],
    });

    expect((await service.loadTodayTasks()).single.id, 'remote');
    expect((await service.loadHistoryTasks()).single.id, 'history');
    expect(
      (await service.buildSyncPayload())['updatedAt'],
      '2026-07-23T12:00:00.000Z',
    );
  });

  test('measuring tool sync payload replaces local configuration', () async {
    SharedPreferences.setMockInitialValues({});
    final service = MeasuringToolService.instance;

    await service.replaceFromSyncPayload({
      'updatedAt': '2026-07-23T12:00:00.000Z',
      'tools': [
        {
          'id': 'custom-pipette',
          'toolType': 'Micropipette',
          'toolName': 'Custom P20',
          'minVolumeUl': 2,
          'maxVolumeUl': 20,
          'incrementUl': 0.5,
          'accuracyRank': 3,
          'active': true,
        },
      ],
    });

    final tools = await service.loadTools();
    expect(tools.single.id, 'custom-pipette');
    expect(
      (await service.buildSyncPayload())['updatedAt'],
      '2026-07-23T12:00:00.000Z',
    );
  });

  test('project sync payload replaces project collection', () async {
    SharedPreferences.setMockInitialValues({});
    final service = StorageService();
    await service.saveProjects([
      Project(id: 'local-project', name: 'Local Project'),
    ]);

    await service.replaceProjectsFromSyncPayload({
      'updatedAt': '2026-07-23T12:00:00.000Z',
      'projects': [
        {'id': 'remote-project', 'name': 'Remote Project'},
      ],
    });

    final projects = await service.loadProjects();
    expect(projects.single.id, 'remote-project');
    expect(
      (await service.buildProjectsSyncPayload())['updatedAt'],
      '2026-07-23T12:00:00.000Z',
    );
  });
}
