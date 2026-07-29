import '../models/completed_protocol.dart';
import '../models/active_protocol.dart';
import '../models/protocol.dart';
import '../services/storage_service.dart';

List<CompletedProtocol> completedProtocols = [];
List<ActiveProtocol> runningProtocols = [];
ActiveProtocol? activeProtocol;

final StorageService _storageService = StorageService();

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
          protocol: protocol,
          currentStepIndex: initialStepIndex ?? -1,
          notes: const [],
          startedAt: DateTime.now(),
        )
      : session.copyWith(
          protocol: protocol,
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
  completedProtocols = await _storageService.loadCompletedProtocols();
  activeProtocol = await _storageService.loadActiveProtocol();
  runningProtocols = await _storageService.loadRunningProtocols();
}

Future<void> savePersistentProtocols() async {
  await _storageService.saveCompletedProtocols(
    completedProtocols,
    markPending: false,
  );
  await _storageService.saveActiveProtocol(activeProtocol);
  await _storageService.saveRunningProtocols(runningProtocols);
}
