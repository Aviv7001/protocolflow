import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/task.dart';

void main() {
  test('task project assignment survives JSON and can be cleared', () {
    final task = Task(
      id: 'task-1',
      title: 'Prepare samples',
      description: '',
      createdAt: DateTime.utc(2026, 8, 12),
      projectId: 'project-1',
    );

    final restored = Task.fromJson(task.toJson());
    expect(restored.projectId, 'project-1');
    expect(restored.copyWith(clearProjectId: true).projectId, isNull);
  });

  test('task protocol and run links are optional and round-trip', () {
    final linked = Task(
      id: 'task-linked',
      title: 'Read plate',
      description: '',
      createdAt: DateTime.utc(2026, 8, 13),
      projectId: 'project-1',
      protocolId: 'protocol-1',
      runId: 'RUN-1',
    );
    final restored = Task.fromJson(linked.toJson());
    expect(restored.protocolId, 'protocol-1');
    expect(restored.runId, 'RUN-1');
    expect(restored.copyWith(clearProtocolId: true).protocolId, isNull);
    expect(restored.copyWith(clearRunId: true).runId, isNull);

    final legacy = Task.fromJson({
      'id': 'legacy',
      'title': 'Legacy task',
      'description': '',
      'createdAt': DateTime.utc(2026, 8, 13).toIso8601String(),
    });
    expect(legacy.protocolId, isNull);
    expect(legacy.runId, isNull);
  });

  test('saved table project assignment survives JSON and can be cleared', () {
    final table = ProtocolTable(
      id: 'table-1',
      title: 'Results',
      projectId: 'project-1',
      createdAt: DateTime.utc(2026, 8, 14),
    );

    final restored = ProtocolTable.fromJson(table.toJson());
    expect(restored.projectId, 'project-1');
    expect(restored.createdAt, DateTime.utc(2026, 8, 14));
    expect(restored.copyWith(clearProjectId: true).projectId, isNull);
  });

  test('legacy task and table JSON remain unassigned', () {
    final task = Task.fromJson({
      'id': 'legacy-task',
      'title': 'Legacy',
      'description': '',
      'createdAt': DateTime.utc(2026).toIso8601String(),
    });
    final table = ProtocolTable.fromJson({
      'id': 'legacy-table',
      'title': 'Legacy',
    });

    expect(task.projectId, isNull);
    expect(table.projectId, isNull);
    expect(table.createdAt, isNull);
  });
}
