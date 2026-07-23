import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/measuring_tools/services/measuring_tool_service.dart';
import 'package:protocolflow/features/today_tasks/services/task_service.dart';
import 'package:protocolflow/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
}
