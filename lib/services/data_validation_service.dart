import 'dart:convert';

import '../features/measuring_tools/models/measuring_tool.dart';
import '../models/active_protocol.dart';
import '../models/completed_protocol.dart';
import '../models/deleted_protocol_record.dart';
import '../models/material.dart';
import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_additional_data.dart';
import '../models/protocol_run.dart';
import '../models/protocol_table.dart';
import '../models/protocol_step.dart';
import '../models/step_note.dart';
import '../models/task.dart';
import 'storage_service.dart';

class DataValidationService {
  DataValidationService._();

  static const int maxShortText = 200;
  static const int maxMediumText = 1000;
  static const int maxLongText = 20000;
  static const int maxListItems = 500;
  static const int maxTableRows = 10000;
  static const int maxTableColumns = 500;
  static const int maxTableCells = 200000;
  static const int maxMetadataEntries = 200;
  static const int maxPreferenceStringBytes = 5 * 1024 * 1024;

  static const Set<String> allowedLocalBackupPreferenceKeys = {
    'protocols_library_json',
    'projects_json',
    'projects_sync_updated_at',
    'completed_protocols_json',
    'active_protocol_json',
    'running_protocols_json',
    'protocol_runs_json',
    'deleted_protocols_json',
    'saved_tables_json',
    'deleted_saved_tables_json',
    'saved_tables_sync_state',
    'projects_sync_state',
    'completed_protocols_sync_state',
    'tasks_sync_state',
    'measuring_tools_sync_state',
    'today_tasks_json',
    'history_tasks_json',
    'tasks_sync_updated_at',
    'measuring_tools_json',
    'measuring_tools_sync_updated_at',
    'measuring_tools_mass_defaults_migrated',
    'drive_sync_device_id_v2',
    'drive_sync_local_journal_v2',
    'drive_sync_baseline_v2',
    'drive_sync_journal_file_id_v2',
    'home_explore_locally_v1',
    'dashboard_export_history_json',
  };

  static void validateProtocols(Iterable<Protocol> protocols) {
    _validateListSize(protocols.length, 'protocols');
    for (final protocol in protocols) {
      validateProtocol(protocol);
    }
  }

  static void validateProtocol(Protocol protocol) {
    _requiredString(protocol.id, 'Protocol ID', maxShortText);
    _requiredString(protocol.title, 'Protocol title', maxShortText);
    _optionalString(protocol.objective, 'Protocol objective', maxMediumText);
    _optionalString(protocol.description, 'Protocol description', maxLongText);
    _optionalString(protocol.ownerId, 'Protocol owner ID', maxShortText);
    _optionalString(protocol.projectId, 'Protocol project ID', maxShortText);
    _optionalString(protocol.createdByName, 'Protocol creator', maxShortText);
    _validateDate(protocol.createdAt, 'Protocol created date');
    _validateDate(protocol.updatedAt, 'Protocol updated date');
    _validateListSize(protocol.materials.length, 'protocol materials');
    _validateListSize(protocol.samples.length, 'protocol samples');
    _validateListSize(protocol.files.length, 'protocol files');
    _validateListSize(protocol.imageNames.length, 'protocol image names');
    _validateListSize(protocol.steps.length, 'protocol steps');
    _validateListSize(protocol.tables.length, 'protocol tables');
    _validateListSize(protocol.additionalData.length, 'additional data');
    for (final material in protocol.materials) {
      validateMaterial(material);
    }
    for (final sample in protocol.samples) {
      _optionalString(sample, 'Sample name', maxShortText);
    }
    for (final file in protocol.files) {
      _validateMediaSource(file, 'Attached file path');
    }
    for (final name in protocol.imageNames) {
      _optionalString(name, 'Protocol image name', maxShortText);
    }
    for (final step in protocol.steps) {
      validateProtocolStep(step);
    }
    for (final table in protocol.tables) {
      validateProtocolTable(table, requireTitle: false);
    }
    for (final data in protocol.additionalData) {
      validateAdditionalData(data);
    }
  }

