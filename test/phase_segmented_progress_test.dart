import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/widgets/phase_segmented_progress.dart';

void main() {
  testWidgets(
    'phase segments keep a minimum width and center the active phase',
    (tester) async {
      final steps = List.generate(
        5,
        (index) => ProtocolStep(
          id: 'step-$index',
          title: 'Step $index',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Phase ${index + 1}',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: PhaseSegmentedProgress(
                  key: const Key('phase-progress'),
                  steps: steps,
                  currentStepIndex: 3,
                  completedStepIds: const {'step-0', 'step-1', 'step-2'},
                  segmentKeyPrefix: 'phase-segment',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final firstSegment = find.byKey(const Key('phase-segment-0'));
      final activeSegment = find.byKey(const Key('phase-segment-3'));
      expect(tester.getSize(firstSegment).width, 148);
      expect(tester.getSize(activeSegment).width, 148);

      final scrollView = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byKey(const Key('phase-progress')),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scrollView.controller!.position.maxScrollExtent, greaterThan(0));
      expect(scrollView.controller!.offset, greaterThan(0));
      expect(scrollView.padding, const EdgeInsets.only(bottom: 18));
      expect(tester.getCenter(activeSegment).dx, closeTo(150, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('add phase action is rendered as a trailing segment', (
    tester,
  ) async {
    var addCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: PhaseSegmentedProgress(
              steps: const [],
              currentStepIndex: -1,
              completedStepIds: const {},
              segmentKeyPrefix: 'empty-phase-progress',
              onAddPhase: () => addCount++,
            ),
          ),
        ),
      ),
    );

    final addPhase = find.byKey(const Key('empty-phase-progress-add'));
    expect(addPhase, findsOneWidget);
    expect(tester.getSize(addPhase).width, 140);
    await tester.tap(addPhase);
    expect(addCount, 1);
  });
}
