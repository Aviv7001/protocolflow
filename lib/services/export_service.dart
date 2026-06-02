import 'dart:convert';
import '../models/protocol.dart';
import '../models/completed_protocol.dart';
import 'storage_service.dart';
import 'json_file_saver.dart';

class ExportService {
  final StorageService _storageService = StorageService();

  Future<void> exportTemplates() async {
    final protocols = await _storageService.loadProtocols();
    final templates = protocols.where((p) => p.isTemplate).toList();
    final jsonString = jsonEncode(templates.map((p) => p.toJson()).toList());
    await _saveFile(jsonString, 'protocol_templates.json');
  }

  Future<void> exportHistory() async {
    final completed = await _storageService.loadCompletedProtocols();
    final jsonString = jsonEncode(completed.map((p) => p.toJson()).toList());
    await _saveFile(jsonString, 'completed_protocols.json');
  }

  Future<void> exportSingleCompletedProtocol(
    CompletedProtocol completed,
  ) async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(completed.toJson());
    final fileName =
        'completed_${completed.protocol.title.replaceAll(' ', '_')}_${completed.id}.json';
    await _saveFile(jsonString, fileName);
  }

  Future<void> exportSingleTemplate(Protocol protocol) async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(protocol.toJson());
    final fileName = 'template_${protocol.title.replaceAll(' ', '_')}.json';
    await _saveFile(jsonString, fileName);
  }

  Future<void> exportAllData() async {
    final protocols = await _storageService.loadProtocols();
    final completed = await _storageService.loadCompletedProtocols();

    final allData = {
      'templates': protocols.map((p) => p.toJson()).toList(),
      'history': completed.map((p) => p.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(allData);
    await _saveFile(jsonString, 'protocolflow_backup.json');
  }

  Future<void> _saveFile(String content, String fileName) async {
    await saveJsonFile(content, fileName);
  }
}
