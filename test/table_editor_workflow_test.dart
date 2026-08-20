import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/models/plate_wizard.dart';
import 'package:protocolflow/screens/plate_wizard_samples_screen.dart';
import 'package:protocolflow/screens/table_data_editor_screen.dart';
import 'package:protocolflow/screens/table_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('generic table columns can be deleted', (tester) async {
    List<ProtocolTable>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: TableDataEditorScreen(
          tables: [
            ProtocolTable(
              id: 'generic',
              title: 'Editable table',
              type: TableType.generic,
              columnHeaders: const ['A', 'B'],
              rowHeaders: const ['2'],
              data: const [
                ['one', 'two'],
              ],
            ),
          ],
          promptForSaveDetails: false,
          onSave: (tables) => saved = tables,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete-generic-column-0')));
    await tester.tap(find.byTooltip('Save table'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.single.columnHeaders, ['B']);
    expect(saved!.single.data, [
      ['two'],
    ]);
  });

  testWidgets('canceling save returns to the generated table editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: TableSelectionScreen(standaloneMode: true, embedded: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generic Table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate table'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save table'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save-table-dialog')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Generic Table'), findsWidgets);
    expect(find.byTooltip('Save table'), findsOneWidget);
    expect(find.byKey(const Key('save-table-dialog')), findsNothing);
  });

  testWidgets('wide plate manager puts layout directions above the plate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(items: [TestItem(sampleName: 'Sample A')]),
          onUpdate: (_) {},
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final directionsTop = tester.getTopLeft(find.text('Layout Directions')).dy;
    final directionsLeft = tester.getTopLeft(find.text('Layout Directions')).dx;
    final configurationLeft = tester
        .getTopLeft(find.text('Plate Configuration'))
        .dx;
    final plateTop = tester.getTopLeft(find.text('Plate Layout').last).dy;
    expect(directionsTop, lessThan(plateTop));
    expect(directionsLeft, greaterThan(configurationLeft));
  });

  testWidgets('imported plate samples remain editable with plate settings', (
    tester,
  ) async {
    PlateLayoutWizard? updated;
    final importedTable = ProtocolTable(
      id: 'imported',
      title: 'Imported Plate Layout',
      type: TableType.plateLayout,
      columnHeaders: const ['1'],
      rowHeaders: const ['A'],
      data: const [
        ['Sample A'],
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(
            items: [TestItem(sampleName: 'Sample A')],
            importedTables: [importedTable],
          ),
          onUpdate: (wizard) => updated = wizard,
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Rows'), '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byTooltip('Save table'));
    await tester.pump();

    expect(updated, isNotNull);
    expect(updated!.rows, 4);
    expect(updated!.items.single.sampleName, 'Sample A');
    expect(updated!.importedTables, isEmpty);
  });
}
