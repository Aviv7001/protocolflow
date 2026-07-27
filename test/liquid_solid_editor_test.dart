import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/lab_math/lab_calculation.dart';
import 'package:protocolflow/features/master_mix/screens/master_mix_manager_screen.dart';
import 'package:protocolflow/features/serial_dilution/models/serial_dilution_input.dart';
import 'package:protocolflow/features/serial_dilution/screens/serial_dilution_manager_screen.dart';
import 'package:protocolflow/models/master_mix_wizard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('master mix editor accepts legacy g/mol reagent state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MasterMixManagerScreen(
          wizard: MasterMixWizard(
            reagents: [
              MasterMixReagentItem(
                name: 'Compound',
                stockConc: 180.16,
                stockUnit: ConcentrationUnit.gMol,
                finalConc: 5,
                finalUnit: ConcentrationUnit.mM,
              ),
            ],
          ),
          onUpdate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Solid'), findsOneWidget);
    expect(find.text('Molecular weight (g/mol)'), findsOneWidget);
  });

  testWidgets('serial dilution source switch keeps dropdown units valid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SerialDilutionManagerScreen(
          input: SerialDilutionInput(
            stockConcentrationUnit: ConcentrationUnit.ratio,
            startingDilutionConcentration: 10,
            startingDilutionConcentrationUnit: ConcentrationUnit.ratio,
            targetLowestConcentration: 100,
            targetLowestConcentrationUnit: ConcentrationUnit.ratio,
          ),
          onUpdate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solid'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('D0 Final Concentration'), findsOneWidget);
  });

  testWidgets('serial dilution editor normalizes legacy g/mol units', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SerialDilutionManagerScreen(
          input: SerialDilutionInput(
            stockConcentrationUnit: ConcentrationUnit.gMol,
            startingDilutionConcentration: 1,
            startingDilutionConcentrationUnit: ConcentrationUnit.gMol,
            targetLowestConcentration: 0.1,
            targetLowestConcentrationUnit: ConcentrationUnit.gMol,
          ),
          onUpdate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('g/mol'), findsNothing);
  });
}
