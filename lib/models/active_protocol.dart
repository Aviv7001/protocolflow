import 'protocol.dart';
import 'step_note.dart';

class ActiveProtocol {
  final Protocol protocol;
  int currentStepIndex;
  final List<StepNote> notes;
  final DateTime startedAt;
  final Map<String, DateTime> timerStartTimes;
  final Map<String, int> pausedSeconds;
  final Set<String> completedStepIds;

  ActiveProtocol({
    required this.protocol,
    this.currentStepIndex = -1,
    required this.notes,
    required this.startedAt,
    this.timerStartTimes = const {},
    this.pausedSeconds = const {},
    this.completedStepIds = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol.toJson(),
      'currentStepIndex': currentStepIndex,
      'notes': notes.map((n) => n.toJson()).toList(),
      'startedAt': startedAt.toIso8601String(),
      'timerStartTimes': timerStartTimes.map(
        (k, v) => MapEntry(k, v.toIso8601String()),
      ),
      'pausedSeconds': pausedSeconds,
      'completedStepIds': completedStepIds.toList(),
    };
  }

  factory ActiveProtocol.fromJson(Map<String, dynamic> json) {
    return ActiveProtocol(
      protocol: Protocol.fromJson(json['protocol']),
      currentStepIndex: json['currentStepIndex'] ?? -1,
      notes: (json['notes'] as List? ?? [])
          .map((n) => StepNote.fromJson(n))
          .toList(),
      startedAt: DateTime.parse(
        json['startedAt'] ?? DateTime.now().toIso8601String(),
      ),
      timerStartTimes: (json['timerStartTimes'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, DateTime.parse(v as String)),
      ),
      pausedSeconds: (json['pausedSeconds'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as int),
      ),
      completedStepIds: Set<String>.from(json['completedStepIds'] ?? []),
    );
  }

  ActiveProtocol copyWith({
    Protocol? protocol,
    int? currentStepIndex,
    List<StepNote>? notes,
    DateTime? startedAt,
    Map<String, DateTime>? timerStartTimes,
    Map<String, int>? pausedSeconds,
    Set<String>? completedStepIds,
  }) {
    return ActiveProtocol(
      protocol: (protocol ?? this.protocol).deepCopy(),
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      notes: (notes ?? this.notes).map((n) => n.deepCopy()).toList(),
      startedAt: startedAt ?? this.startedAt,
      timerStartTimes: Map<String, DateTime>.from(
        timerStartTimes ?? this.timerStartTimes,
      ),
      pausedSeconds: Map<String, int>.from(pausedSeconds ?? this.pausedSeconds),
      completedStepIds: Set<String>.from(
        completedStepIds ?? this.completedStepIds,
      ),
    );
  }
}
