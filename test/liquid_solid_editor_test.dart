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

  testWidgets('serial dilution can toggle the suggested D0 intermediate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SerialDilutionManagerScreen(
          input: SerialDilutionInput(
            stockConcentration: 100000,
            stockConcentrationUnit: ConcentrationUnit.ugML,
            startingDilutionConcentration: 1,
            startingDilutionConcentrationUnit: ConcentrationUnit.ugML,
            dilutionFactor: 10,
            finalVolume: 1000,
            finalVolumeUnit: VolumeUnit.uL,
            extraVolumePercent: 0,
            dilutionMode: DilutionMode.independent,
            numberOfDilutions: 1,
          ),
          onUpdate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Numerator'), findsNWidgets(2));
    expect(find.text('Denominator'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('toggle-d0-intermediate-dilution')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('toggle-d0-intermediate-dilution')),
    );
    await tester.pumpAndSettle();

    expect(find.text('D0 intermediate'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('toggle-d0-intermediate-dilution')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('toggle-d0-intermediate-dilution')),
    );
    await tester.pumpAndSettle();

    expect(find.text('D0 intermediate'), findsNothing);
    expect(
      find.byKey(const ValueKey('toggle-d0-intermediate-dilution')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
