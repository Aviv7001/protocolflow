import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/master_mix/services/master_mix_calculator_service.dart';
import 'package:protocolflow/features/lab_math/lab_calculation.dart';
import 'package:protocolflow/features/serial_dilution/models/serial_dilution_input.dart';
import 'package:protocolflow/features/serial_dilution/services/serial_dilution_calculator_service.dart';
import 'package:protocolflow/models/master_mix_wizard.dart';

void main() {
  group('LabCalculation concentration units', () {
    test('supports independently selected mass and volume units', () {
      expect(
        LabCalculation.concentrationToBase(1, ConcentrationUnit.gML),
        1000,
      );
      expect(
        LabCalculation.concentrationToBase(1, ConcentrationUnit.mgL),
        0.001,
      );
      expect(
        LabCalculation.concentrationToBase(1, ConcentrationUnit.ugL),
        0.000001,
      );
      expect(
        LabCalculation.concentrationToBase(1, ConcentrationUnit.ngL),
        0.000000001,
      );
      expect(LabCalculation.unitLabel(ConcentrationUnit.gML), 'g/mL');
      expect(LabCalculation.unitLabel(ConcentrationUnit.mgL), 'mg/L');
    });

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

    test(
      'derives C2 when percent is used as a relative final concentration',
      () {
        final result = MasterMixCalculatorService().calculateMasterMix(
          MasterMixInput(
            mixName: 'Percent mix',
            finalVolume: 1000,
            finalVolumeUnit: VolumeUnit.uL,
            extraVolumePercent: 0,
            baseSolventName: 'Water',
            reagents: [
              MasterMixReagentInput(
                reagentName: 'Protein',
                stockConcentration: 50,
                stockConcentrationUnit: ConcentrationUnit.mgML,
                finalConcentration: 5,
                finalConcentrationUnit: ConcentrationUnit.percent,
              ),
            ],
          ),
        );

        expect(result.success, isTrue);
        expect(
          result.reagentResults.single.reagentVolumeUl,
          closeTo(50, 0.001),
        );
        expect(
          result.reagentResults.single.formattedFinalConcentration,
          '2.5 mg/mL (5 % of C1)',
        );
        expect(result.baseSolventVolumeUl, closeTo(950, 0.001));
      },
    );

    test('derives C2 when ratio is used as a relative final concentration', () {
      final result = MasterMixCalculatorService().calculateMasterMix(
        MasterMixInput(
          mixName: 'Ratio mix',
          finalVolume: 1000,
          finalVolumeUnit: VolumeUnit.uL,
          extraVolumePercent: 0,
          baseSolventName: 'Water',
          reagents: [
            MasterMixReagentInput(
              reagentName: 'Antibody',
              stockConcentration: 50,
              stockConcentrationUnit: ConcentrationUnit.mgML,
              finalConcentration: 20,
              finalConcentrationUnit: ConcentrationUnit.ratio,
            ),
          ],
        ),
      );

      expect(result.success, isTrue);
      expect(result.reagentResults.single.reagentVolumeUl, closeTo(50, 0.001));
      expect(
        result.reagentResults.single.formattedFinalConcentration,
        '2.5 mg/mL (1:20 of C1)',
      );
      expect(result.baseSolventVolumeUl, closeTo(950, 0.001));
    });

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

    test('adds a selected D0 intermediate dilution as a preparation row', () {
      final baseInput = SerialDilutionInput(
        title: 'D0 intermediate',
        stockSolutionName: 'Stock',
        stockConcentration: 19500,
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
      );
      final calculator = SerialDilutionCalculatorService();

      final suggested = calculator.generateDilutionTable(baseInput);
      expect(suggested.success, isTrue);
      expect(suggested.d0IntermediateSuggestion, isNotNull);
      expect(suggested.includesD0IntermediateDilution, isFalse);
      expect(
        suggested.rows.map((row) => row.dilutionName),
        isNot(contains('D0 intermediate')),
      );

      final selectedInput = baseInput.copyWith(
        includeD0IntermediateDilution: true,
      );
      final selected = calculator.generateDilutionTable(selectedInput);
      expect(selected.includesD0IntermediateDilution, isTrue);
      expect(
        selected.rows.map((row) => row.dilutionName),
        orderedEquals(['Stock', 'D0 intermediate', 'D0', 'D1']),
      );
      expect(selected.rows[2].transferFrom, 'D0 intermediate');
      expect(selected.rows[2].transferVolumeUl, closeTo(50, 0.000001));
      expect(selected.rows[1].finalVolumeUl, closeTo(975, 0.000001));
      expect(selected.rows[1].transferVolumeUl, closeTo(1, 0.000001));
      expect(selected.rows[1].solventVolumeUl, closeTo(974, 0.000001));
      expect(selected.rows[1].warnings, isEmpty);
      expect(selected.rows[1].suggestions, isEmpty);
      expect(selected.rows[1].transferEvaluation, isNull);
      expect(selected.rows[1].solventTransferEvaluation, isNull);

      final restored = SerialDilutionInput.fromJson(selectedInput.toJson());
      expect(restored.includeD0IntermediateDilution, isTrue);
      expect(
        restored.generateTable().data.map((row) => row.first),
        contains('D0 intermediate'),
      );
    });

    test(
      'scales output numerators while preserving the starting denominator',
      () {
        final calculator = SerialDilutionCalculatorService();
        final small = calculator.generateDilutionTable(
          SerialDilutionInput(
            stockConcentration: 10,
            stockConcentrationUnit: ConcentrationUnit.mgML,
            startingDilutionConcentration: 1,
            startingDilutionConcentrationUnit: ConcentrationUnit.mgML,
            dilutionFactor: 10000,
            finalVolume: 1000,
            finalVolumeUnit: VolumeUnit.uL,
            extraVolumePercent: 0,
            dilutionMode: DilutionMode.independent,
            numberOfDilutions: 1,
          ),
        );
        final large = calculator.generateDilutionTable(
          SerialDilutionInput(
            stockConcentration: 2,
            stockConcentrationUnit: ConcentrationUnit.gL,
            startingDilutionConcentration: 1000,
            startingDilutionConcentrationUnit: ConcentrationUnit.ugML,
            dilutionFactor: 2,
            finalVolume: 1000,
            finalVolumeUnit: VolumeUnit.uL,
            extraVolumePercent: 0,
            dilutionMode: DilutionMode.independent,
            numberOfDilutions: 1,
          ),
        );

        expect(small.success, isTrue);
        expect(small.rows.last.formattedConcentration, '0.1 ug/mL');
        expect(large.success, isTrue);
        expect(large.rows.first.formattedConcentration, '2 mg/mL');
        expect(large.rows[1].formattedConcentration, '1 mg/mL');
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
