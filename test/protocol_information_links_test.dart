import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/timeline/models/timeline_model.dart';
import 'package:protocolflow/features/timeline/widgets/timeline_preview.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/screens/protocol_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Protocol Information displays its linked timeline figure', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final timeline = ExperimentTimeline(
      title: 'Study timeline',
      events: List.generate(
        12,
        (index) => TimelineEvent(
          id: 'event-$index',
          name: 'Event $index',
          selectedTimePoints: const [0, 2, 4],
        ),
      ),
    ).toProtocolTable(id: 'timeline-info');
    final protocol = Protocol(
      id: 'protocol-info-preview',
      title: 'Information preview',
      objective: '',
      description: '',
      steps: const [],
      tables: [timeline],
      informationTableIds: const ['timeline-info'],
    );

    await tester.pumpWidget(
      MaterialApp(home: ProtocolDetailScreen(protocol: protocol)),
    );
    await tester.pumpAndSettle();

    final information = find.byKey(const Key('detail-protocol-information'));
    expect(
      find.descendant(of: information, matching: find.text('Linked tables')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: information, matching: find.byType(TimelinePreview)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: information,
        matching: find.byKey(const ValueKey('timeline-vertical-scroll')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: information,
        matching: find.byKey(const ValueKey('timeline-horizontal-scroll')),
      ),
      findsOneWidget,
    );
    final previewFinder = find.descendant(
      of: information,
      matching: find.byType(TimelinePreview),
    );
    final canvasFinder = find.descendant(
      of: information,
      matching: find.byKey(const ValueKey('timeline-canvas')),
    );
    expect(tester.widget<TimelinePreview>(previewFinder).fitToWidth, isTrue);
    expect(
      tester.getSize(canvasFinder).width,
      lessThanOrEqualTo(tester.getSize(previewFinder).width + 0.1),
    );
    expect(tester.takeException(), isNull);
  });
}