  static void validateMaterial(MaterialItem material) {
    _requiredString(material.id, 'Material ID', maxShortText);
    _optionalString(material.name, 'Material name', maxShortText);
    _optionalString(material.quantity, 'Material quantity', maxShortText);
    _optionalString(material.catalogNumber, 'Catalog number', maxShortText);
    _optionalString(material.manufacturer, 'Manufacturer', maxShortText);
    _optionalString(material.location, 'Material location', maxShortText);
    _optionalString(
      material.stockConcentration,
      'Stock concentration',
      maxShortText,
    );
  }

  static void validateProtocolStep(ProtocolStep step) {
    _requiredString(step.id, 'Step ID', maxShortText);
    _optionalString(step.title, 'Step title', maxShortText);
    _optionalString(step.instructions, 'Step instructions', maxLongText);
    _intRange(step.day, 'Step day', min: 1, max: 3650);
    _optionalString(step.phaseName, 'Phase name', maxShortText);
    _validateListSize(step.actionItems.length, 'step actions');
    _validateListSize(step.notes.length, 'step notes');
    _validateListSize(step.attachedFiles.length, 'step attachments');
    _validateListSize(step.tableIds.length, 'step table links');
    for (final action in step.actionItems) {
      _optionalString(action, 'Step action', maxMediumText);
    }
    for (final note in step.notes) {
      _optionalString(note, 'Step note', maxMediumText);
    }
    for (final attachment in step.attachedFiles) {
      _validateMediaSource(attachment, 'Step attachment');
    }
    for (final timer in step.actionTimers.entries) {
      _intRange(timer.key, 'Action timer index', min: 0, max: maxListItems);
      _intRange(timer.value, 'Action timer seconds', min: 1, max: 86400);
    }
  }

  static void validateAdditionalData(ProtocolAdditionalData data) {
    _requiredString(data.id, 'Additional data ID', maxShortText);
    _requiredString(data.title, 'Additional data title', maxShortText);
    _optionalString(
      data.description,
      'Additional data description',
      maxLongText,
    );
    _optionalString(data.link, 'Additional data link', maxMediumText);
    if (data.link.trim().isNotEmpty) {
      final uri = Uri.tryParse(data.link.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw const FormatException(
          'Additional data link must be a valid URL.',
        );
      }
    }
    _validateListSize(data.photoPaths.length, 'additional data photos');
    for (final path in data.photoPaths) {
      _validateMediaSource(path, 'Additional data photo path');
    }
  }

  static void _validateMediaSource(String value, String label) {
    _optionalString(
      value,
      label,
      value.startsWith('data:image/')
          ? maxPreferenceStringBytes
          : maxMediumText,
    );
  }

  static void validateProjects(Iterable<Project> projects) {
    _validateListSize(projects.length, 'projects');
    for (final project in projects) {
      validateProject(project);
    }
  }

  static void validateProject(Project project) {
    _requiredString(project.id, 'Project ID', maxShortText);
    _requiredString(project.name, 'Project name', maxShortText);
    _optionalString(project.description, 'Project description', maxMediumText);
    _validateDate(project.createdAt, 'Project created date');
    _validateDate(project.updatedAt, 'Project updated date');
  }

  static void validateTasks(Iterable<Task> tasks) {
    _validateListSize(tasks.length, 'tasks');
    for (final task in tasks) {
      validateTask(task);
    }
  }

  static void validateTask(Task task) {
    _requiredString(task.id, 'Task ID', maxShortText);
    _requiredString(task.title, 'Task title', maxShortText);
    _optionalString(task.description, 'Task description', maxMediumText);
    _validateDate(task.createdAt, 'Task created date');
    if (task.completedAt != null) {
      _validateDate(task.completedAt!, 'Task completed date');
    }
    _optionalString(task.projectId, 'Task project ID', maxShortText);
    _optionalString(task.protocolId, 'Task protocol ID', maxShortText);
    _optionalString(task.runId, 'Task run ID', maxShortText);
  }

