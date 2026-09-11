import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/lab_math/lab_calculation.dart';
import 'package:protocolflow/features/master_mix/screens/master_mix_manager_screen.dart';
import 'package:protocolflow/features/master_mix/services/master_mix_calculator_service.dart';
import 'package:protocolflow/features/master_mix/widgets/master_mix_result_table.dart';
import 'package:protocolflow/models/master_mix_wizard.dart';
import 'package:protocolflow/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('solid stock shows molar mass and whole mix rows are banded', (
    tester,
  ) async {
    final wizard = MasterMixWizard(
      mixes: [
        MasterMixItem(
          mixName: 'Mix A',
          finalVolume: 1,
          finalVolumeUnit: VolumeUnit.mL,
          extraVolumePercent: 0,
          reagents: [
            MasterMixReagentItem(
              sourceType: ReagentSourceType.solidMaterial,
              name: 'Compound A',
              finalConc: 1,
              finalUnit: ConcentrationUnit.mgML,
              mw: 180.16,
            ),
          ],
        ),
        MasterMixItem(
          mixName: 'Mix B',
          finalVolume: 1,
          finalVolumeUnit: VolumeUnit.mL,
          extraVolumePercent: 0,
          reagents: [
            MasterMixReagentItem(
              sourceType: ReagentSourceType.solidMaterial,
              name: 'Compound B',
              finalConc: 2,
              finalUnit: ConcentrationUnit.mgML,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MasterMixResultTable(
            wizard: wizard,
            calculator: MasterMixCalculatorService(),
            showExportActions: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('180.16 g/mol'), findsOneWidget);
    expect(find.text('Solid material'), findsOneWidget);

    final table = tester.widget<DataTable>(find.byType(DataTable));
    for (final row in table.rows.take(3)) {
      expect(row.color, isNull);
    }
    for (final row in table.rows.skip(3).take(3)) {
      expect(row.color!.resolve(<WidgetState>{}), AppColors.surfaceContainer);
    }

    final exportedTable = wizard.generateTable();
    expect(
      exportedTable.cellColors.take(3).expand((row) => row),
      everyElement(''),
    );
    expect(
      exportedTable.cellColors.skip(3).take(3).expand((row) => row),
      everyElement('EEF4F5'),
    );
  });

  testWidgets('wide manager scrolls columns separately and moves mixes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MasterMixManagerScreen(
          wizard: MasterMixWizard(
            mixes: [
              MasterMixItem(mixName: 'Mix A'),
              MasterMixItem(mixName: 'Mix B'),
            ],
          ),
          onUpdate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('controls-column-scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preview-column-scroll')), findsOneWidget);

    await tester.tap(find.text('Shrink all mixes'));
    await tester.pumpAndSettle();
    expect(find.text('Expand all mixes'), findsOneWidget);

    expect(find.byTooltip('Drag to reorder mix'), findsNothing);
    expect(find.byKey(const Key('master-mix-list')), findsOneWidget);
    expect(find.byType(ReorderableListView), findsNothing);

    await tester.tap(find.byTooltip('Mix actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Move up'), findsOneWidget);
    expect(find.text('Move down'), findsOneWidget);
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();

    final preview = tester.widget<MasterMixResultTable>(
      find.byType(MasterMixResultTable),
    );
    expect(preview.wizard.mixes.first.mixName, 'Mix B');
    expect(preview.wizard.mixes.last.mixName, 'Mix A');
  });

  testWidgets('reagent concentrations separate numerator and denominator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MasterMixManagerScreen(
          wizard: MasterMixWizard(
            mixes: [
              MasterMixItem(
                reagents: [
                  MasterMixReagentItem(
                    name: 'Protein',
                    stockUnit: ConcentrationUnit.mgML,
                    finalUnit: ConcentrationUnit.ugML,
                  ),
                ],
              ),
            ],
          ),
          onUpdate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Numerator'), findsNWidgets(2));
    expect(find.text('Denominator'), findsNWidgets(2));

    final stockValueField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'C1 (Stock Conc.)',
    );
    final stockNumerator = find.byKey(
      const ValueKey('C1 (Stock Conc.)_numerator_mg'),
    );
    expect(
      tester.getTopLeft(stockNumerator).dy,
      closeTo(tester.getTopLeft(stockValueField).dy, 2),
    );

    await tester.tap(stockNumerator);
    await tester.pumpAndSettle();
    expect(find.text('g'), findsOneWidget);
    expect(find.text('µg'), findsWidgets);
    expect(find.text('ng'), findsWidgets);
    await tester.tap(find.text('g'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('C1 (Stock Conc.)_denominator_gML')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('C1 (Stock Conc.)_denominator_gML')),
    );
    await tester.pumpAndSettle();
    expect(find.text('L'), findsWidgets);
    expect(find.text('µL'), findsWidgets);
    await tester.tap(find.text('µL').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('C1 (Stock Conc.)_denominator_gUL')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
