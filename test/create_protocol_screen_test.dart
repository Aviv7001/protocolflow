import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/screens/create_protocol_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('protocol builder keeps the mobile workflow order', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: CreateProtocolScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Protocol Builder'), findsOneWidget);
    expect(find.text('NEW PROTOCOL'), findsOneWidget);
    expect(find.byTooltip('Save protocol'), findsOneWidget);

    final sections = [
      const Key('builder-protocol-information'),
      const Key('builder-samples'),
      const Key('builder-materials'),
      const Key('builder-steps'),
      const Key('builder-tables'),
      const Key('builder-additional-data'),
    ];
    final topPositions = sections
        .map((key) => tester.getTopLeft(find.byKey(key)).dy)
        .toList();
    for (var index = 1; index < topPositions.length; index++) {
      expect(topPositions[index], greaterThan(topPositions[index - 1]));
    }
    for (final key in const [
      Key('builder-materials'),
      Key('builder-tables'),
      Key('builder-additional-data'),
    ]) {
      expect(tester.widget(find.byKey(key)), isA<Card>());
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('protocol builder uses the requested desktop columns', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: CreateProtocolScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    final information = tester.getTopLeft(
      find.byKey(const Key('builder-protocol-information')),
    );
    final tables = tester.getTopLeft(find.byKey(const Key('builder-tables')));
    final additional = tester.getTopLeft(
      find.byKey(const Key('builder-additional-data')),
    );
    final samples = tester.getTopLeft(find.byKey(const Key('builder-samples')));
    final materials = tester.getTopLeft(
      find.byKey(const Key('builder-materials')),
    );
    final steps = tester.getTopLeft(find.byKey(const Key('builder-steps')));

    expect(tables.dx, information.dx);
    expect(additional.dx, information.dx);
    expect(samples.dx, greaterThan(information.dx));
    expect(materials.dx, samples.dx);
    expect(steps.dx, samples.dx);
    expect(tables.dy, greaterThan(information.dy));
    expect(additional.dy, greaterThan(tables.dy));
    expect(materials.dy, greaterThan(samples.dy));
    expect(steps.dy, greaterThan(materials.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('steps use an external numbered timeline inside a section card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: CreateProtocolScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    final stepsSection = find.byKey(const Key('builder-steps'));
    expect(tester.widget(stepsSection), isA<Card>());

    var addStep = find.widgetWithText(FilledButton, 'Add Step');
    await tester.ensureVisible(addStep);
    await tester.tap(addStep);
    await tester.pump();

    addStep = find.widgetWithText(FilledButton, 'Add Step');
    await tester.ensureVisible(addStep);
    await tester.tap(addStep);
    await tester.pump();

    for (var number = 1; number <= 2; number++) {
      final marker = find.byKey(Key('step-number-$number'));
      final card = find.byKey(Key('step-card-$number'));
      expect(marker, findsOneWidget);
      expect(card, findsOneWidget);
      expect(tester.getRect(marker).right, lessThan(tester.getRect(card).left));
      expect(find.byKey(Key('step-connector-$number')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('step table menu links and unlinks tables without crashing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final protocol = Protocol(
      id: 'protocol-1',
      title: 'Table linking',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'step-1',
          title: 'Prepare plate',
          instructions: '',
          actionItems: const [],
          materials: const [],
        ),
      ],
      tables: [
        ProtocolTable(
          id: 'table-plate',
          title: 'Plate Layout',
          type: TableType.plateLayout,
        ),
        ProtocolTable(
          id: 'table-mix',
          title: 'Master Mix',
          type: TableType.masterMix,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateProtocolScreen(initialProtocol: protocol)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final linkButton = find.byTooltip('Link tables to step 1');
    expect(find.text('Linked Tables'), findsNothing);
    expect(find.text('Link table'), findsOneWidget);
    await tester.ensureVisible(linkButton);
    await tester.tap(linkButton);
    await tester.pumpAndSettle();

    Finder plateMenuItem() => find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuItem<String> && widget.value == 'table-plate',
    );

    expect(plateMenuItem(), findsOneWidget);
    final plateIcon = tester.widget<Icon>(
      find.descendant(
        of: plateMenuItem(),
        matching: find.byIcon(Icons.grid_on),
      ),
    );
    expect(plateIcon.color, Colors.orange);

    await tester.tap(plateMenuItem());
    await tester.pumpAndSettle();

    const linkedTableKey = Key('linked-table-step-1-table-plate');
    expect(find.byKey(linkedTableKey), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('step-title-instructions-gap-1')))
          .height,
      12,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('step-linked-tables-bottom-gap-1')))
          .height,
      12,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(linkButton);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: plateMenuItem(), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

    await tester.tap(plateMenuItem());
    await tester.pumpAndSettle();
    expect(find.byKey(linkedTableKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('step link menu stays available when there are no tables', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: CreateProtocolScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    final addStep = find.widgetWithText(FilledButton, 'Add Step');
    await tester.ensureVisible(addStep);
    await tester.tap(addStep);
    await tester.pump();

    final linkButton = find.byTooltip('Link tables to step 1');
    expect(linkButton, findsOneWidget);
    await tester.ensureVisible(linkButton);
    await tester.tap(linkButton);
    await tester.pumpAndSettle();

    expect(find.text('No tables available'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuItem<String> && widget.value == '__add_table__',
      ),
      findsOneWidget,
    );
    expect(find.text('Add table'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructions grow and extract bullet-only actions and notes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final protocol = Protocol(
      id: 'protocol-instructions',
      title: 'Instructions',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'step-instructions',
          title: 'Prepare sample',
          instructions: '',
          actionItems: const [],
          materials: const [],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateProtocolScreen(initialProtocol: protocol)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    Finder instructionsEditable() => find.descendant(
      of: find.byKey(const Key('step-instructions-field-1')),
      matching: find.byType(EditableText),
    );

    await tester.ensureVisible(instructionsEditable());
    final longInstructions = List.generate(
      24,
      (index) => 'Instruction line ${index + 1}',
    ).join('\n');
    await tester.enterText(instructionsEditable(), longInstructions);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.enterText(
      instructionsEditable(),
      '- Mix reagent\n* Keep on ice',
    );
    await tester.pump(const Duration(milliseconds: 600));

    var instructionsText = tester
        .widget<EditableText>(instructionsEditable())
        .controller
        .text;
    expect(instructionsText, '- Mix reagent\n* Keep on ice');
    expect(find.text('Mix reagent'), findsNothing);
    expect(find.text('Keep on ice'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('step-title-field-1')));
    await tester.tap(find.byKey(const Key('step-title-field-1')));
    await tester.pumpAndSettle();

    instructionsText = tester
        .widget<EditableText>(instructionsEditable())
        .controller
        .text;
    expect(instructionsText, isEmpty);
    expect(find.text('Mix reagent'), findsOneWidget);
    expect(find.text('Keep on ice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabling phases clears them from the saved protocol', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final initialProtocol = Protocol(
      id: 'phase-removal-protocol',
      title: 'Phase removal',
      objective: '',
      description: '',
      steps: [
        ProtocolStep(
          id: 'phase-step-1',
          title: 'Prepare',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Preparation',
        ),
        ProtocolStep(
          id: 'phase-step-2',
          title: 'Measure',
          instructions: '',
          actionItems: const [],
          materials: const [],
          phaseName: 'Measurement',
        ),
      ],
    );
    Protocol? savedProtocol;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open-phase-editor'),
            onPressed: () async {
              savedProtocol = await Navigator.push<Protocol>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateProtocolScreen(initialProtocol: initialProtocol),
                ),
              );
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-phase-editor')));
    await tester.pumpAndSettle();

    final phaseSwitch = find.byType(Switch);
    expect(tester.widget<Switch>(phaseSwitch).value, isTrue);
    await tester.ensureVisible(phaseSwitch);
    await tester.tap(phaseSwitch);
    await tester.pump();
    expect(tester.widget<Switch>(phaseSwitch).value, isFalse);

    await tester.tap(find.byTooltip('Save protocol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Protocol'));
    await tester.pumpAndSettle();

    expect(savedProtocol, isNotNull);
    expect(
      savedProtocol!.steps.every((step) => step.phaseName == null),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phase controls adjust boundaries without reordering steps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    ProtocolStep step(String id, String title, String phase) => ProtocolStep(
      id: id,
      title: title,
      instructions: '',
      actionItems: const [],
      materials: const [],
      phaseName: phase,
    );

    final initialProtocol = Protocol(
      id: 'phase-controls-protocol',
      title: 'Phase controls',
      objective: '',
      description: '',
      steps: [
        step('step-a', 'Step A', 'Phase 1'),
        step('step-b', 'Step B', 'Phase 1'),
        step('step-c', 'Step C', 'Phase 1'),
        step('step-d', 'Step D', 'Phase 1'),
        step('step-e', 'Step E', 'Phase 2'),
        step('step-f', 'Step F', 'Phase 2'),
      ],
    );
    Protocol? savedProtocol;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open-phase-controls'),
            onPressed: () async {
              savedProtocol = await Navigator.push<Protocol>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateProtocolScreen(initialProtocol: initialProtocol),
                ),
              );
            },
            child: const Text('Open phase controls'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-phase-controls')));
    await tester.pumpAndSettle();

    final insertPhase = find.byKey(const Key('insert-phase-after-2'));
    expect(insertPhase, findsOneWidget);
    await tester.ensureVisible(insertPhase);
    await tester.tap(insertPhase);
    await tester.pump();

    expect(find.text('Phase 1'), findsOneWidget);
    expect(find.text('Phase 2'), findsOneWidget);
    expect(find.text('Phase 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('phase-menu-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move phase up'));
    await tester.pumpAndSettle();

    final orderedTitles = [
      'Step A',
      'Step B',
      'Step C',
      'Step D',
      'Step E',
      'Step F',
    ].map((title) => tester.getTopLeft(find.text(title)).dy).toList();
    expect(orderedTitles, orderedEquals([...orderedTitles]..sort()));

    final movedPhaseMenu = find.byKey(const Key('phase-menu-2'));
    await tester.ensureVisible(movedPhaseMenu);
    await tester.tap(movedPhaseMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move phase down'));
    await tester.pumpAndSettle();

    final orderAfterBothMoves = [
      'Step A',
      'Step B',
      'Step C',
      'Step D',
      'Step E',
      'Step F',
    ].map((title) => tester.getTopLeft(find.text(title)).dy).toList();
    expect(
      orderAfterBothMoves,
      orderedEquals([...orderAfterBothMoves]..sort()),
    );

    final phaseToDeleteMenu = find.byKey(const Key('phase-menu-3'));
    await tester.ensureVisible(phaseToDeleteMenu);
    await tester.tap(phaseToDeleteMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete phase'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete phase'));
    await tester.pumpAndSettle();

    expect(find.text('Phase 3'), findsNothing);

    await tester.tap(find.byTooltip('Save protocol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Protocol'));
    await tester.pumpAndSettle();

    expect(savedProtocol, isNotNull);
    expect(savedProtocol!.steps.map((step) => step.id).toList(), [
      'step-a',
      'step-b',
      'step-c',
      'step-d',
      'step-e',
      'step-f',
    ]);
    expect(savedProtocol!.steps.map((step) => step.phaseName).toList(), [
      'Phase 1',
      'Phase 1',
      'Phase 1',
      'Phase 1',
      'Phase 2',
      'Phase 2',
    ]);
    expect(tester.takeException(), isNull);
  });
}