  static void validateCompletedProtocols(
    Iterable<CompletedProtocol> protocols,
  ) {
    _validateListSize(protocols.length, 'completed protocols');
    for (final protocol in protocols) {
      validateCompletedProtocol(protocol);
    }
  }

  static void validateCompletedProtocol(CompletedProtocol completed) {
    _requiredString(completed.id, 'Completed protocol ID', maxShortText);
    validateProtocol(completed.protocol);
    if (completed.startedAt != null) {
      _validateDate(completed.startedAt!, 'Completed protocol start date');
    }
    _validateDate(completed.completedAt, 'Completed protocol completion date');
    _validateStepNotes(completed.notes);
  }

  static void validateActiveProtocols(Iterable<ActiveProtocol> protocols) {
    _validateListSize(protocols.length, 'running protocols');
    for (final protocol in protocols) {
      validateActiveProtocol(protocol);
    }
  }

  static void validateActiveProtocol(ActiveProtocol active) {
    validateProtocol(active.protocol);
    _validateDate(active.startedAt, 'Active protocol start date');
    _optionalString(active.runId, 'Run ID', maxShortText);
    _validateStepNotes(active.notes);
  }

  static void validateProtocolRuns(Iterable<ProtocolRun> runs) {
    _validateListSize(runs.length, 'protocol runs');
    for (final run in runs) {
      _requiredString(run.id, 'Protocol run ID', maxShortText);
      _requiredString(run.protocolId, 'Protocol run protocol ID', maxShortText);
      validateProtocol(run.protocolSnapshot);
      _validateDate(run.startedAt, 'Protocol run start date');
      if (run.completedAt != null) {
        _validateDate(run.completedAt!, 'Protocol run completion date');
      }
      _validateStepNotes(run.notes);
    }
  }

  static void _validateStepNotes(Iterable<StepNote> notes) {
    _validateListSize(notes.length, 'run notes');
    for (final note in notes) {
      _requiredString(note.id, 'Run note ID', maxShortText);
      _requiredString(note.stepId, 'Run note step ID', maxShortText);
      _optionalString(note.note, 'Run note', maxLongText);
      _validateDate(note.createdAt, 'Run note creation date');
      _validateListSize(note.photoPaths.length, 'run note photos');
      _validateListSize(note.photoNames.length, 'run note photo names');
      for (final path in note.photoPaths) {
        _validateMediaSource(path, 'Run note photo path');
      }
      for (final name in note.photoNames) {
        _optionalString(name, 'Run note photo name', maxShortText);
      }
    }
  }

  static void validateProtocolTable(
    ProtocolTable table, {
    bool requireTitle = true,
  }) {
    _requiredString(table.id, 'Table ID', maxShortText);
    if (requireTitle) {
      _requiredString(table.title, 'Table title', maxShortText);
    } else {
      _optionalString(table.title, 'Table title', maxShortText);
    }
    _validateListSize(table.columnHeaders.length, 'table columns');
    _validateListSize(table.rowHeaders.length, 'table row headers');
    if (table.columnHeaders.length > maxTableColumns) {
      throw const FormatException('Table has too many columns.');
    }
    if (table.data.length > maxTableRows) {
      throw const FormatException('Table has too many rows.');
    }
    final columnCount = table.columnHeaders.length;
    var cellCount = 0;
    for (final header in table.columnHeaders) {
      _optionalString(header, 'Table column header', maxShortText);
    }
    for (final header in table.rowHeaders) {
      _optionalString(header, 'Table row header', maxShortText);
    }
    for (final row in table.data) {
      if (columnCount > 0 && row.length > columnCount) {
        throw const FormatException('Table row has too many cells.');
      }
      cellCount += row.length;
      if (cellCount > maxTableCells) {
        throw const FormatException('Table has too many cells.');
      }
      for (final cell in row) {
        _validateCell(cell);
      }
    }
    if (table.cellColors.length > table.data.length) {
      throw const FormatException('Table has invalid color rows.');
    }
    for (final colorRow in table.cellColors) {
      if (columnCount > 0 && colorRow.length > columnCount) {
        throw const FormatException('Table has invalid color cells.');
      }
      for (final color in colorRow) {
        _optionalString(color, 'Table cell color', 32);
      }
    }
    _validateMetadata(table.metadata);
    _optionalString(table.projectId, 'Table project ID', maxShortText);
  }

