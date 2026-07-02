import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/master_mix/services/master_mix_calculator_service.dart';
import 'package:protocolflow/features/reagent_mix/services/reagent_mix_calculator_service.dart';
import 'package:protocolflow/features/lab_math/lab_calculation.dart';
import 'package:protocolflow/features/serial_dilution/models/serial_dilution_input.dart';
import 'package:protocolflow/features/serial_dilution/services/serial_dilution_calculator_service.dart';

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

  group('ReagentMixCalculatorService suspensions', () {
    test('calculates solid mass for mg per mL target concentration', () {
      final result = ReagentMixCalculatorService().calculateSuspension(
        ReagentMixInput(
          reagentName: 'Ovalbumin',
          stockConcentration: 0,
          stockUnit: ConcentrationUnit.ugML,
          workingConcentration: 10,
          workingUnit: ConcentrationUnit.mgML,
          volumePerTube: 10,
          volumePerTubeUnit: VolumeUnit.mL,
          numberOfTubes: 1,
        ),
      );

      expect(result.success, isTrue);
      expect(result.reagentMassGrams, closeTo(0.1, 0.000001));
      expect(result.totalVolumeUl, 10000);
    });

    test('calculates solid mass for percent w/v target concentration', () {
      final result = ReagentMixCalculatorService().calculateSuspension(
        ReagentMixInput(
          reagentName: 'Ovalbumin',
          stockConcentration: 0,
          stockUnit: ConcentrationUnit.ugML,
          workingConcentration: 1,
          workingUnit: ConcentrationUnit.percent,
          volumePerTube: 10,
          volumePerTubeUnit: VolumeUnit.mL,
          numberOfTubes: 1,
        ),
      );

      expect(result.success, isTrue);
      expect(result.reagentMassGrams, closeTo(0.1, 0.000001));
      expect(result.formattedSolventVolume, contains('Bring to'));
    });
  });

  group('ReagentMixCalculatorService smart pipetting', () {
    test(
      'recommends a compatible measuring tool for a small direct transfer',
      () {
        final result = ReagentMixCalculatorService().calculateMix(
          ReagentMixInput(
            reagentName: 'Antibody',
            stockConcentration: 1000,
            stockUnit: ConcentrationUnit.ugML,
            workingConcentration: 1,
            workingUnit: ConcentrationUnit.ugML,
            volumePerTube: 1000,
            volumePerTubeUnit: VolumeUnit.uL,
            numberOfTubes: 1,
            extraVolumePercent: 0,
          ),
        );

        expect(result.success, isTrue);
        expect(result.reagentVolumeUl, closeTo(1, 0.000001));
        expect(result.reagentTransferEvaluation, isNotNull);
        expect(result.reagentTransferEvaluation!.recommendedToolName, 'M2.5');
        expect(result.reagentTransferEvaluation!.repeats, 1);
        expect(result.suggestions, isEmpty);
      },
    );

    test(
      'does not suggest intermediate stock when direct transfer is practical',
      () {
        final result = ReagentMixCalculatorService().calculateMix(
          ReagentMixInput(
            reagentName: 'Buffer',
            stockConcentration: 10,
            stockUnit: ConcentrationUnit.X,
            workingConcentration: 1,
            workingUnit: ConcentrationUnit.X,
            volumePerTube: 1000,
            volumePerTubeUnit: VolumeUnit.uL,
            numberOfTubes: 1,
            extraVolumePercent: 0,
          ),
        );

        expect(result.success, isTrue);
        expect(result.reagentVolumeUl, closeTo(100, 0.000001));
        expect(result.suggestions, isEmpty);
      },
    );
  });

  group('MasterMixCalculatorService smart pipetting', () {
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
  });
}
