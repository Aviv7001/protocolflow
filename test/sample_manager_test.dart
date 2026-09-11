import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/plate_wizard/models/plate_wizard_models.dart';
import 'package:protocolflow/features/plate_wizard/services/sample_layout_service.dart';
import 'package:protocolflow/models/plate_wizard.dart';
import 'package:protocolflow/screens/plate_wizard_samples_screen.dart';

void main() {
  test('auto directions resolve each sample dimension to fit the plate', () {
    final result = const SampleLayoutService().generate(
      const PlateWizardInput(
        plateRows: 2,
        plateCols: 6,
        samples: [
          SampleSpec(
            name: 'Auto',
            variables: [
              SampleVariableSpec(
                name: 'Dose',
                values: ['Low', 'High'],
                direction: Direction.auto,
              ),
            ],
            duplicates: 3,
          ),
        ],
      ),
    );

    expect(result.success, isTrue);
    expect(
      result.plates!.single.expand((row) => row).whereType<WellContent>(),
      hasLength(6),
    );
  });

  test(
    'new samples start without variables and round trip custom settings',
    () {
      final item = TestItem(
        id: 'sample-a',
        sampleName: 'Sample A',
        variables: const [
          SampleVariable(
            name: 'Dose',
            values: ['Low', 'High'],
            direction: Direction.vertical,
          ),
        ],
        duplicates: 3,
        sampleDirection: Direction.vertical,
        duplicateDirection: Direction.horizontal,
        colorHex: '#C8E6C9',
        manualWells: const [
          PlateWellPosition(plateIndex: 0, row: 0, column: 0),
        ],
      );

      expect(TestItem().variables, isEmpty);
      expect(TestItem().sampleDirection, Direction.auto);
      expect(TestItem().duplicateDirection, Direction.auto);
      expect(const SampleVariable(name: 'New').direction, Direction.auto);
      final restored = TestItem.fromJson(item.toJson());
      expect(restored.id, 'sample-a');
      expect(restored.variables.single.name, 'Dose');
      expect(restored.variables.single.values, ['Low', 'High']);
      expect(restored.variables.single.direction, Direction.vertical);
      expect(restored.duplicates, 3);
      expect(restored.sampleDirection, Direction.vertical);
      expect(restored.colorHex, '#C8E6C9');
      expect(restored.manualWells.single.key, '0:0:0');
    },
  );

  test('legacy conditions and dilutions migrate to custom variables', () {
    final wizard = PlateLayoutWizard.fromJson({
      'conditionDirection': 'vertical',
      'dilutionDirection': 'horizontal',
      'items': [
        {
          'sampleName': 'Legacy',
          'conditions': ['Control', 'Drug'],
          'dilutions': ['1:10', '1:100'],
          'duplicates': 2,
        },
      ],
    });

    expect(wizard.items.single.variables.map((item) => item.name), [
      'Conditions',
      'Dilutions',
    ]);
    expect(wizard.items.single.variables.first.direction, Direction.vertical);
    expect(wizard.items.single.variables.last.direction, Direction.horizontal);
  });

  test('manual fit can split a sample across multiple plates', () {
    final positions = [
      for (var plate = 0; plate < 2; plate++)
        for (var row = 0; row < 2; row++)
          for (var column = 0; column < 2; column++)
            PlateWellPosition(plateIndex: plate, row: row, column: column),
    ];
    final oversized = TestItem(
      sampleName: 'Wide sample',
      variables: const [
        SampleVariable(name: 'Dose', values: ['1', '2', '3', '4']),
      ],
      duplicates: 2,
    );
    final automatic = PlateLayoutWizard(
      rows: 2,
      columns: 2,
      plateCount: 2,
      items: [oversized],
    ).generateTables();
    expect(automatic.first.metadata['layoutError'], contains('Could not fit'));

    final manual = PlateLayoutWizard(
      rows: 2,
      columns: 2,
      plateCount: 2,
      items: [oversized.copyWith(manualWells: positions)],
    ).generateTables();
    expect(manual.first.metadata['layoutError'], isNull);
    expect(
      manual
          .expand((table) => table.data)
          .expand((row) => row)
          .where((cell) => cell.toString().isNotEmpty),
      hasLength(8),
    );
  });

  testWidgets('sample cards support collapse, ordering, and variables', (
    tester,
  ) async {
    PlateLayoutWizard? saved;
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(
            items: [
              TestItem(id: 'a', sampleName: 'A'),
              TestItem(id: 'b', sampleName: 'B'),
            ],
          ),
          onUpdate: (wizard) => saved = wizard,
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Layout Directions'), findsNothing);
    expect(find.byKey(const Key('sample-cards-toggle-all')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sample-add-variable-a')));
    await tester.pump();
    expect(find.byKey(const Key('sample-variable-a-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sample-menu-a')));
    await tester.pumpAndSettle();
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Move up'), findsOneWidget);
    expect(find.text('Move down'), findsOneWidget);
    expect(find.text('Choose wells'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sample-move-down-a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sample-cards-toggle-all')));
    await tester.pump();
    expect(find.byTooltip('Expand sample'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Save table'));
    await tester.pump();
    expect(saved, isNotNull);
    expect(saved!.items.map((item) => item.sampleName), ['B', 'A']);
    expect(saved!.items.last.variables.single.name, 'Variable 1');
  });

  testWidgets('only variables retain drag-and-drop reordering', (tester) async {
    PlateLayoutWizard? saved;
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(
            items: [
              TestItem(
                id: 'drag-a',
                sampleName: 'A',
                variables: const [
                  SampleVariable(name: 'First'),
                  SampleVariable(name: 'Second'),
                ],
              ),
              TestItem(id: 'drag-b', sampleName: 'B'),
            ],
          ),
          onUpdate: (wizard) => saved = wizard,
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Drag to reorder sample'), findsNothing);
    expect(find.byKey(const Key('sample-card-list')), findsOneWidget);
    final firstHandle = find.byKey(const Key('sample-variable-drag-drag-a-0'));
    final secondHandle = find.byKey(const Key('sample-variable-drag-drag-a-1'));
    final dragDistance =
        tester.getCenter(secondHandle).dy -
        tester.getCenter(firstHandle).dy +
        24;
    await tester.timedDrag(
      firstHandle,
      Offset(0, dragDistance),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save table'));
    await tester.pump();
    expect(saved, isNotNull);
    expect(saved!.items.map((item) => item.sampleName), ['A', 'B']);
    expect(saved!.items.first.variables.map((variable) => variable.name), [
      'Second',
      'First',
    ]);
  });

  testWidgets('manual fit reports required, assigned, and remaining cells', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(
            rows: 2,
            columns: 2,
            items: [
              TestItem(id: 'manual', sampleName: 'Manual', duplicates: 2),
            ],
          ),
          onUpdate: (_) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sample-menu-manual')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sample-manual-fit-manual')));
    await tester.pump();
    expect(find.textContaining('2 wells needed'), findsOneWidget);
    expect(find.textContaining('0 selected, 2 left'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manual-well-0-0-0')));
    await tester.pump();
    expect(find.textContaining('1 selected, 1 left'), findsOneWidget);
    expect(find.byKey(const Key('sample-layout-error')), findsOneWidget);
  });

  testWidgets('choose wells protects other samples and applies atomically', (
    tester,
  ) async {
    PlateLayoutWizard? saved;
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(
            rows: 2,
            columns: 4,
            items: [
              TestItem(id: 'a', sampleName: 'A', duplicates: 2),
              TestItem(id: 'b', sampleName: 'B', duplicates: 2),
            ],
          ),
          onUpdate: (wizard) => saved = wizard,
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sample-menu-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sample-manual-fit-a')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('manual-well-0-0-2')));
    await tester.pump();
    expect(find.textContaining('Reserved by B'), findsOneWidget);
    expect(find.textContaining('0 selected, 2 left'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manual-well-0-0-0')));
    await tester.tap(find.byKey(const Key('manual-well-0-0-1')));
    await tester.pump();
    expect(find.byKey(const Key('sample-choose-wells-apply')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sample-choose-wells-apply')));
    await tester.pump();
    expect(find.byKey(const Key('manual-fit-status')), findsNothing);

    await tester.tap(find.byTooltip('Save table'));
    await tester.pump();
    expect(saved!.items.first.manualWells.map((well) => well.key), [
      '0:0:0',
      '0:0:1',
    ]);
  });

  testWidgets('sample cards remain usable without overflow on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(
            items: [
              TestItem(
                id: 'narrow',
                sampleName: 'Narrow sample',
                variables: const [
                  SampleVariable(name: 'Treatment', values: ['A', 'B']),
                ],
              ),
            ],
          ),
          onUpdate: (_) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sample-card-narrow')), findsOneWidget);
    expect(find.byKey(const Key('sample-add-variable-narrow')), findsOneWidget);
    final cardRect = tester.getRect(
      find.byKey(const Key('sample-card-narrow')),
    );
    final menuRect = tester.getRect(
      find.byKey(const Key('sample-menu-narrow')),
    );
    final layoutDirectionRect = tester.getRect(
      find.byKey(const Key('direction-layout-narrow')),
    );
    final variableNameRect = tester.getRect(
      find.byKey(const Key('sample-variable-name-narrow-0')),
    );
    final variableDirectionRect = tester.getRect(
      find.byKey(const Key('direction-variable-narrow-0')),
    );
    expect(find.text('Live arrangement preview'), findsNothing);
    expect(find.byTooltip('Across'), findsWidgets);
    expect(find.byTooltip('Down'), findsWidgets);
    expect(cardRect.left, greaterThanOrEqualTo(0));
    expect(cardRect.right, lessThanOrEqualTo(390));
    expect(menuRect.right, lessThanOrEqualTo(cardRect.right));
    expect(layoutDirectionRect.right, lessThanOrEqualTo(cardRect.right));
    expect(variableDirectionRect.right, lessThanOrEqualTo(cardRect.right));
    expect(
      (variableNameRect.center.dy - variableDirectionRect.center.dy).abs(),
      lessThan(20),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto-fit all balances variable and replicate directions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(
            rows: 2,
            columns: 4,
            items: [
              TestItem(
                id: 'auto',
                sampleName: 'Auto',
                duplicates: 2,
                variables: const [
                  SampleVariable(
                    name: 'Dose',
                    values: ['1', '2', '3', '4'],
                    direction: Direction.vertical,
                  ),
                ],
                duplicateDirection: Direction.vertical,
              ),
            ],
          ),
          onUpdate: (_) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sample-layout-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sample-auto-fit-all')));
    await tester.pump();
    expect(find.byKey(const Key('sample-layout-error')), findsNothing);
  });
}