  static void validateProtocolTables(Iterable<ProtocolTable> tables) {
    _validateListSize(tables.length, 'saved tables');
    for (final table in tables) {
      validateProtocolTable(table);
    }
  }

  static void validateMeasuringTools(Iterable<MeasuringTool> tools) {
    _validateListSize(tools.length, 'measuring tools');
    for (final tool in tools) {
      validateMeasuringTool(tool);
    }
  }

  static void validateMeasuringTool(MeasuringTool tool) {
    _requiredString(tool.id, 'Measuring tool ID', maxShortText);
    _requiredString(tool.category, 'Measuring tool category', maxShortText);
    _requiredString(tool.toolType, 'Measuring tool type', maxShortText);
    _requiredString(tool.toolName, 'Measuring tool name', maxShortText);
    _requiredString(tool.unit, 'Measuring tool unit', 32);
    _intRange(tool.accuracyRank, 'Accuracy rank', min: 1, max: 10);
    if (tool.isMassTool) {
      _requiredFinite(tool.minMassMg, 'Minimum mass');
      _requiredFinite(tool.maxMassMg, 'Maximum mass');
      _requiredFinite(tool.incrementMassMg, 'Mass increment');
      _range(tool.minMassMg!, 'Minimum mass', min: 0);
      _range(tool.maxMassMg!, 'Maximum mass', min: tool.minMassMg!);
      _range(tool.incrementMassMg!, 'Mass increment', min: 0.000001);
      if (tool.preferredMinMassMg != null) {
        _range(
          tool.preferredMinMassMg!,
          'Preferred minimum mass',
          min: tool.minMassMg!,
          max: tool.maxMassMg!,
        );
      }
      return;
    }
    _range(tool.minVolumeUl, 'Minimum volume', min: 0);
    _range(tool.maxVolumeUl, 'Maximum volume', min: tool.minVolumeUl);
    _range(tool.incrementUl, 'Volume increment', min: 0.000001);
  }

  static void validateDeletedProtocolRecords(
    Iterable<DeletedProtocolRecord> records,
  ) {
    _validateListSize(records.length, 'deleted protocol records');
    for (final record in records) {
      validateProtocol(record.protocol);
      _validateDate(record.deletedAt, 'Protocol deletion date');
      _optionalString(record.driveFileId, 'Drive file ID', maxShortText);
    }
  }

  static void validateDeletedSavedTableIds(Iterable<String> tableIds) {
    _validateListSize(tableIds.length, 'deleted saved table IDs');
    for (final id in tableIds) {
      _requiredString(id, 'Deleted saved table ID', maxShortText);
    }
  }

  static void validateSyncBundleState(SyncBundleState state) {}

  static void validateSavedTablesSyncState(SavedTablesSyncState state) {}

