import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/staining_table/models/stain_definition.dart';
import 'package:protocolflow/features/staining_table/models/staining_sample.dart';
import 'package:protocolflow/features/staining_table/models/staining_wizard.dart';
import 'package:protocolflow/features/staining_table/screens/staining_table_manager_screen.dart';

void main() {
  testWidgets('staining chains and samples use move actions without dragging', (
    tester,
  ) async {
    StainingWizard? saved;
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: StainingTableManagerScreen(
          wizard: StainingWizard(
            panel: [
              StainChain(
                id: 'chain-a',
                chainName: 'Chain A',
                primary: StainComponent(
                  name: 'Primary A',
                  level: StainLevel.primary,
                ),
              ),
              StainChain(
                id: 'chain-b',
                chainName: 'Chain B',
                primary: StainComponent(
                  name: 'Primary B',
                  level: StainLevel.primary,
                ),
              ),
            ],
            samples: [
              StainingSample(sampleName: 'Sample A'),
              StainingSample(sampleName: 'Sample B'),
            ],
          ),
          onUpdate: (wizard) => saved = wizard,
          promptForSaveDetails: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Drag to reorder stain chain'), findsNothing);
    expect(find.byTooltip('Drag to reorder staining sample'), findsNothing);
    expect(find.byKey(const Key('stain-chain-list')), findsOneWidget);
    expect(find.byKey(const Key('staining-sample-list')), findsOneWidget);

    await tester.tap(find.byTooltip('Chain actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sample actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save table'));
    await tester.pump();
    expect(saved, isNotNull);
    expect(saved!.panel.map((chain) => chain.chainName), [
      'Chain B',
      'Chain A',
    ]);
    expect(saved!.samples.map((sample) => sample.sampleName), [
      'Sample B',
      'Sample A',
    ]);
  });
}
