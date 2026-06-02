import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/protocol.dart';
import '../models/completed_protocol.dart';
import '../data/completed_protocols_data.dart';
import 'storage_service.dart';

class ImportService {
  final StorageService _storageService = StorageService();

  Future<ImportResult> importJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null) {
        return ImportResult(success: false, message: 'No file selected');
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        return ImportResult(
          success: false,
          message: 'Could not read selected file',
        );
      }

      final String content = utf8.decode(bytes);
      final dynamic jsonData = jsonDecode(content);

      if (jsonData is Map<String, dynamic>) {
        // Check if it's a full backup
        if (jsonData.containsKey('templates') ||
            jsonData.containsKey('history')) {
          return await _importBackup(jsonData);
        }
        // Check if it's a single completed protocol
        if (jsonData.containsKey('completedAt') &&
            jsonData.containsKey('protocol')) {
          return await _importSingleHistory(jsonData);
        }
        // Check if it's a single template
        if (jsonData.containsKey('id') && jsonData.containsKey('steps')) {
          return await _importSingleTemplate(jsonData);
        }
      } else if (jsonData is List) {
        // Could be a list of templates or history
        if (jsonData.isEmpty) {
          return ImportResult(success: false, message: 'Empty JSON list');
        }

        final first = jsonData.first;
        if (first.containsKey('completedAt')) {
          return await _importHistoryList(jsonData);
        } else {
          return await _importTemplateList(jsonData);
        }
      }

      return ImportResult(success: false, message: 'Unrecognized JSON format');
    } catch (e) {
      if (kDebugMode) print('Import error: $e');
      return ImportResult(success: false, message: 'Error: $e');
    }
  }

  Future<ImportResult> _importBackup(Map<String, dynamic> data) async {
    int templateCount = 0;
    int historyCount = 0;

    if (data.containsKey('templates')) {
      final List<dynamic> templatesJson = data['templates'];
      final List<Protocol> imported = templatesJson
          .map((j) => Protocol.fromJson(j))
          .toList();
      final existing = await _storageService.loadProtocols();

      for (var p in imported) {
        if (!existing.any((e) => e.id == p.id)) {
          existing.add(p);
          templateCount++;
        }
      }
      await _storageService.saveProtocols(existing);
    }

    if (data.containsKey('history')) {
      final List<dynamic> historyJson = data['history'];
      final List<CompletedProtocol> imported = historyJson
          .map((j) => CompletedProtocol.fromJson(j))
          .toList();

      for (var p in imported) {
        if (!completedProtocols.any((e) => e.id == p.id)) {
          completedProtocols.add(p);
          historyCount++;
        }
      }
      await savePersistentProtocols();
    }

    return ImportResult(
      success: true,
      message:
          'Backup imported: $templateCount templates, $historyCount history records added.',
    );
  }

  Future<ImportResult> _importSingleTemplate(Map<String, dynamic> json) async {
    final protocol = Protocol.fromJson(json);
    final existing = await _storageService.loadProtocols();

    if (existing.any((e) => e.id == protocol.id)) {
      return ImportResult(
        success: false,
        message: 'Protocol with this ID already exists in library.',
      );
    }

    existing.add(protocol);
    await _storageService.saveProtocols(existing);
    return ImportResult(
      success: true,
      message: 'Template "${protocol.title}" imported successfully.',
    );
  }

  Future<ImportResult> _importSingleHistory(Map<String, dynamic> json) async {
    final completed = CompletedProtocol.fromJson(json);

    if (completedProtocols.any((e) => e.id == completed.id)) {
      return ImportResult(
        success: false,
        message: 'This history record already exists.',
      );
    }

    completedProtocols.add(completed);
    await savePersistentProtocols();
    return ImportResult(
      success: true,
      message: 'History record for "${completed.protocol.title}" imported.',
    );
  }

  Future<ImportResult> _importTemplateList(List<dynamic> list) async {
    final List<Protocol> imported = list
        .map((j) => Protocol.fromJson(j))
        .toList();
    final existing = await _storageService.loadProtocols();
    int count = 0;

    for (var p in imported) {
      if (!existing.any((e) => e.id == p.id)) {
        existing.add(p);
        count++;
      }
    }
    await _storageService.saveProtocols(existing);
    return ImportResult(
      success: true,
      message: 'Imported $count new templates.',
    );
  }

  Future<ImportResult> _importHistoryList(List<dynamic> list) async {
    final List<CompletedProtocol> imported = list
        .map((j) => CompletedProtocol.fromJson(j))
        .toList();
    int count = 0;

    for (var p in imported) {
      if (!completedProtocols.any((e) => e.id == p.id)) {
        completedProtocols.add(p);
        count++;
      }
    }
    await savePersistentProtocols();
    return ImportResult(
      success: true,
      message: 'Imported $count new history records.',
    );
  }
}

class ImportResult {
  final bool success;
  final String message;
  ImportResult({required this.success, required this.message});
}
