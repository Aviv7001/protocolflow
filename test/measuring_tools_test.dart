import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/measuring_tools/screens/measuring_tools_manager_screen.dart';
import 'package:protocolflow/features/measuring_tools/services/measuring_tool_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('default measuring tools include solid balances', () async {
    SharedPreferences.setMockInitialValues({});
    final service = MeasuringToolService.instance;
    final tools = await service.loadTools();

    expect(
      tools.where((tool) => tool.id == 'balance_micro').single.toolType,
      'Microbalance',
    );
    expect(
      tools.where((tool) => tool.id == 'balance_analytical').single.minMassMg,
      1,
    );
    expect(
      tools.where((tool) => tool.id == 'balance_top_loading').single.unit,
      'mg',
    );
  });

  testWidgets('measuring tools screen groups liquid and solid tools', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: MeasuringToolsManagerScreen(embedded: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Measuring Tools'), findsOneWidget);
    expect(find.text('Liquid'), findsOneWidget);
    expect(find.byTooltip('Expand Liquid tools'), findsOneWidget);
    expect(find.byTooltip('Expand Solid tools'), findsOneWidget);
    expect(find.text('Analytical balance'), findsNothing);

    await tester.tap(find.byTooltip('Expand Solid tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expand Analytical balance tools'));
    await tester.pumpAndSettle();

    expect(find.text('Analytical balance'), findsWidgets);
    expect(find.textContaining('Readability'), findsWidgets);
  });
}
