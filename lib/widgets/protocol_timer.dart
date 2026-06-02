import 'dart:async';
import 'package:flutter/material.dart';

class ProtocolTimer extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback? onFinished;

  const ProtocolTimer({
    super.key,
    required this.initialSeconds,
    this.onFinished,
  });

  @override
  State<ProtocolTimer> createState() => _ProtocolTimerState();
}

class _ProtocolTimerState extends State<ProtocolTimer> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
  }

  @override
  void didUpdateWidget(ProtocolTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSeconds != widget.initialSeconds) {
      _stopTimer();
      setState(() {
        _remainingSeconds = widget.initialSeconds;
        _isRunning = false;
      });
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    if (_remainingSeconds > 0) {
      setState(() {
        _isRunning = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          _stopTimer();
          widget.onFinished?.call();
        }
      });
    }
  }

  void _pauseTimer() {
    _stopTimer();
    setState(() {
      _isRunning = false;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _remainingSeconds = widget.initialSeconds;
      _isRunning = false;
    });
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    int hrs = mins ~/ 60;
    mins = mins % 60;

    String hrsStr = hrs > 0 ? '${hrs.toString().padLeft(2, '0')}:' : '';
    return '$hrsStr${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    double progress = widget.initialSeconds > 0
        ? _remainingSeconds / widget.initialSeconds
        : 0;

    Color progressColor = _remainingSeconds < 30 ? Colors.orange : Colors.blue;
    if (_remainingSeconds == 0) progressColor = Colors.red;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 150,
          width: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
              Center(
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isRunning)
              IconButton.filled(
                onPressed: _startTimer,
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Start Timer',
              )
            else
              IconButton.filledTonal(
                onPressed: _pauseTimer,
                icon: const Icon(Icons.pause),
                tooltip: 'Pause Timer',
              ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: _resetTimer,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Timer',
            ),
          ],
        ),
      ],
    );
  }
}
