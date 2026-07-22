import 'dart:convert';
import '../models/protocol.dart';
import '../models/completed_protocol.dart';
import 'storage_service.dart';
import 'json_file_saver.dart';
import 'protocol_export_filename.dart';
import 'dashboard_activity_service.dart';

class ExportService {
  final StorageService _storageService = StorageService();
  final DashboardActivityService _activityService = DashboardActivityService();

  Future<void> exportTemplates() async {
    final protocols = await _storageService.loadProtocols();
    final templates = protocols.where((p) => p.isTemplate).toList();
    final jsonString = jsonEncode(templates.map((p) => p.toJson()).toList());
    await _saveFile(jsonString, 'protocol_templates.json');
    await _activityService.recordExport(
      'Protocol templates',
      'ProtocolFlow file',
    );
  }

  Future<void> exportHistory() async {
    final completed = await _storageService.loadCompletedProtocols();
    final jsonString = jsonEncode(completed.map((p) => p.toJson()).toList());
    await _saveFile(jsonString, 'completed_protocols.json');
    await _activityService.recordExport(
      'Completed protocols',
      'ProtocolFlow file',
    );
  }

  Future<void> exportSingleCompletedProtocol(
    CompletedProtocol completed,
  ) async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(completed.toJson());
    await _saveFile(
      jsonString,
      ProtocolExportFilename.completed(
        completed.protocol,
        completed.completedAt,
        'json',
      ),
    );
    await _activityService.recordExport(
      completed.protocol.title,
      'ProtocolFlow file',
    );
  }

  Future<void> exportSingleTemplate(Protocol protocol) async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(protocol.toJson());
    await _saveFile(
      jsonString,
      ProtocolExportFilename.protocol(protocol, 'json'),
    );
    await _activityService.recordExport(protocol.title, 'ProtocolFlow file');
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
    await _activityService.recordExport(
      'ProtocolFlow backup',
      'ProtocolFlow file',
    );
  }

  Future<void> _saveFile(String content, String fileName) async {
    await saveJsonFile(content, fileName);
  }
}
