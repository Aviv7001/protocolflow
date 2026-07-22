import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/lab_math/lab_calculation.dart';
import 'package:protocolflow/features/lab_math/widgets/concentration_input_row.dart';

void main() {
  testWidgets('cells per mL shows coefficient and exponent fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ConcentrationInputRow(
              label: 'Stock Concentration',
              value: 5000000,
              unit: ConcentrationUnit.cellsML,
              units: const [ConcentrationUnit.cellsML],
              onValueChanged: (_) {},
              onUnitChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('x10^'), findsOneWidget);
    expect(find.text('cells/mL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
