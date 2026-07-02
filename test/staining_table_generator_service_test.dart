import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/features/staining_table/models/stain_definition.dart';
import 'package:protocolflow/features/staining_table/models/staining_sample.dart';
import 'package:protocolflow/features/staining_table/models/staining_wizard.dart';
import 'package:protocolflow/features/staining_table/services/staining_table_generator_service.dart';

void main() {
  group('StainingTableGeneratorService last link only', () {
    final service = StainingTableGeneratorService();

    StainChain linkedChain({
      required String id,
      required String chainName,
      required String primary,
      required String reporter,
    }) {
      return StainChain(
        id: id,
        chainName: chainName,
        primary: StainComponent(name: primary, level: StainLevel.primary),
        secondary: StainComponent(name: reporter, level: StainLevel.secondary),
      );
    }

    StainChain directChain({
      required String id,
      required String chainName,
      required String stain,
    }) {
      return StainChain(
        id: id,
        chainName: chainName,
        primary: StainComponent(name: stain, level: StainLevel.primary),
      );
    }

    final panel = [
      linkedChain(
        id: 'chain_a',
        chainName: 'CD3',
        primary: 'CD3',
        reporter: 'AF488',
      ),
      linkedChain(
        id: 'chain_b',
        chainName: 'CD19',
        primary: 'CD19',
        reporter: 'AF488',
      ),
      directChain(id: 'chain_c', chainName: 'CD45', stain: 'CD45-PE'),
    ];

    test('single-stain last link only keeps only the tested last link', () {
      final result = service.generateTable(
        StainingWizard(
          panel: panel,
          samples: [
            StainingSample(
              sampleName: 'Sample 1',
              selectedChainIds: panel.map((chain) => chain.id).toList(),
              includeUnstained: false,
              includeSingleStain: true,
              includeSecondaryOnly: true,
              includeFullStain: false,
            ),
          ],
        ),
      );

      final row = result.rows.firstWhere(
        (row) => row.rowName == 'Sample 1 - AF488 only (single stain)',
      );

      expect(row.stainMap['AF488'], isTrue);
      expect(row.stainMap['CD3'], isFalse);
      expect(row.stainMap['CD19'], isFalse);
      expect(row.stainMap['CD45-PE'], isFalse);
    });

    test('full-stain last link only keeps the rest of the panel active', () {
      final result = service.generateTable(
        StainingWizard(
          panel: panel,
          samples: [
            StainingSample(
              sampleName: 'Sample 1',
              selectedChainIds: panel.map((chain) => chain.id).toList(),
              includeUnstained: false,
              includeSingleStain: false,
              includeSecondaryOnly: true,
              includeFullStain: true,
            ),
          ],
        ),
      );

      final row = result.rows.firstWhere(
        (row) => row.rowName == 'Sample 1 - AF488 only (full stain)',
      );

      expect(row.stainMap['AF488'], isTrue);
      expect(row.stainMap['CD45-PE'], isTrue);
      expect(row.stainMap['CD3'], isFalse);
      expect(row.stainMap['CD19'], isFalse);
    });

    test(
      'when both are enabled, both last-link-only row types are generated',
      () {
        final result = service.generateTable(
          StainingWizard(
            panel: panel,
            samples: [
              StainingSample(
                sampleName: 'Sample 1',
                selectedChainIds: panel.map((chain) => chain.id).toList(),
                includeUnstained: false,
                includeSingleStain: true,
                includeSecondaryOnly: true,
                includeFullStain: true,
              ),
            ],
          ),
        );

        expect(
          result.rows.any(
            (row) => row.rowName == 'Sample 1 - AF488 only (single stain)',
          ),
          isTrue,
        );
        expect(
          result.rows.any(
            (row) => row.rowName == 'Sample 1 - AF488 only (full stain)',
          ),
          isTrue,
        );
      },
    );

    test('keeps generated columns in panel component order', () {
      final result = service.generateTable(
        StainingWizard(
          panel: panel,
          samples: [
            StainingSample(
              sampleName: 'Sample 1',
              selectedChainIds: panel.map((chain) => chain.id).toList(),
            ),
          ],
        ),
      );

      expect(result.stainColumns, ['CD3', 'AF488', 'CD19', 'CD45-PE']);
    });
  });
}
