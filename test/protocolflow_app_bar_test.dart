import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/master_mix/screens/master_mix_manager_screen.dart';
import 'package:protocolflow/features/serial_dilution/models/serial_dilution_input.dart';
import 'package:protocolflow/features/serial_dilution/screens/serial_dilution_manager_screen.dart';
import 'package:protocolflow/features/staining_table/models/staining_wizard.dart';
import 'package:protocolflow/features/staining_table/screens/staining_table_manager_screen.dart';
import 'package:protocolflow/models/master_mix_wizard.dart';
import 'package:protocolflow/models/plate_wizard.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/screens/plate_wizard_samples_screen.dart';
import 'package:protocolflow/screens/table_data_editor_screen.dart';
import 'package:protocolflow/screens/table_selection_screen.dart';
import 'package:protocolflow/theme/app_colors.dart';
import 'package:protocolflow/widgets/protocolflow_app_bar.dart';

void main() {
  testWidgets('lab tools and generators share the ProtocolFlow app bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final screens = <({String title, Widget screen})>[
      (
        title: 'Lab Tools',
        screen: const TableSelectionScreen(
          title: 'Lab Tools',
          standaloneMode: true,
        ),
      ),
      (
        title: 'Master Mix Manager',
        screen: MasterMixManagerScreen(
          wizard: MasterMixWizard(),
          onUpdate: (_) {},
        ),
      ),
      (
        title: 'Staining Manager',
        screen: StainingTableManagerScreen(
          wizard: StainingWizard(),
          onUpdate: (_) {},
        ),
      ),
      (
        title: 'Serial Dilution Manager',
        screen: SerialDilutionManagerScreen(
          input: SerialDilutionInput(),
          onUpdate: (_) {},
        ),
      ),
      (
        title: 'Sample Manager',
        screen: PlateWizardSamplesScreen(
          wizard: PlateLayoutWizard(),
          onUpdate: (_) {},
        ),
      ),
      (
        title: 'Generic Table',
        screen: TableDataEditorScreen(
          tables: [
            ProtocolTable(
              id: 'generic-table',
              title: 'Generic Table',
              metadata: const {'needs_dimension_setup': 'true'},
            ),
          ],
          onSave: (_) {},
        ),
      ),
    ];

    for (final entry in screens) {
      await tester.pumpWidget(MaterialApp(home: entry.screen));
      await tester.pump();

      final appBarFinder = find.byType(ProtocolFlowAppBar);
      expect(appBarFinder, findsOneWidget, reason: entry.title);
      final appBar = tester.widget<ProtocolFlowAppBar>(appBarFinder);
      expect(appBar.toolbarHeight, 64, reason: entry.title);
      expect(appBar.backgroundColor, AppColors.surface, reason: entry.title);
      expect(
        appBar.foregroundColor,
        AppColors.textPrimary,
        reason: entry.title,
      );
      expect(appBar.centerTitle, isFalse, reason: entry.title);

      final title = tester.widget<Text>(
        find.descendant(of: appBarFinder, matching: find.text(entry.title)),
      );
      expect(title.style?.color, AppColors.primary, reason: entry.title);
      expect(title.style?.fontSize, 22, reason: entry.title);
      expect(title.style?.fontWeight, FontWeight.w700, reason: entry.title);
      expect(tester.takeException(), isNull, reason: entry.title);
    }
  });
}
