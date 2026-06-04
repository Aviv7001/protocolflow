import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/widgets/action_timer_wrapper.dart';
import 'package:protocolflow/widgets/local_image.dart';
import 'package:protocolflow/widgets/protocol_table_widget.dart';
import 'package:protocolflow/screens/library_screen.dart';

class RunProtocolScreen extends StatefulWidget {
  const RunProtocolScreen({
    super.key,
    required this.protocol,
    this.initialStepIndex,
    this.finalStepIndex,
  });

  final Protocol protocol;
  final int? initialStepIndex;
  final int? finalStepIndex;

  @override
  State<RunProtocolScreen> createState() => _RunProtocolScreenState();
}

class _RunProtocolScreenState extends State<RunProtocolScreen> {
  late int currentStepIndex;
  late Protocol protocol;
  late List<StepNote> _notes;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Initialize from activeProtocol if it exists and matches
    if (activeProtocol != null &&
        activeProtocol!.protocol.id == widget.protocol.id) {
      protocol = activeProtocol!.protocol;
      currentStepIndex =
          widget.initialStepIndex ?? activeProtocol!.currentStepIndex;
      _notes = activeProtocol!.notes;

      // If it's a phase-based run and we just started it (initial index is set), reset timer
      if (widget.initialStepIndex != null &&
          widget.initialStepIndex != activeProtocol!.currentStepIndex) {
        _elapsedTime = Duration.zero;
        // We might want to update activeProtocol startedAt for this phase session
        activeProtocol = activeProtocol!.copyWith(startedAt: DateTime.now());
      } else {
        _elapsedTime = DateTime.now().difference(activeProtocol!.startedAt);
      }
    } else {
      // Start fresh or replace active protocol
      protocol = widget.protocol;
      currentStepIndex = widget.initialStepIndex ?? -1;
      _notes = [];
      _updateActiveProtocol();
    }
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (activeProtocol != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(activeProtocol!.startedAt);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  void _updateActiveProtocol() {
    activeProtocol = ActiveProtocol(
      protocol: protocol,
      currentStepIndex: currentStepIndex,
      notes: _notes,
      startedAt: activeProtocol?.startedAt ?? DateTime.now(),
      timerStartTimes: activeProtocol?.timerStartTimes ?? {},
      pausedSeconds: activeProtocol?.pausedSeconds ?? {},
      completedStepIds: activeProtocol?.completedStepIds ?? {},
    );
    savePersistentProtocols();
  }

  List<ProtocolStep> get steps => protocol.sortedSteps;

  ProtocolStep? get currentStep =>
      currentStepIndex >= 0 ? steps[currentStepIndex] : null;

  void _goToPreviousStep() {
    final firstIndex = widget.initialStepIndex ?? -1;
    if (currentStepIndex > firstIndex) {
      setState(() {
        currentStepIndex--;
        _updateActiveProtocol();
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _goToNextStep() {
    final lastIndex = widget.finalStepIndex ?? steps.length - 1;
    final firstIndex = widget.initialStepIndex ?? 0;

    // Mark current step as completed
    if (currentStepIndex >= 0) {
      final step = steps[currentStepIndex];
      final newCompleted = Set<String>.from(
        activeProtocol?.completedStepIds ?? {},
      )..add(step.id);
      activeProtocol = activeProtocol?.copyWith(completedStepIds: newCompleted);
    }

    if (currentStepIndex < lastIndex) {
      setState(() {
        currentStepIndex++;
        _updateActiveProtocol();
      });
    } else {
      // If finishing a phase/range, mark ALL steps in that range as done
      if (widget.initialStepIndex != null || widget.finalStepIndex != null) {
        final newCompleted = Set<String>.from(
          activeProtocol?.completedStepIds ?? {},
        );
        for (int i = firstIndex; i <= lastIndex; i++) {
          newCompleted.add(steps[i].id);
        }
        activeProtocol = activeProtocol?.copyWith(
          completedStepIds: newCompleted,
        );
      }

      if (widget.finalStepIndex != null &&
          widget.finalStepIndex! < steps.length - 1) {
        _showPhaseCompletionDialog();
      } else {
        _showCompletionDialog();
      }
    }
  }

  void _showPhaseCompletionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Phase Completed'),
        content: const Text(
          'You have finished this phase. The protocol will be stored in your running list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () async {
              if (activeProtocol != null) {
                // Move from active to running list
                runningProtocols.removeWhere(
                  (p) => p.protocol.id == activeProtocol!.protocol.id,
                );
                runningProtocols.add(activeProtocol!);
                activeProtocol = null;
              }

              await savePersistentProtocols();
              if (!mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LibraryScreen(initialTabIndex: 1),
                ),
                (route) => route.isFirst,
              );
            },
            child: const Text('Complete Phase'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Protocol?'),
        content: const Text(
          'You have reached the end of the protocol. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Go Back'),
          ),
          TextButton(
            onPressed: () async {
              if (activeProtocol != null) {
                // Move from active to running list
                runningProtocols.removeWhere(
                  (p) => p.protocol.id == activeProtocol!.protocol.id,
                );
                runningProtocols.add(activeProtocol!);
                activeProtocol = null;
              }

              await savePersistentProtocols();
              if (!mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LibraryScreen(initialTabIndex: 1),
                ),
                (route) => route.isFirst,
              );
            },
            child: const Text('Keep in Running'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Mark current step as completed
              if (currentStepIndex >= 0) {
                final step = steps[currentStepIndex];
                final newCompleted = Set<String>.from(
                  activeProtocol?.completedStepIds ?? {},
                )..add(step.id);
                activeProtocol = activeProtocol?.copyWith(
                  completedStepIds: newCompleted,
                );
              }

              completedProtocols.add(
                CompletedProtocol(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  protocol: protocol,
                  notes: List.from(_notes),
                  completedAt: DateTime.now(),
                ),
              );

              if (activeProtocol != null) {
                runningProtocols.removeWhere(
                  (p) => p.protocol.id == activeProtocol!.protocol.id,
                );
                activeProtocol = null;
              }

              await savePersistentProtocols();
              if (!mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LibraryScreen(initialTabIndex: 2),
                ),
                (route) => route.isFirst,
              );
            },
            child: const Text('Complete Protocol'),
          ),
        ],
      ),
    );
  }

  void _cancelProtocol() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Protocol?'),
        content: const Text(
          'Are you sure you want to cancel this protocol? All progress and notes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Continue'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              activeProtocol = null;
              await savePersistentProtocols();
              if (mounted) {
                navigator.pop(); // Close dialog
                navigator.pop(); // Exit run screen
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _addNote() {
    final TextEditingController controller = TextEditingController();
    final List<String> pickedImagePaths = [];
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Note'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter your note here',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    if (pickedImagePaths.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 3 / 4,
                            ),
                        itemCount: pickedImagePaths.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: buildLocalImage(pickedImagePaths[index]),
                              ),
                              Positioned(
                                top: -10,
                                right: -10,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () => setDialogState(
                                    () => pickedImagePaths.removeAt(index),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final XFile? photo = await picker.pickImage(
                              source: ImageSource.camera,
                            );
                            if (photo != null) {
                              setDialogState(
                                () => pickedImagePaths.add(photo.path),
                              );
                            }
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final List<XFile> images = await picker
                                .pickMultiImage();
                            if (images.isNotEmpty) {
                              setDialogState(
                                () => pickedImagePaths.addAll(
                                  images.map((e) => e.path),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.isNotEmpty ||
                      pickedImagePaths.isNotEmpty) {
                    setState(() {
                      _notes.add(
                        StepNote(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          stepId: currentStepIndex >= 0
                              ? steps[currentStepIndex].id
                              : 'materials',
                          note: controller.text,
                          photoPaths: List.from(pickedImagePaths),
                          createdAt: DateTime.now(),
                        ),
                      );
                      _updateActiveProtocol();
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotesList() {
    final String currentStepId = currentStepIndex >= 0
        ? steps[currentStepIndex].id
        : 'materials';

    final stepNotes = _notes.where((n) => n.stepId == currentStepId).toList();

    if (stepNotes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          'Notes for this step:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        // Joined Photo Grid
        if (stepNotes.any((n) => n.photoPaths.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3 / 4,
              ),
              itemCount: stepNotes.fold<int>(
                0,
                (sum, n) => sum + n.photoPaths.length,
              ),
              itemBuilder: (context, globalIdx) {
                // Find which note and which photo within that note this globalIdx refers to
                int count = 0;
                int noteIdx = -1;
                int photoInNoteIdx = -1;
                String? path;

                for (int i = 0; i < stepNotes.length; i++) {
                  final n = stepNotes[i];
                  if (globalIdx < count + n.photoPaths.length) {
                    noteIdx = i + 1;
                    photoInNoteIdx = globalIdx - count + 1;
                    path = n.photoPaths[photoInNoteIdx - 1];
                    break;
                  }
                  count += n.photoPaths.length;
                }

                if (path == null) return const SizedBox.shrink();

                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: buildLocalImage(path),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$noteIdx.$photoInNoteIdx',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        // Text Notes
        ...stepNotes.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final note = entry.value;
          if (note.note.isEmpty) return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.note,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _editStep() {
    if (currentStepIndex < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot edit materials.')));
      return;
    }

    final step = steps[currentStepIndex];
    final TextEditingController titleController = TextEditingController(
      text: step.title,
    );
    final TextEditingController instructionsController = TextEditingController(
      text: step.instructions,
    );
    final TextEditingController dayController = TextEditingController(
      text: step.day.toString(),
    );

    // Track timers in local state of dialog as raw integers
    Map<int, int> localActionTimers = Map.from(step.actionTimers);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Step'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Day: '),
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Action Timers',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...step.actionItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final actionText = entry.value;
                      final totalSeconds = localActionTimers[idx] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                actionText,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            _ActionTimerInput(
                              totalSeconds: totalSeconds,
                              onChanged: (newTotal) {
                                setDialogState(() {
                                  if (newTotal > 0) {
                                    localActionTimers[idx] = newTotal;
                                  } else {
                                    localActionTimers.remove(idx);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    // Clean up 0 timers
                    localActionTimers.removeWhere((key, value) => value <= 0);

                    final updatedStep = step.copyWith(
                      title: titleController.text,
                      instructions: instructionsController.text,
                      day: int.tryParse(dayController.text) ?? step.day,
                      actionTimers: localActionTimers,
                    );
                    final updatedSteps = List<ProtocolStep>.from(
                      protocol.steps,
                    );
                    updatedSteps[currentStepIndex] = updatedStep;
                    protocol = protocol.copyWith(steps: updatedSteps);
                    _updateActiveProtocol();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openFiles() {
    final currentStepTableIds = currentStep?.tableIds.toSet() ?? <String>{};
    final currentStepTables = protocol.tables
        .where((t) => currentStepTableIds.contains(t.id))
        .toList();
    // Get all tables assigned to any step
    final assignedTableIds = protocol.steps.expand((s) => s.tableIds).toSet();
    // Filter tables that are NOT assigned to any step
    final unassignedTables = protocol.tables
        .where((t) => !assignedTableIds.contains(t.id))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      'Attached Files & Data',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (protocol.files.isEmpty &&
                        currentStepTables.isEmpty &&
                        unassignedTables.isEmpty)
                      const Text('No files or detached tables found.')
                    else ...[
                      if (currentStepTables.isNotEmpty) ...[
                        const Text(
                          'Current Step Tables',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTableGrid(currentStepTables),
                        const SizedBox(height: 16),
                      ],
                      if (protocol.files.isNotEmpty) ...[
                        const Text(
                          'Documents',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildFileGrid(protocol.files),
                        const SizedBox(height: 16),
                      ],
                      if (unassignedTables.isNotEmpty) ...[
                        const Text(
                          'Reference Tables',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTableGrid(unassignedTables),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTableGrid(List<ProtocolTable> tables) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tables.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) =>
          ProtocolTableWidget(table: tables[index]),
    );
  }

  Widget _buildFileGrid(List<String> files) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final fileName = files[index];
        return InkWell(
          onTap: () {
            debugPrint('Open file: $fileName');
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.insert_drive_file, size: 32),
                const SizedBox(height: 8),
                Text(
                  fileName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = 'Run Protocol';
    String? daySubtitle;
    if (currentStepIndex == -1) {
      appBarTitle = 'Materials';
    } else {
      if (widget.finalStepIndex != null) {
        final step = steps[currentStepIndex];
        appBarTitle = step.phaseName ?? 'Running Phase';
        daySubtitle = 'Step ${currentStepIndex + 1} of ${steps.length}';
      } else {
        appBarTitle = 'Step ${currentStepIndex + 1} of ${steps.length}';
        daySubtitle = 'Day ${steps[currentStepIndex].day}';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appBarTitle, style: const TextStyle(fontSize: 18)),
            if (daySubtitle != null)
              Text(
                daySubtitle,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
          ],
        ),
        actions: [
          Center(
            child: Text(
              _formatDuration(_elapsedTime),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            onPressed: _cancelProtocol,
            tooltip: 'Cancel Protocol',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: _buildBody()),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: _goToPreviousStep,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Previous',
              ),
              IconButton(
                onPressed: _addNote,
                icon: const Icon(Icons.note_add),
                tooltip: 'Note',
              ),
              IconButton(
                onPressed: _editStep,
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: _goToNextStep,
                icon: Icon(
                  currentStepIndex ==
                          (widget.finalStepIndex ?? steps.length - 1)
                      ? Icons.check
                      : Icons.arrow_forward,
                ),
                tooltip:
                    currentStepIndex ==
                        (widget.finalStepIndex ?? steps.length - 1)
                    ? 'Finish'
                    : 'Next',
              ),
              IconButton(
                onPressed: _openFiles,
                icon: const Icon(Icons.folder_open),
                tooltip: 'Files',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (currentStepIndex == -1) {
      return _buildMaterialsChecklist();
    } else {
      return _buildStepExecution();
    }
  }

  Widget _buildMaterialsChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Material List', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Ensure you have everything ready before starting.'),
        const SizedBox(height: 16),
        Expanded(
          child: protocol.materials.isEmpty
              ? const Center(child: Text('No materials listed.'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Quantity')),
                        DataColumn(label: Text('Catalog #')),
                        DataColumn(label: Text('Manufacturer')),
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('Stock Conc.')),
                      ],
                      rows: protocol.materials
                          .map(
                            (m) => DataRow(
                              cells: [
                                DataCell(Text(m.name)),
                                DataCell(Text(m.quantity)),
                                DataCell(Text(m.catalogNumber)),
                                DataCell(Text(m.manufacturer)),
                                DataCell(Text(m.location)),
                                DataCell(Text(m.stockConcentration)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
        ),
        _buildNotesList(),
      ],
    );
  }

  Widget _buildStepExecution() {
    final step = currentStep!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(step.instructions),
        const SizedBox(height: 16),
        Text('Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: step.actionItems.length,
            itemBuilder: (context, index) {
              final actionText = step.actionItems[index];
              final int? actionTimer = step.actionTimers[index];

              Widget cardContent = ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                title: Text(actionText),
              );

              if (actionTimer != null) {
                final timerKey = '${step.id}_$index';
                cardContent = ActionTimerWrapper(
                  totalSeconds: actionTimer,
                  startTime: activeProtocol?.timerStartTimes[timerKey],
                  remainingSeconds: activeProtocol?.pausedSeconds[timerKey],
                  onStart: (startTime) {
                    setState(() {
                      final newStarts = Map<String, DateTime>.from(
                        activeProtocol?.timerStartTimes ?? {},
                      );
                      final newPaused = Map<String, int>.from(
                        activeProtocol?.pausedSeconds ?? {},
                      );
                      newStarts[timerKey] = startTime;
                      // When starting, if it was paused, we stay at that value,
                      // if not, it will be initial.
                      // ActionTimerWrapper handles the math.
                      activeProtocol = activeProtocol?.copyWith(
                        timerStartTimes: newStarts,
                        pausedSeconds: newPaused,
                      );
                    });
                    _updateActiveProtocol();
                  },
                  onStop: (remaining) {
                    setState(() {
                      final newStarts = Map<String, DateTime>.from(
                        activeProtocol?.timerStartTimes ?? {},
                      );
                      final newPaused = Map<String, int>.from(
                        activeProtocol?.pausedSeconds ?? {},
                      );
                      newStarts.remove(timerKey);
                      newPaused[timerKey] = remaining;
                      activeProtocol = activeProtocol?.copyWith(
                        timerStartTimes: newStarts,
                        pausedSeconds: newPaused,
                      );
                    });
                    _updateActiveProtocol();
                  },
                  onReset: () {
                    setState(() {
                      final newStarts = Map<String, DateTime>.from(
                        activeProtocol?.timerStartTimes ?? {},
                      );
                      final newPaused = Map<String, int>.from(
                        activeProtocol?.pausedSeconds ?? {},
                      );
                      newStarts.remove(timerKey);
                      newPaused.remove(timerKey);
                      activeProtocol = activeProtocol?.copyWith(
                        timerStartTimes: newStarts,
                        pausedSeconds: newPaused,
                      );
                    });
                    _updateActiveProtocol();
                  },
                  onFinished: () {
                    setState(() {
                      final newStarts = Map<String, DateTime>.from(
                        activeProtocol?.timerStartTimes ?? {},
                      );
                      final newPaused = Map<String, int>.from(
                        activeProtocol?.pausedSeconds ?? {},
                      );
                      newStarts.remove(timerKey);
                      newPaused[timerKey] = 0;
                      activeProtocol = activeProtocol?.copyWith(
                        timerStartTimes: newStarts,
                        pausedSeconds: newPaused,
                      );
                    });
                    _updateActiveProtocol();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Action "$actionText" finished!'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.green,
                        action: SnackBarAction(
                          label: 'OK',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                  child: cardContent,
                );
              }

              return Card(clipBehavior: Clip.antiAlias, child: cardContent);
            },
          ),
        ),
        _buildNotesList(),
      ],
    );
  }
}

class _ActionTimerInput extends StatefulWidget {
  final int totalSeconds;
  final Function(int) onChanged;

  const _ActionTimerInput({
    required this.totalSeconds,
    required this.onChanged,
  });

  @override
  State<_ActionTimerInput> createState() => _ActionTimerInputState();
}

class _ActionTimerInputState extends State<_ActionTimerInput> {
  late String _unit;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _determineUnitAndValue();
  }

  void _determineUnitAndValue() {
    if (widget.totalSeconds == 0) {
      _unit = 'M';
      _controller = TextEditingController();
    } else if (widget.totalSeconds >= 3600) {
      _unit = 'H';
      _controller = TextEditingController(
        text: _formatDecimal(widget.totalSeconds / 3600),
      );
    } else if (widget.totalSeconds >= 60) {
      _unit = 'M';
      _controller = TextEditingController(
        text: _formatDecimal(widget.totalSeconds / 60),
      );
    } else {
      _unit = 'S';
      _controller = TextEditingController(text: widget.totalSeconds.toString());
    }
  }

  String _formatDecimal(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 45,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => _updateValue(),
          ),
        ),
        const SizedBox(width: 4),
        DropdownButton<String>(
          value: _unit,
          isDense: true,
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 13, color: Colors.black),
          items: const [
            DropdownMenuItem(value: 'H', child: Text('H')),
            DropdownMenuItem(value: 'M', child: Text('M')),
            DropdownMenuItem(value: 'S', child: Text('S')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _unit = v);
              _updateValue();
            }
          },
        ),
      ],
    );
  }

  void _updateValue() {
    final val = double.tryParse(_controller.text) ?? 0;
    int total = 0;
    if (_unit == 'H') {
      total = (val * 3600).round();
    } else if (_unit == 'M') {
      total = (val * 60).round();
    } else {
      total = val.round();
    }
    widget.onChanged(total);
  }
}
