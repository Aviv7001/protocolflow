import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/services/picked_image_store.dart';
import 'package:protocolflow/services/auth_service.dart';
import 'package:protocolflow/theme/app_colors.dart';
import 'package:protocolflow/widgets/action_timer_wrapper.dart';
import 'package:protocolflow/widgets/local_image.dart';
import 'package:protocolflow/widgets/phase_segmented_progress.dart';
import 'package:protocolflow/widgets/protocol_step_actions_table.dart';
import 'package:protocolflow/widgets/protocol_step_notes_table.dart';
import 'package:protocolflow/widgets/protocol_table_preview.dart';
import 'package:protocolflow/widgets/protocolflow_app_bar.dart';
import 'package:protocolflow/widgets/responsive_layout.dart';
import 'package:protocolflow/screens/home_screen.dart';

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
  bool _allowPop = false;
  bool _isExitDialogVisible = false;

  @override
  void initState() {
    super.initState();
    final session = activateProtocolSession(
      widget.protocol,
      initialStepIndex: widget.initialStepIndex,
    );
    protocol = session.protocol;
    currentStepIndex = session.currentStepIndex;
    _notes = session.notes;
    _elapsedTime = DateTime.now().difference(session.startedAt);
    unawaited(savePersistentProtocols());
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
    final currentSession = activeProtocol?.protocol.id == protocol.id
        ? activeProtocol
        : null;
    activeProtocol = ActiveProtocol(
      protocol: protocol,
      currentStepIndex: currentStepIndex,
      notes: _notes,
      startedAt: currentSession?.startedAt ?? DateTime.now(),
      timerStartTimes: currentSession?.timerStartTimes ?? {},
      pausedSeconds: currentSession?.pausedSeconds ?? {},
      completedStepIds: currentSession?.completedStepIds ?? {},
    );
    unawaited(savePersistentProtocols());
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
      _requestExitRun();
    }
  }

  Future<void> _requestExitRun() async {
    if (_isExitDialogVisible || !mounted) return;
    _isExitDialogVisible = true;
    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave protocol run?'),
        content: const Text(
          'Pause this run to preserve the current step, notes, completed actions, and timers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'continue'),
            child: const Text('Continue run'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard run'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'pause'),
            icon: const Icon(Icons.pause),
            label: const Text('Pause run'),
          ),
        ],
      ),
    );
    _isExitDialogVisible = false;
    if (!mounted || decision == null || decision == 'continue') return;

    if (decision == 'pause') {
      pauseProtocolSession(protocol.id);
    } else if (decision == 'discard') {
      discardProtocolSession(protocol.id);
    }
    await savePersistentProtocols();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
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
              pauseProtocolSession(protocol.id);

              await savePersistentProtocols();
              if (!mounted) return;

              _returnToLibrary(2);
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
              pauseProtocolSession(protocol.id);

              await savePersistentProtocols();
              if (!mounted) return;

              _returnToLibrary(2);
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
                  startedAt: activeProtocol?.startedAt,
                  completedAt: DateTime.now(),
                  completedByName:
                      AuthService.instance.currentUser?.displayName ??
                      AuthService.instance.currentUser?.email,
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

              _returnToLibrary(3);
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
              Navigator.pop(context);
              discardProtocolSession(protocol.id);
              await savePersistentProtocols();
              if (!mounted) return;
              setState(() => _allowPop = true);
              Navigator.of(this.context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _returnToLibrary(int tabIndex) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomeScreen(initialLibraryTabIndex: tabIndex),
      ),
      (route) => false,
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
                              final storedPath =
                                  await PickedImageStore.persistPickedImage(
                                    photo,
                                  );
                              setDialogState(
                                () => pickedImagePaths.add(storedPath),
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
                              final storedPaths = <String>[];
                              for (final image in images) {
                                storedPaths.add(
                                  await PickedImageStore.persistPickedImage(
                                    image,
                                  ),
                                );
                              }
                              setDialogState(
                                () => pickedImagePaths.addAll(storedPaths),
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

  Widget _buildNotesList({bool showHeading = true}) {
    final stepNotes = _currentRunNotes();

    if (stepNotes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          const Divider(height: 32),
          Text(
            'User Notes for this step:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
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

  // Retained for a future step-edit route; run navigation no longer exposes it.
  // ignore: unused_element
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
    final unlinkedTables = _unlinkedTables();
    final additionalData = protocol.additionalData;
    final attachedFiles = protocol.files;

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
                      'Resources',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Reference tables, additional data, and attached files for this protocol.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (unlinkedTables.isEmpty &&
                        additionalData.isEmpty &&
                        attachedFiles.isEmpty)
                      _buildEmptyState('No resources attached.')
                    else ...[
                      if (unlinkedTables.isNotEmpty) ...[
                        _buildResourceSheetSection(
                          context,
                          title: 'Reference Tables',
                          child: LinkedProtocolTablesSection(
                            tables: unlinkedTables,
                            initiallyCollapsed: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (additionalData.isNotEmpty) ...[
                        _buildResourceSheetSection(
                          context,
                          title: 'Additional Data',
                          child: Column(
                            children: additionalData
                                .map(_buildAdditionalDataCard)
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (attachedFiles.isNotEmpty)
                        _buildResourceSheetSection(
                          context,
                          title: 'Attached Files',
                          child: Column(
                            children: attachedFiles
                                .map(
                                  (file) => ListTile(
                                    leading: const Icon(
                                      Icons.insert_drive_file_outlined,
                                    ),
                                    title: Text(file),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
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

  Widget _buildResourceSheetSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildAdditionalDataCard(ProtocolAdditionalData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (data.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(data.description),
            ],
            if (data.link.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: data.link));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Link copied')));
                },
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.link,
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (data.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.photoPaths.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3 / 4,
                ),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: buildLocalImage(data.photoPaths[index]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<ProtocolTable> _unlinkedTables() {
    final linkedTableIds = protocol.steps
        .expand((step) => step.tableIds)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    return protocol.tables
        .where(
          (table) =>
              table.type != TableType.materialList &&
              !linkedTableIds.contains(table.id),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExitRun();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: ProtocolFlowAppBar(
          title: protocol.title,
          actions: [
            Center(
              child: Container(
                key: const Key('run-elapsed-time'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_elapsedTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _cancelProtocol,
              tooltip: 'Cancel Protocol',
            ),
          ],
        ),
        body: _buildRunBody(),
        bottomNavigationBar: _buildBottomCommandBar(),
      ),
    );
  }

  Widget _buildRunBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= ProtocolFlowBreakpoints.desktop;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            desktop ? 24 : 12,
            desktop ? 24 : 16,
            desktop ? 24 : 12,
            32,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProgressSurface(),
                  const SizedBox(height: 24),
                  _buildExecutionWorkspace(desktop: desktop),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExecutionWorkspace({required bool desktop}) {
    final mainContent = currentStepIndex == -1
        ? _buildMaterialsChecklist()
        : _buildStepExecution();
    final linkedTables = currentStepIndex < 0
        ? const <ProtocolTable>[]
        : _linkedTablesForStep(currentStep!);

    final contextSections = <Widget>[
      if (linkedTables.isNotEmpty) _buildLinkedTablesSurface(linkedTables),
      _buildRunNotesSurface(),
      _buildResourcesSurface(),
    ];

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          mainContent,
          for (final section in contextSections) ...[
            const SizedBox(height: 24),
            section,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: mainContent),
        const SizedBox(width: 32),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < contextSections.length; index++) ...[
                if (index > 0) const SizedBox(height: 24),
                contextSections[index],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSurface() {
    final totalSteps = steps.length;
    final currentNumber = currentStepIndex < 0 ? 0 : currentStepIndex + 1;
    final completedCount = activeProtocol?.completedStepIds.length ?? 0;
    final progress = totalSteps == 0
        ? 0.0
        : (currentNumber / totalSteps).clamp(0.0, 1.0);
    final step = currentStep;
    final stage = currentStepIndex < 0
        ? 'Preparation'
        : step?.phaseName?.isNotEmpty ?? false
        ? step!.phaseName!
        : 'Day ${step?.day ?? 1}';
    final stepLabel = currentStepIndex < 0
        ? 'Materials check'
        : 'Step $currentNumber of $totalSteps';

    return _buildSectionSurface(
      key: const Key('run-progress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stepLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$completedCount completed',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_phaseProgressEntries().isEmpty)
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: AppColors.surfaceContainer,
            )
          else
            _buildPhaseProgress(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Elapsed ${_formatDuration(_elapsedTime)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '$currentNumber / $totalSteps',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<({String name, List<int> indexes})> _phaseProgressEntries() {
    final groupedIndexes = <String, List<int>>{};
    for (var index = 0; index < steps.length; index++) {
      final phaseName = steps[index].phaseName?.trim();
      if (phaseName == null || phaseName.isEmpty) continue;
      groupedIndexes.putIfAbsent(phaseName, () => []).add(index);
    }
    return groupedIndexes.entries
        .map((entry) => (name: entry.key, indexes: entry.value))
        .toList();
  }

  Widget _buildPhaseProgress() {
    return PhaseSegmentedProgress(
      key: const Key('run-phase-progress'),
      steps: steps,
      currentStepIndex: currentStepIndex,
      completedStepIds: activeProtocol?.completedStepIds ?? const <String>{},
      segmentKeyPrefix: 'run-phase-progress',
    );
  }

  Widget _buildMaterialsChecklist() {
    return _buildSectionSurface(
      key: const Key('run-materials'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Material List'),
          const SizedBox(height: 6),
          const Text(
            'Ensure you have everything ready before starting.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (protocol.materialListTable == null)
            _buildEmptyState('No material list table linked.')
          else
            LinkedProtocolTablesSection(tables: [protocol.materialListTable!]),
        ],
      ),
    );
  }

  Widget _buildStepExecution() {
    final step = currentStep!;
    return _buildSectionSurface(
      key: const Key('run-current-step'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Current Step'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const Key('run-current-step-number'),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Text(
                  '${currentStepIndex + 1}',
                  style: const TextStyle(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (step.instructions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(step.instructions),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (step.actionItems.isNotEmpty) ...[
            const SizedBox(height: 18),
            ProtocolStepActionsTable(
              actions: step.actionItems,
              rowWrapperBuilder: (context, index, child) =>
                  _buildActionTimer(step, index, child),
            ),
          ],
          if (step.notes.isNotEmpty) ...[
            const SizedBox(height: 18),
            ProtocolStepNotesTable(notes: step.notes),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkedTablesSurface(List<ProtocolTable> tables) {
    return _buildSectionSurface(
      key: const Key('run-linked-tables'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.link, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Linked tables',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinkedProtocolTablesSection(tables: tables),
        ],
      ),
    );
  }

  Widget _buildRunNotesSurface() {
    final notes = _currentRunNotes();
    return _buildSectionSurface(
      key: const Key('run-notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buildSectionHeader('Run Notes')),
              IconButton(
                tooltip: 'Add note',
                onPressed: _addNote,
                icon: const Icon(Icons.note_add_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            _buildEmptyState('No notes recorded for this stage.')
          else
            _buildNotesList(showHeading: false),
        ],
      ),
    );
  }

  Widget _buildResourcesSurface() {
    final tableCount = _unlinkedTables().length;
    final additionalCount = protocol.additionalData.length;
    final fileCount = protocol.files.length;
    return _buildSectionSurface(
      key: const Key('run-resources'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Resources'),
          const SizedBox(height: 8),
          Text(
            '$tableCount tables, $additionalCount data items, $fileCount files',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openFiles,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open resources'),
            ),
          ),
        ],
      ),
    );
  }

  List<StepNote> _currentRunNotes() {
    final currentStepId = currentStepIndex >= 0
        ? steps[currentStepIndex].id
        : 'materials';
    return _notes.where((note) => note.stepId == currentStepId).toList();
  }

  Widget _buildSectionSurface({Key? key, required Widget child}) {
    final expanded = MediaQuery.sizeOf(context).width >= 1000;
    return Card(
      key: key,
      margin: EdgeInsets.zero,
      child: Padding(padding: EdgeInsets.all(expanded ? 24 : 16), child: child),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildBottomCommandBar() {
    final lastIndex = widget.finalStepIndex ?? steps.length - 1;
    final isLastStep = currentStepIndex == lastIndex;
    final primaryLabel = currentStepIndex < 0
        ? 'Start'
        : isLastStep
        ? 'Finish'
        : 'Next';
    final primaryIcon = isLastStep ? Icons.check : Icons.arrow_forward;

    return NavigationBar(
      key: const Key('run-navigation-bar'),
      height: 68,
      selectedIndex: 2,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            _goToPreviousStep();
            return;
          case 1:
            _addNote();
            return;
          case 2:
            _goToNextStep();
            return;
          case 3:
            _openFiles();
            return;
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.arrow_back_outlined),
          selectedIcon: Icon(Icons.arrow_back),
          label: 'Previous',
        ),
        const NavigationDestination(
          icon: Icon(Icons.note_add_outlined),
          selectedIcon: Icon(Icons.note_add),
          label: 'Note',
        ),
        NavigationDestination(
          key: const Key('run-primary-action'),
          icon: Icon(primaryIcon),
          selectedIcon: Icon(primaryIcon),
          label: primaryLabel,
        ),
        const NavigationDestination(
          icon: Icon(Icons.folder_open_outlined),
          selectedIcon: Icon(Icons.folder_open),
          label: 'Files',
        ),
      ],
    );
  }

  Widget _buildActionTimer(ProtocolStep step, int index, Widget child) {
    final int? actionTimer = step.actionTimers[index];
    if (actionTimer != null) {
      final timerKey = '${step.id}_$index';
      return ActionTimerWrapper(
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
              content: Text('Action "${step.actionItems[index]}" finished!'),
              duration: const Duration(seconds: 3),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: 'OK',
                textColor: AppColors.onPrimary,
                onPressed: () {},
              ),
            ),
          );
        },
        child: child,
      );
    }
    return child;
  }

  List<ProtocolTable> _linkedTablesForStep(ProtocolStep step) {
    final linkedTables = <ProtocolTable>[];
    for (final id in step.tableIds) {
      for (final table in protocol.tables) {
        if (table.id == id) {
          linkedTables.add(table);
          break;
        }
      }
    }
    return linkedTables;
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
