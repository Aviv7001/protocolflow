import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/task.dart';

void main() {
  group('Task status persistence', () {
    test('migrates legacy incomplete and completed tasks', () {
      final baseJson = {
        'id': 'task-1',
        'title': 'Prepare samples',
        'description': '',
        'createdAt': '2026-07-22T08:00:00.000',
      };

      expect(
        Task.fromJson({...baseJson, 'isDone': false}).status,
        TaskStatus.notStarted,
      );
      expect(
        Task.fromJson({...baseJson, 'isDone': true}).status,
        TaskStatus.completed,
      );
    });

    test('round trips the in-progress status', () {
      final task = Task(
        id: 'task-2',
        title: 'Run incubation',
        description: 'Plate A',
        status: TaskStatus.inProgress,
        createdAt: DateTime(2026, 7, 22, 9),
      );

      final restored = Task.fromJson(task.toJson());

      expect(restored.status, TaskStatus.inProgress);
      expect(restored.isDone, isFalse);
    });
  });
}
