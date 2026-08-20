import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:protocolflow/widgets/protocol_export_dialog.dart';

void main() {
  testWidgets('protocol export dialog returns the selected format', (
    tester,
  ) async {
    ProtocolExportFormat? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                selected = await showDialog<ProtocolExportFormat>(
                  context: context,
                  builder: (_) => const ProtocolExportDialog(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('protocol-export-dialog')), findsOneWidget);
    expect(find.text('Excel (XLSX)'), findsOneWidget);
    final excelTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Excel (XLSX)'),
        matching: find.byType(ListTile),
      ),
    );
    expect(excelTile.enabled, isFalse);

    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(selected, ProtocolExportFormat.pdf);
    expect(find.byKey(const Key('protocol-export-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
