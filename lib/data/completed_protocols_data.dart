import '../models/completed_protocol.dart';
import '../models/active_protocol.dart';
import '../models/protocol.dart';
import '../models/protocol_run.dart';
import '../services/protocol_run_service.dart';
import '../utils/protocol_run_id.dart';

List<CompletedProtocol> completedProtocols = [];
List<ActiveProtocol> runningProtocols = [];
ActiveProtocol? activeProtocol;
List<ProtocolRun> protocolRuns = [];

final ProtocolRunService _runService = ProtocolRunService.instance;

void _upsertRunningProtocol(ActiveProtocol state) {
  runningProtocols.removeWhere(
    (entry) => entry.protocol.id == state.protocol.id,
  );
  runningProtocols.add(state);
}

ActiveProtocol activateProtocolSession(
  Protocol protocol, {
  int? initialStepIndex,
}) {
  final pendingProtocol = protocol.copyWith(
    syncStatus: ProtocolSyncStatus.modified,
  );
  final protocolId = protocol.id;
  ActiveProtocol? session;

  if (activeProtocol?.protocol.id == protocolId) {
    session = activeProtocol;
  } else {
    if (activeProtocol != null) {
      _upsertRunningProtocol(activeProtocol!);
    }

    final runningIndex = runningProtocols.indexWhere(
      (entry) => entry.protocol.id == protocolId,
    );
    if (runningIndex >= 0) {
      session = runningProtocols.removeAt(runningIndex);
    }
  }

  runningProtocols.removeWhere((entry) => entry.protocol.id == protocolId);
  session = session == null
      ? ActiveProtocol(
          runId: generateProtocolRunId(),
          protocol: pendingProtocol,
          currentStepIndex: initialStepIndex ?? -1,
          notes: const [],
          startedAt: DateTime.now(),
        )
      : session.copyWith(
          protocol: pendingProtocol,
          currentStepIndex: initialStepIndex ?? session.currentStepIndex,
        );
  activeProtocol = session;
  return session;
}

bool pauseProtocolSession(String protocolId) {
  final session = activeProtocol;
  if (session == null || session.protocol.id != protocolId) return false;
  _upsertRunningProtocol(session);
  activeProtocol = null;
  return true;
}

void discardProtocolSession(String protocolId) {
  if (activeProtocol?.protocol.id == protocolId) {
    activeProtocol = null;
  }
  runningProtocols.removeWhere((entry) => entry.protocol.id == protocolId);
}

Future<void> loadPersistentProtocols() async {
  protocolRuns = await _runService.loadRuns();
  _hydrateCompatibilityViews();
}

Future<void> savePersistentProtocols() async {
  await _runService.saveFromCompatibilityViews(
    active: activeProtocol,
    running: runningProtocols,
    completed: completedProtocols,
  );
  protocolRuns = await _runService.loadRuns();
  _hydrateCompatibilityViews();
}

void _hydrateCompatibilityViews() {
  final activeRuns = protocolRuns
      .where((run) => run.status == ProtocolRunStatus.running)
      .toList();
  activeProtocol = activeRuns.isEmpty
      ? null
      : activeRuns.first.toActiveProtocol();
  runningProtocols = protocolRuns
      .where((run) => run.status == ProtocolRunStatus.paused)
      .map((run) => run.toActiveProtocol())
      .toList();
  completedProtocols = protocolRuns
      .where((run) => run.status == ProtocolRunStatus.completed)
      .map((run) => run.toCompletedProtocol())
      .toList();
}
