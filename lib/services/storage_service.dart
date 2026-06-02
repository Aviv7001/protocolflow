import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/completed_protocol.dart';
import '../models/active_protocol.dart';
import '../models/protocol.dart';

class StorageService {
  static const String _storageKey = 'completed_protocols_json';
  static const String _activeKey = 'active_protocol_json';
  static const String _runningKey = 'running_protocols_json';
  static const String _libraryKey = 'protocols_library_json';

  Future<void> saveProtocols(List<Protocol> protocols) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(protocols.map((p) => p.toJson()).toList());
    await prefs.setString(_libraryKey, jsonString);
  }

  Future<List<Protocol>> loadProtocols() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_libraryKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => Protocol.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCompletedProtocols(List<CompletedProtocol> protocols) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(protocols.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  Future<List<CompletedProtocol>> loadCompletedProtocols() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => CompletedProtocol.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveActiveProtocol(ActiveProtocol? protocol) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (protocol == null) {
      await prefs.remove(_activeKey);
    } else {
      final String jsonString = jsonEncode(protocol.toJson());
      await prefs.setString(_activeKey, jsonString);
    }
  }

  Future<ActiveProtocol?> loadActiveProtocol() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_activeKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      
      final dynamic jsonMap = jsonDecode(jsonString);
      return ActiveProtocol.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveRunningProtocols(List<ActiveProtocol> protocols) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(protocols.map((p) => p.toJson()).toList());
    await prefs.setString(_runningKey, jsonString);
  }

  Future<List<ActiveProtocol>> loadRunningProtocols() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_runningKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => ActiveProtocol.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }
}
