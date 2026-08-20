import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/master_mix/services/master_mix_calculator_service.dart';
import 'package:protocolflow/features/lab_math/lab_calculation.dart';
import 'package:protocolflow/features/serial_dilution/models/serial_dilution_input.dart';
import 'package:protocolflow/features/serial_dilution/services/serial_dilution_calculator_service.dart';
import 'package:protocolflow/models/master_mix_wizard.dart';

void main() {
  group('LabCalculation concentration units', () {
    test('converts mass per microliter units to base g/L', () {
      expect(LabCalculation.concentrationToBase(1, ConcentrationUnit.ugUL), 1);
      expect(
        LabCalculation.concentrationToBase(1, ConcentrationUnit.mgUL),
        1000,
      );
      expect(
        LabCalculation.concentrationToBase(1, ConcentrationUnit.ngUL),
        0.001,
      );
    });

    test('formats mass per microliter labels', () {
      expect(LabCalculation.unitLabel(ConcentrationUnit.ugUL), 'ug/uL');
      expect(LabCalculation.unitLabel(ConcentrationUnit.mgUL), 'mg/uL');
      expect(LabCalculation.unitLabel(ConcentrationUnit.ngUL), 'ng/uL');
    });

    test('parses colon and slash ratio inputs', () {
      expect(
        LabCalculation.parseConcentrationInput('1:50', ConcentrationUnit.ratio),
        50,
      );
      expect(
        LabCalculation.parseConcentrationInput('1/50', ConcentrationUnit.ratio),
        50,
      );
      expect(
        LabCalculation.parseConcentrationInput('2:10', ConcentrationUnit.ratio),
        5,
      );
    });

    test('combines cells per mL coefficient and exponent', () {
      final value = LabCalculation.parseConcentrationInput(
        '5',
        ConcentrationUnit.cellsML,
        cellsExponent: 6,
      );

      expect(value, 5000000);
      expect(LabCalculation.cellsCoefficient(value!), 5);
      expect(LabCalculation.cellsExponent(value), 6);
      expect(
        LabCalculation.formatInputConcentration(
          value,
          ConcentrationUnit.cellsML,
        ),
        '5 x 10^6 cells/mL',
      );
    });
  });

  group('LabCalculation smart pipetting helpers', () {
    test('detects transfers below the practical fraction threshold', () {
      expect(
        LabCalculation.isBelowPracticalTransferFraction(
          transferUl: 1,
          totalUl: 1000,
        ),
        isTrue,
      );
      expect(
        LabCalculation.isBelowPracticalTransferFraction(
          transferUl: 50,
          totalUl: 1000,
        ),
        isFalse,
      );
    });

    test('builds reusable intermediate dilution suggestions', () {
      final suggestion = LabCalculation.intermediateDilutionSuggestion(
        stockConcentrationBase: LabCalculation.concentrationToBase(
          1000,
          ConcentrationUnit.ugML,
        ),
        targetConcentrationBase: LabCalculation.concentrationToBase(
          1,
          ConcentrationUnit.ugML,
        ),
        targetDisplayUnit: ConcentrationUnit.ugML,
        totalVolumeUl: 1000,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.intermediateStockConcentration, closeTo(20, 0.000001));
      expect(suggestion.finalTransferVolumeUl, 50);
      expect(suggestion.finalSolventVolumeUl, 950);
      expect(suggestion.message, contains('Suggested intermediate'));
    });
  });

  group('MasterMixCalculatorService smart pipetting', () {
    test('migrates legacy g/mol reagent data to a solid material', () {
      final reagent = MasterMixReagentItem.fromJson({
        'name': 'Compound',
        'stockConc': 180.16,
        'stockUnit': 'gMol',
        'finalConc': 5,
        'finalUnit': 'mM',
      });

      expect(reagent.sourceType, ReagentSourceType.solidMaterial);
      expect(reagent.mw, 180.16);
      expect(reagent.finalConc, 5);
      expect(reagent.finalUnit, ConcentrationUnit.mM);
    });

    test(
      'recommends a compatible measuring tool for small reagent volumes',
      () {
        final result = MasterMixCalculatorService().calculateMasterMix(
          MasterMixInput(
            mixName: 'Tiny transfer mix',
            finalVolume: 1000,
            finalVolumeUnit: VolumeUnit.uL,
            extraVolumePercent: 0,
            baseSolventName: 'PBS',
            reagents: [
              MasterMixReagentInput(
                reagentName: 'Antibody',
                stockConcentration: 1000,
                stockConcentrationUnit: ConcentrationUnit.ugML,
                finalConcentration: 1,
                finalConcentrationUnit: ConcentrationUnit.ugML,
              ),
            ],
          ),
        );

        expect(result.success, isTrue);
        expect(result.reagentResults.single.transferEvaluation, isNotNull);
        expect(
          result.reagentResults.single.transferEvaluation!.recommendedToolName,
          'M2.5',
        );
        expect(result.reagentResults.single.suggestions, isEmpty);
      },
    );

    test('calculates solid reagent mass and balance recommendation', () {
      final result = MasterMixCalculatorService().calculateMasterMix(
        MasterMixInput(
          mixName: 'Digest mix',
          finalVolume: 10,
          finalVolumeUnit: VolumeUnit.mL,
          extraVolumePercent: 0,
          baseSolventName: 'HBSS',
          reagents: [
            MasterMixReagentInput(
              sourceType: ReagentSourceType.solidMaterial,
              reagentName: 'Collagenase type II',
              stockConcentration: 0,
              stockConcentrationUnit: ConcentrationUnit.mgML,
              finalConcentration: 2,
              finalConcentrationUnit: ConcentrationUnit.mgML,
            ),
          ],
        ),
      );

      expect(result.success, isTrue);
      final reagent = result.reagentResults.single;
      expect(reagent.reagentMassGrams, closeTo(0.02, 0.000001));
      expect(reagent.formattedReagentVolume, '20 mg');
      expect(reagent.massEvaluation, isNotNull);
      expect(reagent.massEvaluation!.recommendedToolName, isNotEmpty);
      expect(result.baseSolventVolumeUl, 10000);
      expect(
        result.formattedBaseSolventVolume,
        'Bring to 10.000 mL (~10.000 mL)',
      );
      expect(reagent.formattedStockConcentration, 'Solid material');
    });

    test('estimates solvent after liquid additions in a mix with solids', () {
      final result = MasterMixCalculatorService().calculateMasterMix(
        MasterMixInput(
          mixName: 'Mixed material preparation',
          finalVolume: 10,
          finalVolumeUnit: VolumeUnit.mL,
          extraVolumePercent: 0,
          baseSolventName: 'Water',
          reagents: [
            MasterMixReagentInput(
              reagentName: 'Liquid stock',
              stockConcentration: 10,
              stockConcentrationUnit: ConcentrationUnit.mgML,
              finalConcentration: 5.1,
              finalConcentrationUnit: ConcentrationUnit.mgML,
            ),
            MasterMixReagentInput(
              sourceType: ReagentSourceType.solidMaterial,
              reagentName: 'Solid reagent',
              stockConcentration: 0,
              stockConcentrationUnit: ConcentrationUnit.mgML,
              finalConcentration: 2,
              finalConcentrationUnit: ConcentrationUnit.mgML,
            ),
          ],
        ),
      );

      expect(result.success, isTrue);
      expect(result.baseSolventVolumeUl, closeTo(4900, 0.000001));
      expect(
        result.formattedBaseSolventVolume,
        'Bring to 10.000 mL (~4.900 mL)',
      );
    });

    test('generated master mix table labels mixed measurements as amount', () {
      final table = MasterMixWizard(
        finalVolume: 10,
        finalVolumeUnit: VolumeUnit.mL,
        extraVolumePercent: 0,
        reagents: [
          MasterMixReagentItem(
            sourceType: ReagentSourceType.solidMaterial,
            name: 'Collagenase type II',
            finalConc: 2,
            finalUnit: ConcentrationUnit.mgML,
          ),
        ],
      ).generateTable();

      expect(table.columnHeaders, contains('Amount'));
      expect(table.columnHeaders, isNot(contains('final volume')));
    });

    test('requires molecular weight for solid molar targets', () {
      final result = MasterMixCalculatorService().calculateMasterMix(
        MasterMixInput(
          mixName: 'Molar solid',
          finalVolume: 1,
          finalVolumeUnit: VolumeUnit.mL,
          extraVolumePercent: 0,
          baseSolventName: 'Water',
          reagents: [
            MasterMixReagentInput(
              sourceType: ReagentSourceType.solidMaterial,
              reagentName: 'Compound',
              stockConcentration: 0,
              stockConcentrationUnit: ConcentrationUnit.mM,
              finalConcentration: 1,
              finalConcentrationUnit: ConcentrationUnit.mM,
            ),
          ],
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Molecular weight is required'));
    });
  });

  group('SerialDilutionCalculatorService smart pipetting', () {
    test(
      'adds suggestions for dilution rows below practical transfer fraction',
      () {
        final result = SerialDilutionCalculatorService().generateDilutionTable(
          SerialDilutionInput(
            title: 'Steep dilution',
            stockSolutionName: 'Stock',
            stockConcentration: 1000,
            stockConcentrationUnit: ConcentrationUnit.ugML,
            startingDilutionConcentration: 1,
            startingDilutionConcentrationUnit: ConcentrationUnit.ugML,
            dilutionFactor: 10,
            finalVolume: 1000,
            finalVolumeUnit: VolumeUnit.uL,
            extraVolumePercent: 0,
            dilutionMode: DilutionMode.independent,
            seriesLengthMode: SeriesLengthMode.numberOfDilutions,
            numberOfDilutions: 1,
          ),
        );

        expect(result.success, isTrue);
        expect(
          result.rows.where((row) => row.suggestions.isNotEmpty),
          isNotEmpty,
        );
      },
    );

    test('uses weighed solid material to prepare D0', () {
      final result = SerialDilutionCalculatorService().generateDilutionTable(
        SerialDilutionInput(
          title: 'Collagenase series',
          startingSourceType: ReagentSourceType.solidMaterial,
          stockSolutionName: 'Collagenase type II',
          stockConcentration: 0,
          stockConcentrationUnit: ConcentrationUnit.mgML,
          startingDilutionConcentration: 2,
          startingDilutionConcentrationUnit: ConcentrationUnit.mgML,
          dilutionFactor: 2,
          finalVolume: 1000,
          finalVolumeUnit: VolumeUnit.uL,
          extraVolumePercent: 0,
          dilutionMode: DilutionMode.independent,
          seriesLengthMode: SeriesLengthMode.numberOfDilutions,
          numberOfDilutions: 1,
        ),
      );

      expect(result.success, isTrue);
      expect(result.rows.first.dilutionName, 'D0');
      expect(result.rows.first.formattedTransferVolume, '2 mg');
      expect(result.rows.first.formattedSolventVolume, contains('Bring to'));
      expect(result.rows.first.finalVolumeUl, 1000);
      expect(result.rows.first.massEvaluation, isNotNull);
      expect(result.rows[1].transferFrom, 'D0');
      expect(result.rows[1].transferVolumeUl, closeTo(500, 0.000001));
    });

    test('generated serial dilution table labels transfer amount', () {
      final table = SerialDilutionInput(
        startingSourceType: ReagentSourceType.solidMaterial,
        stockSolutionName: 'Collagenase type II',
        stockConcentration: 0,
        stockConcentrationUnit: ConcentrationUnit.mgML,
        startingDilutionConcentration: 2,
        startingDilutionConcentrationUnit: ConcentrationUnit.mgML,
        dilutionFactor: 2,
        finalVolume: 1000,
        finalVolumeUnit: VolumeUnit.uL,
        extraVolumePercent: 0,
        numberOfDilutions: 1,
      ).generateTable();

      expect(table.columnHeaders, contains('Transfer Amount'));
      expect(table.columnHeaders, isNot(contains('Transfer Volume')));
    });
  });
}