  static void validateLocalBackupPreference(String key, Object value) {
    if (!allowedLocalBackupPreferenceKeys.contains(key)) {
      throw FormatException(
        'Local backup contains unsupported setting "$key".',
      );
    }
    switch (key) {
      case 'protocols_library_json':
        validateProtocols(_decodeList(value, Protocol.fromJson, key));
      case 'projects_json':
        validateProjects(_decodeList(value, Project.fromJson, key));
      case 'completed_protocols_json':
        validateCompletedProtocols(
          _decodeList(value, CompletedProtocol.fromJson, key),
        );
      case 'active_protocol_json':
        validateActiveProtocol(
          ActiveProtocol.fromJson(_decodeMapString(value, key)),
        );
      case 'running_protocols_json':
        validateActiveProtocols(
          _decodeList(value, ActiveProtocol.fromJson, key),
        );
      case 'protocol_runs_json':
        validateProtocolRuns(_decodeList(value, ProtocolRun.fromJson, key));
      case 'deleted_protocols_json':
        validateDeletedProtocolRecords(
          _decodeList(value, DeletedProtocolRecord.fromJson, key),
        );
      case 'saved_tables_json':
        validateProtocolTables(_decodeList(value, ProtocolTable.fromJson, key));
      case 'deleted_saved_tables_json':
        validateDeletedSavedTableIds(_decodeStringList(value, key));
      case 'today_tasks_json':
      case 'history_tasks_json':
        validateTasks(_decodeList(value, Task.fromJson, key));
      case 'measuring_tools_json':
        validateMeasuringTools(_decodeList(value, MeasuringTool.fromJson, key));
      case 'projects_sync_updated_at':
      case 'tasks_sync_updated_at':
      case 'measuring_tools_sync_updated_at':
        _parseDateString(value, key);
      case 'saved_tables_sync_state':
        _enumName(value, SavedTablesSyncState.values.map((e) => e.name), key);
      case 'projects_sync_state':
      case 'completed_protocols_sync_state':
      case 'tasks_sync_state':
      case 'measuring_tools_sync_state':
        _enumName(value, SyncBundleState.values.map((e) => e.name), key);
      default:
        _validatePrimitivePreference(value, key);
    }
  }

