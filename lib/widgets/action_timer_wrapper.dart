import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActionTimerWrapper extends StatefulWidget {
  final Widget child;
  final int totalSeconds;
  final int? remainingSeconds;
  final DateTime? startTime;
  final Function(DateTime)? onStart;
  final Function(int)? onStop;
  final VoidCallback? onReset;
  final VoidCallback? onFinished;

  const ActionTimerWrapper({
    super.key,
    required this.child,
    required this.totalSeconds,
    this.remainingSeconds,
    this.startTime,
    this.onStart,
    this.onStop,
    this.onReset,
    this.onFinished,
  });

  @override
  State<ActionTimerWrapper> createState() => _ActionTimerWrapperState();
}

class _ActionTimerWrapperState extends State<ActionTimerWrapper> {
  late int _displaySeconds;
  Timer? _timer;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _initTimerState();
  }

  void _initTimerState() {
    if (widget.startTime != null) {
      _isRunning = true;
      final elapsed = DateTime.now().difference(widget.startTime!).inSeconds;
      final initialRemaining = widget.remainingSeconds ?? widget.totalSeconds;
      _displaySeconds = (initialRemaining - elapsed).clamp(0, widget.totalSeconds);
      _startTimer(widget.startTime!, initialRemaining);
    } else {
      _isRunning = false;
      _displaySeconds = widget.remainingSeconds ?? widget.totalSeconds;
    }
  }

  @override
  void didUpdateWidget(ActionTimerWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime || 
        oldWidget.remainingSeconds != widget.remainingSeconds ||
        oldWidget.totalSeconds != widget.totalSeconds) {
      _timer?.cancel();
      _initTimerState();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime start, int fromRemaining) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(start).inSeconds;
      final remaining = (fromRemaining - elapsed).clamp(0, widget.totalSeconds);
      
      if (mounted) {
        setState(() {
          _displaySeconds = remaining;
        });
      }

      if (remaining <= 0) {
        _timer?.cancel();
        if (mounted) setState(() => _isRunning = false);
        _playFinishSound();
        widget.onFinished?.call();
      }
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      widget.onStop?.call(_displaySeconds);
    } else {
      if (_displaySeconds <= 0) {
        // Reset if finished and play again
        _displaySeconds = widget.totalSeconds;
      }
      final newStart = DateTime.now();
      widget.onStart?.call(newStart);
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _displaySeconds = widget.totalSeconds;
    });
    widget.onReset?.call();
  }

  void _playFinishSound() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    int hrs = mins ~/ 60;
    mins = mins % 60;

    if (hrs > 0) {
      return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    double progress = 1 - (_displaySeconds / widget.totalSeconds);
    
    Color progressColor;
    if (_displaySeconds == 0) {
      progressColor = Colors.green.withValues(alpha: 0.2);
    } else if (_displaySeconds < 30) {
      progressColor = Colors.orange.withValues(alpha: 0.2);
    } else {
      progressColor = Colors.blue.withValues(alpha: 0.2);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ),
        widget.child,
        Positioned(
          right: 4,
          top: 0,
          bottom: 0,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(_displaySeconds),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _displaySeconds == 0 ? Colors.green : Colors.black54,
                  ),
                ),
                IconButton(
                  onPressed: _toggleTimer,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  icon: Icon(
                    _isRunning ? Icons.pause_circle : Icons.play_circle,
                    color: _isRunning ? Colors.blue : Colors.grey,
                  ),
                ),
                IconButton(
                  onPressed: _resetTimer,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                  tooltip: 'Reset',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
