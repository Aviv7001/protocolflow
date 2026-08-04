import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/task.dart';
import '../../../services/storage_service.dart';

class TaskService {
  static const String _todayTasksKey = 'today_tasks_json';
  static const String _historyTasksKey = 'history_tasks_json';
  static const String _syncUpdatedAtKey = 'tasks_sync_updated_at';

  Future<void> validateLocalSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in <String, String>{
      _todayTasksKey: "today's tasks",
      _historyTasksKey: 'task history',
    }.entries) {
      final encoded = prefs.getString(entry.key);
      if (encoded == null) continue;
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is! List) throw const FormatException();
      } catch (_) {
        throw FormatException(
          'Local ${entry.value} data is damaged. Sync was stopped to protect Drive data.',
        );
      }
    }
  }

  Future<List<Task>> loadTodayTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_todayTasksKey);
    if (jsonString == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => Task.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveTodayTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_todayTasksKey, jsonString);
    await prefs.setString(_syncUpdatedAtKey, DateTime.now().toIso8601String());
    await StorageService().saveSyncBundleState(
      SyncBundleType.tasks,
      SyncBundleState.pending,
    );
  }

  Future<List<Task>> loadHistoryTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historyTasksKey);
    if (jsonString == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => Task.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveHistoryTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_historyTasksKey, jsonString);
    await prefs.setString(_syncUpdatedAtKey, DateTime.now().toIso8601String());
    await StorageService().saveSyncBundleState(
      SyncBundleType.tasks,
      SyncBundleState.pending,
    );
  }

  Future<void> clearHistoryTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyTasksKey);
    await prefs.setString(_syncUpdatedAtKey, DateTime.now().toIso8601String());
    await StorageService().saveSyncBundleState(
      SyncBundleType.tasks,
      SyncBundleState.pending,
    );
  }

  Future<Map<String, dynamic>> buildSyncPayload() async {
    final prefs = await SharedPreferences.getInstance();
    var updatedAt = DateTime.tryParse(prefs.getString(_syncUpdatedAtKey) ?? '');
    if (updatedAt == null) {
      final hasLegacyData =
          prefs.containsKey(_todayTasksKey) ||
          prefs.containsKey(_historyTasksKey);
      updatedAt = hasLegacyData
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (hasLegacyData) {
        await prefs.setString(_syncUpdatedAtKey, updatedAt.toIso8601String());
      }
    }
    return {
      'updatedAt': updatedAt.toIso8601String(),
      'today': (await loadTodayTasks()).map((task) => task.toJson()).toList(),
      'history': (await loadHistoryTasks())
          .map((task) => task.toJson())
          .toList(),
    };
  }

  Future<void> replaceFromSyncPayload(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final today = (payload['today'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Task.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final history = (payload['history'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Task.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    await prefs.setString(
      _todayTasksKey,
      jsonEncode(today.map((task) => task.toJson()).toList()),
    );
    await prefs.setString(
      _historyTasksKey,
      jsonEncode(history.map((task) => task.toJson()).toList()),
    );
    await prefs.setString(
      _syncUpdatedAtKey,
      payload['updatedAt']?.toString() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String(),
    );
  }

  Future<void> archiveDoneTasks() async {
    List<Task> today = await loadTodayTasks();
    List<Task> history = await loadHistoryTasks();

    final done = today
        .where((t) => t.status == TaskStatus.completed)
        .map((t) => t.copyWith(completedAt: DateTime.now()))
        .toList();
    final remaining = today
        .where((t) => t.status != TaskStatus.completed)
        .toList();

    if (done.isEmpty) return;

    history.insertAll(0, done);

    await saveTodayTasks(remaining);
    await saveHistoryTasks(history);
  }
}
