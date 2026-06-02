import '../models/completed_protocol.dart';
import '../models/active_protocol.dart';
import '../services/storage_service.dart';

List<CompletedProtocol> completedProtocols = [];
List<ActiveProtocol> runningProtocols = [];
ActiveProtocol? activeProtocol;

final StorageService _storageService = StorageService();

Future<void> loadPersistentProtocols() async {
  completedProtocols = await _storageService.loadCompletedProtocols();
  activeProtocol = await _storageService.loadActiveProtocol();
  runningProtocols = await _storageService.loadRunningProtocols();
}

Future<void> savePersistentProtocols() async {
  await _storageService.saveCompletedProtocols(completedProtocols);
  await _storageService.saveActiveProtocol(activeProtocol);
  await _storageService.saveRunningProtocols(runningProtocols);
}
