import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/task.dart';

class TaskService {
  static const String _todayTasksKey = 'today_tasks_json';
  static const String _historyTasksKey = 'history_tasks_json';

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
  }

  Future<void> clearHistoryTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyTasksKey);
  }

  Future<void> archiveDoneTasks() async {
    List<Task> today = await loadTodayTasks();
    List<Task> history = await loadHistoryTasks();

    final done = today
        .where((t) => t.isDone)
        .map((t) => t.copyWith(completedAt: DateTime.now()))
        .toList();
    final remaining = today.where((t) => !t.isDone).toList();

    if (done.isEmpty) return;

    history.insertAll(0, done);

    await saveTodayTasks(remaining);
    await saveHistoryTasks(history);
  }
}
