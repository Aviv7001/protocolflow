import '../models/active_protocol.dart';
import '../models/completed_protocol.dart';
import '../models/protocol.dart';
import '../models/protocol_run.dart';
import '../utils/protocol_run_id.dart';
import 'storage_service.dart';

class ProtocolRunService {
  ProtocolRunService({StorageService? storageService})
    : _storage = storageService ?? StorageService();

  static final ProtocolRunService instance = ProtocolRunService();

  final StorageService _storage;

  Future<List<ProtocolRun>> loadRuns() async {
    if (await _storage.hasProtocolRunsStorage()) {
      return _sorted(await _storage.loadProtocolRuns());
    }
    final migrated = await _migrateLegacyStores();
    await saveRuns(migrated);
    return _sorted(migrated);
  }

  Future<void> saveRuns(
    List<ProtocolRun> runs, {
    bool writeLegacyMirrors = true,
  }) async {
    final deduplicated = <String, ProtocolRun>{};
    for (final run in runs) {
      deduplicated[run.id] = run;
    }
    final values = _sorted(deduplicated.values.toList());
    await _storage.saveProtocolRuns(values);
    if (writeLegacyMirrors) await _writeLegacyMirrors(values);
  }

  Future<List<ProtocolRun>> getRunningRuns() async => (await loadRuns())
      .where(
        (run) =>
            run.status == ProtocolRunStatus.running ||
            run.status == ProtocolRunStatus.paused,
      )
      .toList();

  Future<List<ProtocolRun>> getCompletedRuns() async => (await loadRuns())
      .where((run) => run.status == ProtocolRunStatus.completed)
      .toList();

  Future<List<ProtocolRun>> getRunsForProtocol(String protocolId) async =>
      (await loadRuns()).where((run) => run.protocolId == protocolId).toList();

  Future<List<ProtocolRun>> getRunsForProject(String? projectId) async =>
      (await loadRuns()).where((run) => run.projectId == projectId).toList();

  Future<ProtocolRun?> getRun(String runId) async {
    for (final run in await loadRuns()) {
      if (run.id == runId) return run;
    }
    return null;
  }

