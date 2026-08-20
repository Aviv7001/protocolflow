import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_run.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/services/protocol_run_service.dart';

void main() {
  Protocol protocol({String title = 'Original', String? projectId}) => Protocol(
    id: 'PT-20260813-AV-TEST',
    title: title,
    objective: '',
    description: '',
    projectId: projectId,
    steps: const [],
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('creation preserves source links and an immutable snapshot', () async {
    final service = ProtocolRunService();
    final source = protocol(projectId: 'project-1');
    final first = await service.createRunFromProtocol(source);
    final second = await service.createRunFromProtocol(source);

    expect(first.id, startsWith('RUN-'));
    expect(second.id, isNot(first.id));
    expect(first.protocolId, source.id);
    expect(first.projectId, 'project-1');
    expect(first.startedAt, isNotNull);
    expect(first.protocolSnapshot.title, 'Original');

    final edited = source.copyWith(title: 'Edited later');
    expect(edited.title, 'Edited later');
    expect(
      (await service.getRun(first.id))!.protocolSnapshot.title,
      'Original',
    );
  });

  test('pause and resume preserve one run and all execution state', () async {
    final service = ProtocolRunService();
    var run = await service.createRunFromProtocol(protocol());
    final note = StepNote(
      id: 'note-1',
      stepId: 'step-1',
      note: 'Keep this',
      createdAt: DateTime.utc(2026, 8, 13),
    );
    run = await service.updateRun(
      run.copyWith(
        currentStepIndex: 2,
        completedStepIds: {'step-1'},
        notes: [note],
        timerStartTimes: {'step-2': DateTime.utc(2026, 8, 13, 10)},
        pausedSeconds: {'step-1': 45},
      ),
    );

    final paused = await service.pauseRun(run.id);
    final resumed = await service.resumeRun(run.id);

    expect(paused!.id, run.id);
    expect(paused.status, ProtocolRunStatus.paused);
    expect(resumed!.id, run.id);
    expect(resumed.status, ProtocolRunStatus.running);
    expect(resumed.currentStepIndex, 2);
    expect(resumed.completedStepIds, {'step-1'});
    expect(resumed.notes.single.note, 'Keep this');
    expect(resumed.timerStartTimes, contains('step-2'));
    expect(resumed.pausedSeconds, {'step-1': 45});
    expect(await service.loadRuns(), hasLength(1));
  });

  test('completion transitions the same run and supports later runs', () async {
    final service = ProtocolRunService();
    final first = await service.createRunFromProtocol(protocol());
    final completed = await service.completeRun(
      first.id,
      completedByName: 'Aviv',
    );
    final second = await service.createRunFromProtocol(protocol());

    expect(completed!.id, first.id);
    expect(completed.status, ProtocolRunStatus.completed);
    expect(completed.completedAt, isNotNull);
    expect(await service.getCompletedRuns(), hasLength(1));
    expect((await service.getRunningRuns()).single.id, second.id);
    expect(await service.getRunsForProtocol(first.protocolId), hasLength(2));
  });

  test('discard deletes the run without leaving an orphan', () async {
    final service = ProtocolRunService();
    final run = await service.createRunFromProtocol(protocol());
    await service.discardRun(run.id);
    expect(await service.loadRuns(), isEmpty);
    expect(await service.getRun(run.id), isNull);
  });

  test('project queries include assigned and unassigned runs', () async {
    final service = ProtocolRunService();
    await service.createRunFromProtocol(protocol(projectId: 'project-1'));
    await service.createRunFromProtocol(protocol());
    expect(await service.getRunsForProject('project-1'), hasLength(1));
    expect(await service.getRunsForProject(null), hasLength(1));
  });

  test('legacy active, paused, and completed records migrate once', () async {
    final source = protocol(projectId: 'project-1');
    final started = DateTime.utc(2026, 8, 10);
    final active = ActiveProtocol(
      protocol: source,
      notes: const [],
      startedAt: started,
      currentStepIndex: 1,
      pausedSeconds: const {'timer': 20},
    );
    final paused = ActiveProtocol(
      protocol: source.copyWith(id: 'paused-protocol'),
      notes: const [],
      startedAt: started.add(const Duration(days: 1)),
    );
    final completed = CompletedProtocol(
      id: 'legacy-completed-id',
      protocol: source,
      notes: const [],
      startedAt: started,
      completedAt: started.add(const Duration(hours: 2)),
    );
    SharedPreferences.setMockInitialValues({
      'active_protocol_json': jsonEncode(active.toJson()),
      'running_protocols_json': jsonEncode([paused.toJson()]),
      'completed_protocols_json': jsonEncode([completed.toJson()]),
    });
    final service = ProtocolRunService();

    final firstLoad = await service.loadRuns();
    final secondLoad = await service.loadRuns();

    expect(firstLoad, hasLength(3));
    expect(secondLoad.map((run) => run.id), firstLoad.map((run) => run.id));
    expect(
      firstLoad
          .singleWhere((run) => run.status == ProtocolRunStatus.running)
          .pausedSeconds,
      {'timer': 20},
    );
    expect(
      firstLoad.singleWhere((run) => run.id == 'legacy-completed-id').status,
      ProtocolRunStatus.completed,
    );
  });

  test('new unified storage takes precedence over legacy stores', () async {
    final now = DateTime.utc(2026, 8, 13);
    final unified = ProtocolRun(
      id: 'RUN-UNIFIED',
      protocolId: 'unified-protocol',
      protocolSnapshot: protocol().copyWith(id: 'unified-protocol'),
      status: ProtocolRunStatus.paused,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final legacy = ActiveProtocol(
      protocol: protocol(),
      notes: const [],
      startedAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'protocol_runs_json': jsonEncode([unified.toJson()]),
      'active_protocol_json': jsonEncode(legacy.toJson()),
    });

    final runs = await ProtocolRunService().loadRuns();
    expect(runs.map((run) => run.id), ['RUN-UNIFIED']);
  });
}
