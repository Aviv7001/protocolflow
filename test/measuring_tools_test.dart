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

  testWidgets('measuring tools screen shows editable tool list tiles', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: MeasuringToolsManagerScreen(embedded: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Measuring Tools'), findsOneWidget);
    expect(find.textContaining('LIQUID'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('measuring-tool-balance_analytical')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SOLID'), findsOneWidget);
    expect(
      find.byKey(const Key('measuring-tool-balance_analytical')),
      findsOneWidget,
    );
    expect(find.byTooltip('Manage Analytical balance'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('measuring-tool-balance_analytical')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Tool'), findsOneWidget);
  });
}
