import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/measuring_tool.dart';

class MeasuringToolService {
  MeasuringToolService._();

  static final MeasuringToolService instance = MeasuringToolService._();
  static const String _storageKey = 'measuring_tools_json';

  List<MeasuringTool>? _cachedTools;

  static const List<MeasuringTool> _defaultTools = [
    MeasuringTool(
      id: 'micropipette_m2_5',
      toolType: 'Micropipette',
      toolName: 'M2.5',
      minVolumeUl: 0.1,
      maxVolumeUl: 2.5,
      incrementUl: 0.05,
      accuracyRank: 3,
    ),
    MeasuringTool(
      id: 'micropipette_m10',
      toolType: 'Micropipette',
      toolName: 'M10',
      minVolumeUl: 0.5,
      maxVolumeUl: 10,
      incrementUl: 0.1,
      accuracyRank: 3,
    ),
    MeasuringTool(
      id: 'micropipette_m20',
      toolType: 'Micropipette',
      toolName: 'M20',
      minVolumeUl: 2,
      maxVolumeUl: 20,
      incrementUl: 0.5,
      accuracyRank: 3,
    ),
    MeasuringTool(
      id: 'micropipette_m50',
      toolType: 'Micropipette',
      toolName: 'M50',
      minVolumeUl: 5,
      maxVolumeUl: 50,
      incrementUl: 0.5,
      accuracyRank: 3,
    ),
    MeasuringTool(
      id: 'micropipette_m100',
      toolType: 'Micropipette',
      toolName: 'M100',
      minVolumeUl: 10,
      maxVolumeUl: 100,
      incrementUl: 1,
      accuracyRank: 3,
    ),
    MeasuringTool(
      id: 'micropipette_m200',
      toolType: 'Micropipette',
      toolName: 'M200',
      minVolumeUl: 20,
      maxVolumeUl: 200,
      incrementUl: 1,
      accuracyRank: 3,
    ),
    MeasuringTool(
      id: 'micropipette_m1000',
      toolType: 'Micropipette',
      toolName: 'M1000',
      minVolumeUl: 100,
      maxVolumeUl: 1000,
      incrementUl: 5,
      accuracyRank: 3,
    ),
    MeasuringTool(
      id: 'serological_1ml',
      toolType: 'serological pipette',
      toolName: '1 mL',
      minVolumeUl: 10,
      maxVolumeUl: 1000,
      incrementUl: 10,
      accuracyRank: 2,
    ),
    MeasuringTool(
      id: 'serological_2ml',
      toolType: 'serological pipette',
      toolName: '2 mL',
      minVolumeUl: 10,
      maxVolumeUl: 2000,
      incrementUl: 10,
      accuracyRank: 2,
    ),
    MeasuringTool(
      id: 'serological_5ml',
      toolType: 'serological pipette',
      toolName: '5 mL',
      minVolumeUl: 100,
      maxVolumeUl: 5000,
      incrementUl: 100,
      accuracyRank: 2,
    ),
    MeasuringTool(
      id: 'serological_10ml',
      toolType: 'serological pipette',
      toolName: '10 mL',
      minVolumeUl: 100,
      maxVolumeUl: 10000,
      incrementUl: 100,
      accuracyRank: 2,
    ),
    MeasuringTool(
      id: 'serological_25ml',
      toolType: 'serological pipette',
      toolName: '25 mL',
      minVolumeUl: 200,
      maxVolumeUl: 25000,
      incrementUl: 200,
      accuracyRank: 2,
    ),
    MeasuringTool(
      id: 'serological_50ml',
      toolType: 'serological pipette',
      toolName: '50 mL',
      minVolumeUl: 500,
      maxVolumeUl: 50000,
      incrementUl: 500,
      accuracyRank: 2,
    ),
    MeasuringTool(
      id: 'cylinder_5ml',
      toolType: 'Measuring cylinder',
      toolName: '5 mL',
      minVolumeUl: 100,
      maxVolumeUl: 5000,
      incrementUl: 100,
      accuracyRank: 1,
    ),
    MeasuringTool(
      id: 'cylinder_10ml',
      toolType: 'Measuring cylinder',
      toolName: '10 mL',
      minVolumeUl: 200,
      maxVolumeUl: 10000,
      incrementUl: 200,
      accuracyRank: 1,
    ),
    MeasuringTool(
      id: 'cylinder_25ml',
      toolType: 'Measuring cylinder',
      toolName: '25 mL',
      minVolumeUl: 500,
      maxVolumeUl: 25000,
      incrementUl: 500,
      accuracyRank: 1,
    ),
    MeasuringTool(
      id: 'cylinder_50ml',
      toolType: 'Measuring cylinder',
      toolName: '50 mL',
      minVolumeUl: 1000,
      maxVolumeUl: 50000,
      incrementUl: 1000,
      accuracyRank: 1,
    ),
    MeasuringTool(
      id: 'cylinder_100ml',
      toolType: 'Measuring cylinder',
      toolName: '100 mL',
      minVolumeUl: 1000,
      maxVolumeUl: 100000,
      incrementUl: 1000,
      accuracyRank: 1,
    ),
    MeasuringTool(
      id: 'cylinder_250ml',
      toolType: 'Measuring cylinder',
      toolName: '250 mL',
      minVolumeUl: 2000,
      maxVolumeUl: 250000,
      incrementUl: 2000,
      accuracyRank: 1,
    ),
    MeasuringTool(
      id: 'cylinder_500ml',
      toolType: 'Measuring cylinder',
      toolName: '500 mL',
      minVolumeUl: 5000,
      maxVolumeUl: 500000,
      incrementUl: 5000,
      accuracyRank: 1,
    ),
    MeasuringTool(
      id: 'cylinder_1000ml',
      toolType: 'Measuring cylinder',
      toolName: '1000 mL',
      minVolumeUl: 10000,
      maxVolumeUl: 1000000,
      incrementUl: 10000,
      accuracyRank: 1,
    ),
    MeasuringTool(
      id: 'cylinder_2000ml',
      toolType: 'Measuring cylinder',
      toolName: '2000 mL',
      minVolumeUl: 20000,
      maxVolumeUl: 2000000,
      incrementUl: 20000,
      accuracyRank: 1,
    ),
  ];

  Future<void> initialize() async {
    _cachedTools = await loadTools();
  }

  List<MeasuringTool> currentTools() {
    return List<MeasuringTool>.from(_cachedTools ?? _defaultTools);
  }

  List<MeasuringTool> activeTools() {
    return currentTools().where((tool) => tool.active).toList();
  }

  List<MeasuringTool> defaultTools() {
    return List<MeasuringTool>.from(_defaultTools);
  }

  Future<List<MeasuringTool>> loadTools() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return defaultTools();
    }

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final loaded = jsonList
          .whereType<Map>()
          .map(
            (json) => MeasuringTool.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
      if (loaded.isEmpty) {
        return defaultTools();
      }
      return loaded;
    } catch (_) {
      return defaultTools();
    }
  }

  Future<void> saveTools(List<MeasuringTool> tools) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(tools.map((tool) => tool.toJson()).toList());
    await prefs.setString(_storageKey, payload);
    _cachedTools = List<MeasuringTool>.from(tools);
  }

  Future<void> resetToDefaults() async {
    await saveTools(defaultTools());
  }
}
