import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/protocol.dart';

void main() {
  test('completed protocol preserves its run start time', () {
    final startedAt = DateTime(2026, 7, 22, 8);
    final completed = CompletedProtocol(
      id: 'completed-1',
      protocol: Protocol(
        id: 'protocol-1',
        title: 'BCA assay',
        objective: '',
        description: '',
        steps: const [],
      ),
      notes: const [],
      startedAt: startedAt,
      completedAt: startedAt.add(const Duration(hours: 2)),
      completedByName: 'Aviv Researcher',
    );

    final restored = CompletedProtocol.fromJson(completed.toJson());

    expect(restored.startedAt, startedAt);
    expect(restored.completedByName, 'Aviv Researcher');
    expect(restored.syncStatus, ProtocolSyncStatus.localOnly);
    expect(
      restored.completedAt.difference(restored.startedAt!),
      const Duration(hours: 2),
    );
  });
}