  Future<ProtocolRun> createRunFromProtocol(Protocol protocol) async {
    final runs = await loadRuns();
    final now = DateTime.now();
    for (var index = 0; index < runs.length; index++) {
      if (runs[index].status == ProtocolRunStatus.running) {
        runs[index] = runs[index].copyWith(
          status: ProtocolRunStatus.paused,
          pausedAt: now,
          updatedAt: now,
        );
      }
    }
    var id = generateProtocolRunId(date: now);
    while (runs.any((run) => run.id == id)) {
      id = generateProtocolRunId(date: now);
    }
    final run = ProtocolRun(
      id: id,
      protocolId: protocol.id,
      projectId: protocol.projectId,
      protocolSnapshot: protocol.deepCopy(),
      status: ProtocolRunStatus.running,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    runs.add(run);
    await saveRuns(runs);
    return run;
  }

  Future<ProtocolRun> updateRun(ProtocolRun run) async {
    final runs = await loadRuns();
    final updated = run.copyWith(updatedAt: DateTime.now());
    final index = runs.indexWhere((item) => item.id == run.id);
    if (index < 0) {
      runs.add(updated);
    } else {
      runs[index] = updated;
    }
    await saveRuns(runs);
    return updated;
  }

  Future<ProtocolRun?> pauseRun(String runId) => _transition(
    runId,
    (run, now) => run.copyWith(
      status: ProtocolRunStatus.paused,
      pausedAt: now,
      updatedAt: now,
    ),
  );

  Future<ProtocolRun?> resumeRun(String runId) async {
    final runs = await loadRuns();
    final now = DateTime.now();
    ProtocolRun? resumed;
    for (var index = 0; index < runs.length; index++) {
      final run = runs[index];
      if (run.id == runId) {
        resumed = run.copyWith(
          status: ProtocolRunStatus.running,
          clearPausedAt: true,
          updatedAt: now,
        );
        runs[index] = resumed;
      } else if (run.status == ProtocolRunStatus.running) {
        runs[index] = run.copyWith(
          status: ProtocolRunStatus.paused,
          pausedAt: now,
          updatedAt: now,
        );
      }
    }
    if (resumed != null) await saveRuns(runs);
    return resumed;
  }

  Future<ProtocolRun?> completeRun(String runId, {String? completedByName}) =>
      _transition(
        runId,
        (run, now) => run.copyWith(
          status: ProtocolRunStatus.completed,
          completedAt: now,
          completedByName: completedByName,
          clearPausedAt: true,
          updatedAt: now,
        ),
      );

  Future<bool> discardRun(String runId) async {
    final runs = await loadRuns();
    final initialLength = runs.length;
    runs.removeWhere((run) => run.id == runId);
    if (runs.length == initialLength) return false;
    await saveRuns(runs);
    return true;
  }

  Future<void> replaceFromLegacySync({
    ActiveProtocol? active,
    required List<ActiveProtocol> running,
    required List<CompletedProtocol> completed,
  }) async {
    final migrated = _convertLegacy(active, running, completed);
    await saveRuns(migrated);
  }

  Future<void> saveFromCompatibilityViews({
    ActiveProtocol? active,
    required List<ActiveProtocol> running,
    required List<CompletedProtocol> completed,
  }) async {
    final existing = {for (final run in await loadRuns()) run.id: run};
    final converted = _convertLegacy(active, running, completed);
    final enriched = converted.map((run) {
      final old = existing[run.id];
      if (old == null) return run;
      return run.copyWith(
        createdAt: old.createdAt,
        driveFileId: old.driveFileId,
        lastSyncedAt: old.lastSyncedAt,
      );
    }).toList();
    await saveRuns(enriched);
  }

  Future<ProtocolRun?> _transition(
    String runId,
    ProtocolRun Function(ProtocolRun run, DateTime now) change,
  ) async {
    final runs = await loadRuns();
    final index = runs.indexWhere((run) => run.id == runId);
    if (index < 0) return null;
    final updated = change(runs[index], DateTime.now());
    runs[index] = updated;
    await saveRuns(runs);
    return updated;
  }

  Future<List<ProtocolRun>> _migrateLegacyStores() async {
    return _convertLegacy(
      await _storage.loadActiveProtocol(),
      await _storage.loadRunningProtocols(),
      await _storage.loadCompletedProtocols(),
    );
  }

  List<ProtocolRun> _convertLegacy(
    ActiveProtocol? active,
    List<ActiveProtocol> running,
    List<CompletedProtocol> completed,
  ) {
    final values = <String, ProtocolRun>{};
    if (active != null) {
      final run = _fromActive(active, ProtocolRunStatus.running, 'in-progress');
      values[run.id] = run;
    }
    for (final session in running) {
      final run = _fromActive(session, ProtocolRunStatus.paused, 'in-progress');
      values.putIfAbsent(run.id, () => run);
    }
    for (final item in completed) {
      final id = item.id.trim().isNotEmpty
          ? item.id
          : deterministicLegacyRunId(
              protocolId: item.protocol.id,
              startedAt: item.startedAt ?? item.completedAt,
              source: 'completed',
            );
      values[id] = ProtocolRun(
        id: id,
        protocolId: item.protocol.id,
        projectId: item.protocol.projectId,
        protocolSnapshot: item.protocol.deepCopy(),
        status: ProtocolRunStatus.completed,
        currentStepIndex: item.protocol.sortedSteps.length - 1,
        completedStepIds: item.protocol.sortedSteps
            .map((step) => step.id)
            .toSet(),
        notes: item.notes,
        startedAt: item.startedAt ?? item.completedAt,
        completedAt: item.completedAt,
        createdAt: item.startedAt ?? item.completedAt,
        updatedAt: item.completedAt,
        completedByName: item.completedByName,
        driveFileId: item.driveFileId,
        lastSyncedAt: item.lastSyncedAt,
        syncStatus: item.syncStatus,
      );
    }
    return values.values.toList();
  }

  ProtocolRun _fromActive(
    ActiveProtocol session,
    ProtocolRunStatus status,
    String source,
  ) {
    final id = session.runId?.trim().isNotEmpty == true
        ? session.runId!
        : deterministicLegacyRunId(
            protocolId: session.protocol.id,
            startedAt: session.startedAt,
            source: source,
          );
    return ProtocolRun(
      id: id,
      protocolId: session.protocol.id,
      projectId: session.protocol.projectId,
      protocolSnapshot: session.protocol.deepCopy(),
      status: status,
      currentStepIndex: session.currentStepIndex,
      completedStepIds: session.completedStepIds,
      notes: session.notes,
      timerStartTimes: session.timerStartTimes,
      pausedSeconds: session.pausedSeconds,
      startedAt: session.startedAt,
      pausedAt: status == ProtocolRunStatus.paused ? DateTime.now() : null,
      createdAt: session.startedAt,
      updatedAt: DateTime.now(),
      syncStatus: session.protocol.syncStatus,
      lastSyncedAt: session.protocol.lastSyncedAt,
    );
  }

  Future<void> _writeLegacyMirrors(List<ProtocolRun> runs) async {
    final activeRuns = runs
        .where((run) => run.status == ProtocolRunStatus.running)
        .toList();
    final paused = runs
        .where((run) => run.status == ProtocolRunStatus.paused)
        .map((run) => run.toActiveProtocol())
        .toList();
    final completed = runs
        .where((run) => run.status == ProtocolRunStatus.completed)
        .map((run) => run.toCompletedProtocol())
        .toList();
    await _storage.saveActiveProtocol(
      activeRuns.isEmpty ? null : activeRuns.first.toActiveProtocol(),
    );
    await _storage.saveRunningProtocols(paused);
    await _storage.saveCompletedProtocols(completed);
  }

  List<ProtocolRun> _sorted(List<ProtocolRun> runs) {
    return List<ProtocolRun>.from(runs)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
