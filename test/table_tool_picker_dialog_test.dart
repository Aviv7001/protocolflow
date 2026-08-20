import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/screens/table_selection_screen.dart';
import 'package:protocolflow/theme/app_theme.dart';

void main() {
  Future<void> pumpPicker(
    WidgetTester tester, {
    required bool standaloneMode,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showTableToolPicker(context, standaloneMode: standaloneMode),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('protocol table picker includes saved tables', (tester) async {
    await pumpPicker(tester, standaloneMode: false);

    expect(find.byKey(const Key('table-tool-picker-dialog')), findsOneWidget);
    expect(find.text('Add table'), findsOneWidget);
    expect(find.text('Saved Tables'), findsOneWidget);
    expect(find.text('Import Table'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone Lab Tools picker hides saved tables', (tester) async {
    await pumpPicker(tester, standaloneMode: true);

    expect(find.text('Lab tools'), findsOneWidget);
    expect(find.text('Saved Tables'), findsNothing);
    expect(find.text('Master Mix'), findsOneWidget);
    expect(find.text('Plate Layout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
