import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/models/active_protocol.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/screens/run_protocol_screen.dart';
import 'package:protocolflow/screens/home_screen.dart';
import 'package:protocolflow/screens/library_screen.dart';
import 'package:protocolflow/widgets/protocolflow_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('files action shows unlinked protocol tables', (tester) async {
    SharedPreferences.setMockInitialValues({});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];

    final linkedTable = ProtocolTable(
      id: 'linked-table',
      title: 'Step Dilution Table',
      columnHeaders: const ['Sample', 'Dilution'],
      rowHeaders: const ['1'],
      data: const [
        ['A1', '1:10'],
      ],
    );
    final unlinkedTable = ProtocolTable(
      id: 'unlinked-table',
      title: 'Reference Plate Map',
      columnHeaders: const ['Well', 'Sample'],
      rowHeaders: const ['1'],
      data: const [
        ['A1', 'Control'],
      ],
    );
    final materialList = createMaterialListTable(
      id: 'materials',
      data: const [
        ['PBS', '10 mL', '', '', ''],
      ],
    );
    final protocol = Protocol(
      id: 'protocol-1',
      title: 'Reference table protocol',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'step-1',
          title: 'Prepare samples',
          instructions: 'Prepare samples.',
          actionItems: [],
          materials: [],
          tableIds: ['linked-table'],
        ),
      ],
      materialListTableId: 'materials',
      tables: [linkedTable, unlinkedTable, materialList],
      files: const ['safety-notes.pdf'],
      additionalData: [
        ProtocolAdditionalData(
          id: 'data-1',
          title: 'Antibody Datasheet',
          description: 'Vendor instructions.',
          link: 'https://example.com/datasheet',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunProtocolScreen(protocol: protocol, initialStepIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Files'));
    await tester.pumpAndSettle();

    final sheet = find.byType(DraggableScrollableSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Reference Tables')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Additional Data')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Reference Plate Map')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Control')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Antibody Datasheet')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Step Dilution Table')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Material List')),
      findsNothing,
    );

    final resourceList = find.descendant(
      of: sheet,
      matching: find.byType(ListView),
    );
    await tester.drag(resourceList.first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sheet, matching: find.text('Attached Files')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('safety-notes.pdf')),
      findsOneWidget,
    );
  });

  testWidgets('run protocol uses responsive execution workspace', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];
    addTearDown(() {
      activeProtocol = null;
      runningProtocols = [];
      completedProtocols = [];
    });

    final linkedTable = ProtocolTable(
      id: 'run-linked-table',
      title: 'Run Plate',
      type: TableType.plateLayout,
    );
    final protocol = Protocol(
      id: 'run-layout-protocol',
      title: 'Responsive Run',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'run-step-1',
          title: 'Prepare plate',
          instructions: 'Add samples to the plate.',
          actionItems: const ['Add samples'],
          materials: const [],
          tableIds: const ['run-linked-table'],
          phaseName: 'Preparation',
        ),
        ProtocolStep(
          id: 'run-step-2',
          title: 'Read plate',
          instructions: 'Measure absorbance.',
          actionItems: const [],
          materials: const [],
          phaseName: 'Measurement',
        ),
      ],
      tables: [linkedTable],
      additionalData: [
        ProtocolAdditionalData(id: 'run-reference', title: 'Run reference'),
      ],
    );

    Future<void> pumpAtSize(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: RunProtocolScreen(protocol: protocol, initialStepIndex: 0),
        ),
      );
      await tester.pump();
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAtSize(const Size(1400, 1400));

    final progress = find.byKey(const Key('run-progress'));
    final currentStep = find.byKey(const Key('run-current-step'));
    final linkedTables = find.byKey(const Key('run-linked-tables'));
    final notes = find.byKey(const Key('run-notes'));
    final resources = find.byKey(const Key('run-resources'));

    expect(find.byType(ProtocolFlowAppBar), findsOneWidget);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    final navigationBar = tester.widget<NavigationBar>(
      find.byKey(const Key('run-navigation-bar')),
    );
    expect(find.byKey(const Key('floating-run-navigation')), findsOneWidget);
    expect(navigationBar.height, 68);
    expect(navigationBar.selectedIndex, 2);
    expect(
      navigationBar.destinations
          .map((destination) => (destination as NavigationDestination).label)
          .toList(),
      ['Previous', 'Note', 'Next', 'Files'],
    );
    expect(find.byKey(const Key('run-phase-progress')), findsOneWidget);
    final firstPhase = find.byKey(const Key('run-phase-progress-0'));
    final secondPhase = find.byKey(const Key('run-phase-progress-1'));
    expect(tester.getTopLeft(firstPhase).dy, tester.getTopLeft(secondPhase).dy);
    expect(tester.getSize(firstPhase).width, tester.getSize(secondPhase).width);
    expect(
      tester.getRect(currentStep).right,
      lessThan(tester.getRect(linkedTables).left),
    );
    expect(
      tester.getTopLeft(notes).dy,
      greaterThan(tester.getTopLeft(linkedTables).dy),
    );
    expect(
      tester.getTopLeft(resources).dy,
      greaterThan(tester.getTopLeft(notes).dy),
    );
    expect(
      tester.getSize(progress).width,
      greaterThan(tester.getSize(currentStep).width),
    );

    await pumpAtSize(const Size(390, 1600));
    expect(find.byKey(const Key('floating-run-navigation')), findsNothing);
    final mobileOrder = [
      progress,
      currentStep,
      linkedTables,
      notes,
      resources,
    ].map((finder) => tester.getTopLeft(finder).dy).toList();
    expect(mobileOrder, orderedEquals([...mobileOrder]..sort()));
    expect(find.byKey(const Key('run-current-step-number')), findsOneWidget);
    expect(find.byKey(const Key('run-primary-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completing a protocol returns to the Home library shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];
    addTearDown(() {
      activeProtocol = null;
      runningProtocols = [];
      completedProtocols = [];
    });

    final protocol = Protocol(
      id: 'completion-route-protocol',
      title: 'Completion Route',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'completion-step',
          title: 'Finish run',
          instructions: 'Complete the run.',
          actionItems: const [],
          materials: const [],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RunProtocolScreen(protocol: protocol, initialStepIndex: 0),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('run-primary-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Complete Protocol'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ProtocolFlowAppBar), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching runs parks one session and restores another', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];
    addTearDown(() {
      activeProtocol = null;
      runningProtocols = [];
      completedProtocols = [];
    });

    Protocol protocol(String id, String stepId) => Protocol(
      id: id,
      title: 'Protocol $id',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: stepId,
          title: 'Run $id',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Phase 1',
        ),
      ],
    );

    final protocolA = protocol('a', 'step-a');
    final protocolB = protocol('b', 'step-b');
    final startedAt = DateTime(2026, 7, 30, 9);
    activeProtocol = ActiveProtocol(
      protocol: protocolA,
      currentStepIndex: 0,
      notes: [
        StepNote(
          id: 'note-a',
          stepId: 'step-a',
          note: 'Keep this note',
          createdAt: startedAt,
        ),
      ],
      startedAt: startedAt,
      timerStartTimes: {'step-a': startedAt},
      pausedSeconds: const {'step-a': 45},
      completedStepIds: const {'step-a'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RunProtocolScreen(
          key: const ValueKey('run-b'),
          protocol: protocolB,
        ),
      ),
    );
    await tester.pump();

    expect(activeProtocol!.protocol.id, 'b');
    expect(activeProtocol!.protocol.syncStatus, ProtocolSyncStatus.modified);
    expect(activeProtocol!.currentStepIndex, -1);
    expect(activeProtocol!.notes, isEmpty);
    expect(activeProtocol!.completedStepIds, isEmpty);
    expect(activeProtocol!.timerStartTimes, isEmpty);
    expect(activeProtocol!.pausedSeconds, isEmpty);
    expect(runningProtocols.map((state) => state.protocol.id), ['a']);
    expect(runningProtocols.single.currentStepIndex, 0);
    expect(runningProtocols.single.notes.single.note, 'Keep this note');
    expect(runningProtocols.single.completedStepIds, {'step-a'});
    expect(runningProtocols.single.pausedSeconds, {'step-a': 45});

    await tester.pumpWidget(
      MaterialApp(
        home: RunProtocolScreen(
          key: const ValueKey('run-a'),
          protocol: protocolA,
        ),
      ),
    );
    await tester.pump();

    expect(activeProtocol!.protocol.id, 'a');
    expect(activeProtocol!.currentStepIndex, 0);
    expect(activeProtocol!.notes.single.note, 'Keep this note');
    expect(activeProtocol!.completedStepIds, {'step-a'});
    expect(activeProtocol!.pausedSeconds, {'step-a': 45});
    expect(runningProtocols.map((state) => state.protocol.id), ['b']);
    expect(runningProtocols.single.completedStepIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a run can pause it midway and return', (tester) async {
    SharedPreferences.setMockInitialValues({});
    activeProtocol = null;
    runningProtocols = [];
    completedProtocols = [];
    addTearDown(() {
      activeProtocol = null;
      runningProtocols = [];
      completedProtocols = [];
    });

    final protocol = Protocol(
      id: 'pause-mid-phase',
      title: 'Pause Mid Phase',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'pause-step-1',
          title: 'Incubate',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Incubation',
        ),
        ProtocolStep(
          id: 'pause-step-2',
          title: 'Wash',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Incubation',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const Key('open-run'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RunProtocolScreen(
                    protocol: protocol,
                    initialStepIndex: 0,
                  ),
                ),
              ),
              child: const Text('Open run'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-run')));
    await tester.pumpAndSettle();
    expect(activeProtocol?.protocol.id, protocol.id);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave protocol run?'), findsOneWidget);

    await tester.tap(find.text('Pause run'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('No protocols currently running.'), findsNothing);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller?.index, 2);
    expect(activeProtocol, isNull);
    expect(runningProtocols, hasLength(1));
    expect(runningProtocols.single.protocol.id, protocol.id);
    expect(
      runningProtocols.single.protocol.syncStatus,
      ProtocolSyncStatus.modified,
    );
    expect(runningProtocols.single.currentStepIndex, 0);
    expect(tester.takeException(), isNull);
  });
}
