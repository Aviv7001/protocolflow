import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/protocol_step.dart';
import '../theme/app_colors.dart';

class PhaseSegmentedProgress extends StatefulWidget {
  const PhaseSegmentedProgress({
    super.key,
    required this.steps,
    required this.currentStepIndex,
    required this.completedStepIds,
    required this.segmentKeyPrefix,
    this.minimumSegmentWidth = 148,
    this.onAddPhase,
  });

  final List<ProtocolStep> steps;
  final int currentStepIndex;
  final Set<String> completedStepIds;
  final String segmentKeyPrefix;
  final double minimumSegmentWidth;
  final VoidCallback? onAddPhase;

  @override
  State<PhaseSegmentedProgress> createState() => _PhaseSegmentedProgressState();
}

class _PhaseSegmentedProgressState extends State<PhaseSegmentedProgress> {
  final ScrollController _scrollController = ScrollController();
  String? _lastCenterSignature;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<({String name, List<int> indexes})> _phases() {
    final groupedIndexes = <String, List<int>>{};
    for (var index = 0; index < widget.steps.length; index++) {
      final phaseName = widget.steps[index].phaseName?.trim();
      if (phaseName == null || phaseName.isEmpty) continue;
      groupedIndexes.putIfAbsent(phaseName, () => []).add(index);
    }
    return groupedIndexes.entries
        .map((entry) => (name: entry.key, indexes: entry.value))
        .toList();
  }

  void _centerActivePhase({
    required int activePhaseIndex,
    required double segmentWidth,
    required double viewportWidth,
    required int phaseCount,
  }) {
    final signature =
        '$activePhaseIndex/$segmentWidth/$viewportWidth/$phaseCount';
    if (_lastCenterSignature == signature) return;
    _lastCenterSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target =
          (activePhaseIndex * segmentWidth) +
          (segmentWidth / 2) -
          (viewportWidth / 2);
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final phases = _phases();
    if (phases.isEmpty && widget.onAddPhase == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final itemCount = phases.length + (widget.onAddPhase == null ? 0 : 1);
        final segmentWidth = math.max(
          widget.minimumSegmentWidth,
          phases.isEmpty
              ? widget.minimumSegmentWidth
              : viewportWidth / itemCount,
        );
        final contentWidth = segmentWidth * itemCount;
        final overflows = contentWidth > viewportWidth + 0.5;
        final activePhaseIndex = math.max(
          0,
          phases.indexWhere(
            (phase) => phase.indexes.contains(widget.currentStepIndex),
          ),
        );

        _centerActivePhase(
          activePhaseIndex: activePhaseIndex,
          segmentWidth: segmentWidth,
          viewportWidth: viewportWidth,
          phaseCount: itemCount,
        );

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: overflows,
          interactive: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(bottom: overflows ? 18 : 0),
            child: SizedBox(
              width: contentWidth,
              child: Row(
                children: [
                  ...phases.asMap().entries.map((entry) {
                    final phaseIndex = entry.key;
                    final phase = entry.value;
                    final reachedCount = widget.currentStepIndex < 0
                        ? 0
                        : phase.indexes
                              .where(
                                (index) => index <= widget.currentStepIndex,
                              )
                              .length;
                    final completedCount = phase.indexes
                        .where(
                          (index) => widget.completedStepIds.contains(
                            widget.steps[index].id,
                          ),
                        )
                        .length;
                    final phaseProgress = phase.indexes.isEmpty
                        ? 0.0
                        : (reachedCount / phase.indexes.length).clamp(0.0, 1.0);
                    final isComplete =
                        completedCount == phase.indexes.length ||
                        (phase.indexes.isNotEmpty &&
                            widget.currentStepIndex > phase.indexes.last);
                    final isActive = phase.indexes.contains(
                      widget.currentStepIndex,
                    );
                    final color = isComplete
                        ? AppColors.success
                        : isActive
                        ? AppColors.primary
                        : AppColors.textSecondary;

                    return SizedBox(
                      width: segmentWidth,
                      child: Container(
                        key: Key('${widget.segmentKeyPrefix}-$phaseIndex'),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: isActive || isComplete ? 0.08 : 0.04,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    phase.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isComplete)
                                  const Icon(
                                    Icons.check_circle,
                                    size: 15,
                                    color: AppColors.success,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: phaseProgress,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                              color: color,
                              backgroundColor: AppColors.surfaceContainer,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (widget.onAddPhase != null)
                    SizedBox(
                      width: segmentWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton.icon(
                          key: Key('${widget.segmentKeyPrefix}-add'),
                          onPressed: widget.onAddPhase,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Add phase'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(67),
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