  static void validateDriveAppDataFile({
    required String name,
    required String content,
  }) {
    _requiredString(name, 'Drive backup file name', maxShortText);
    if (name.contains('/') || name.contains(r'\')) {
      throw const FormatException('Drive backup file name is invalid.');
    }
    if (utf8.encode(content).length > maxPreferenceStringBytes) {
      throw FormatException('Drive backup file "$name" is too large.');
    }
    if (name == 'projects.json') {
      final decoded = _decodeJson(content, name);
      if (decoded is Map<String, dynamic>) {
        validateProjects(_mapList(decoded['projects'], Project.fromJson, name));
      } else {
        validateProjects(_mapList(decoded, Project.fromJson, name));
      }
      return;
    }
    if (name == 'saved_tables.json') {
      validateProtocolTables(
        _mapList(_decodeJson(content, name), ProtocolTable.fromJson, name),
      );
      return;
    }
    if (name == 'today_tasks.json') {
      final decoded = _decodeJson(content, name);
      if (decoded is Map<String, dynamic>) {
        validateTasks(_mapList(decoded['today'], Task.fromJson, name));
        validateTasks(_mapList(decoded['history'], Task.fromJson, name));
      } else {
        validateTasks(_mapList(decoded, Task.fromJson, name));
      }
      return;
    }
    if (name == 'measuring_tools.json') {
      final decoded = _decodeJson(content, name);
      if (decoded is Map<String, dynamic>) {
        validateMeasuringTools(
          _mapList(decoded['tools'], MeasuringTool.fromJson, name),
        );
      } else {
        validateMeasuringTools(_mapList(decoded, MeasuringTool.fromJson, name));
      }
      return;
    }
    if (name.startsWith('completed_protocol_') && name.endsWith('.json')) {
      validateCompletedProtocol(
        CompletedProtocol.fromJson(_decodeMapString(content, name)),
      );
      return;
    }
    if (name.startsWith('sync_journal_') && name.endsWith('.json')) {
      if (_decodeJson(content, name) is! Map<String, dynamic>) {
        throw FormatException('Drive backup file "$name" must be an object.');
      }
      return;
    }
    if (name.endsWith('.json')) {
      validateProtocol(Protocol.fromJson(_decodeMapString(content, name)));
      return;
    }
    throw FormatException('Drive backup file "$name" is not supported.');
  }

  static List<T> _decodeList<T>(
    Object value,
    T Function(Map<String, dynamic>) parser,
    String label,
  ) {
    return _mapList(_decodeJsonString(value, label), parser, label);
  }

  static List<String> _decodeStringList(Object value, String label) {
    final decoded = _decodeJsonString(value, label);
    if (decoded is! List) {
      throw FormatException('$label must be a list.');
    }
    return decoded.map((item) {
      if (item is! String) {
        throw FormatException('$label contains non-text ID.');
      }
      return item;
    }).toList();
  }

  static List<T> _mapList<T>(
    Object? decoded,
    T Function(Map<String, dynamic>) parser,
    String label,
  ) {
    if (decoded is! List) throw FormatException('$label must be a list.');
    _validateListSize(decoded.length, label);
    return decoded.map((item) {
      if (item is! Map) throw FormatException('$label contains invalid item.');
      return parser(Map<String, dynamic>.from(item));
    }).toList();
  }

  static Object _decodeJsonString(Object value, String label) {
    if (value is! String) throw FormatException('$label must be JSON text.');
    return _decodeJson(value, label);
  }

  static Object _decodeJson(String value, String label) {
    if (utf8.encode(value).length > maxPreferenceStringBytes) {
      throw FormatException('$label is too large.');
    }
    try {
      return jsonDecode(value);
    } catch (_) {
      throw FormatException('$label contains invalid JSON.');
    }
  }

  static Map<String, dynamic> _decodeMapString(Object value, String label) {
    final decoded = _decodeJsonString(value, label);
    if (decoded is! Map) throw FormatException('$label must be an object.');
    return Map<String, dynamic>.from(decoded);
  }

  static void _validatePrimitivePreference(Object value, String key) {
    if (value is String) {
      _optionalString(value, key, maxPreferenceStringBytes);
      return;
    }
    if (value is bool || value is int) return;
    if (value is double) {
      _range(value, key);
      return;
    }
    if (value is List<String>) {
      _validateListSize(value.length, key);
      for (final item in value) {
        _optionalString(item, key, maxShortText);
      }
      return;
    }
    throw FormatException('Local backup setting "$key" has invalid type.');
  }

  static void _parseDateString(Object value, String label) {
    if (value is! String || DateTime.tryParse(value) == null) {
      throw FormatException('$label must be a valid date.');
    }
  }

  static void _enumName(Object value, Iterable<String> names, String label) {
    if (value is! String || !names.contains(value)) {
      throw FormatException('$label has an invalid value.');
    }
  }

  static void _validateMetadata(Map<String, String> metadata) {
    if (metadata.length > maxMetadataEntries) {
      throw const FormatException('Metadata has too many entries.');
    }
    for (final entry in metadata.entries) {
      _requiredString(entry.key, 'Metadata key', maxShortText);
      _optionalString(entry.value, 'Metadata value', maxLongText);
    }
  }

  static void _validateCell(Object? cell) {
    if (cell == null || cell is bool) return;
    if (cell is num) {
      _range(cell.toDouble(), 'Table cell number');
      return;
    }
    if (cell is String) {
      _optionalString(cell, 'Table cell text', maxMediumText);
      return;
    }
    throw const FormatException('Table cell has unsupported data type.');
  }

  static void _requiredString(String? value, String label, int maxLength) {
    if (value == null || value.trim().isEmpty) {
      throw FormatException('$label is required.');
    }
    _optionalString(value, label, maxLength);
  }

  static void _optionalString(String? value, String label, int maxLength) {
    if (value == null) return;
    if (value.length > maxLength) {
      throw FormatException('$label is too long.');
    }
  }

  static void _validateListSize(int length, String label) {
    if (length > maxListItems) {
      throw FormatException('Too many $label.');
    }
  }

  static void _validateDate(DateTime value, String label) {
    if (value.year < 1970 || value.year > 2100) {
      throw FormatException('$label is outside the supported range.');
    }
  }

  static void _requiredFinite(double? value, String label) {
    if (value == null) throw FormatException('$label is required.');
    _range(value, label);
  }

  static void _range(double value, String label, {double? min, double? max}) {
    if (!value.isFinite) throw FormatException('$label must be finite.');
    if (min != null && value < min) {
      throw FormatException('$label is below the allowed range.');
    }
    if (max != null && value > max) {
      throw FormatException('$label is above the allowed range.');
    }
  }

  static void _intRange(int value, String label, {int? min, int? max}) {
    if (min != null && value < min) {
      throw FormatException('$label is below the allowed range.');
    }
    if (max != null && value > max) {
      throw FormatException('$label is above the allowed range.');
    }
  }
}
