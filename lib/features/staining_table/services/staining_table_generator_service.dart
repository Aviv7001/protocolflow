import '../models/stain_definition.dart';
import '../models/staining_table_row.dart';
import '../models/staining_wizard.dart';

class StainingTableGeneratorService {
  /// Main calculation method for generating the staining table
  StainingTableResult generateTable(
    StainingWizard wizard, {
    bool includeUnstainedControl = true,
    bool includeSecondaryOnlyControl = true,
    bool includeFullStainRow = true,
  }) {
    // 1. Collect all unique component names used in the panel to create columns
    final Set<String> allComponentNames = {};
    for (var chain in wizard.panel) {
      for (var comp in chain.components) {
        if (comp.name.isNotEmpty) {
          allComponentNames.add(comp.name);
        }
      }
    }
    final List<String> columns = allComponentNames.toList()..sort();

    final List<StainingTableRow> rows = [];

    for (var sample in wizard.samples) {
      if (sample.sampleName.isEmpty) continue;

      // Get the chains selected for this sample
      final selectedChains = wizard.panel
          .where((chain) => sample.selectedChainIds.contains(chain.id))
          .toList();

      // 1. Unstained control: No stains at all
      if (includeUnstainedControl) {
        rows.add(_createRow(
          '${sample.sampleName} - unstained',
          [],
          columns,
        ));
      }

      if (selectedChains.isEmpty) continue;

      // 2. Last link only (Smart Control):
      // For every unique reporter/last link that is part of a LINKED chain:
      // Include that last link + all other independent stains (chains not using that reporter).
      if (includeSecondaryOnlyControl) {
        final Map<String, List<StainChain>> groupedByLastLink = {};
        for (var c in selectedChains) {
          final last = c.components.last.name;
          groupedByLastLink.putIfAbsent(last, () => []).add(c);
        }

        for (var entry in groupedByLastLink.entries) {
          final lastLinkName = entry.key;
          final chainsInGroup = entry.value;

          // Only generate "Last link only" if at least one chain in the group is linked (length > 1)
          if (chainsInGroup.any((c) => c.secondary != null)) {
            final List<StainComponent> rowComponents = [];
            
            // Add the last link component itself (representing the common reporter)
            rowComponents.add(chainsInGroup.first.components.last);

            // Add all components from chains that are NOT in this group
            for (var otherChain in selectedChains) {
              if (otherChain.components.last.name != lastLinkName) {
                rowComponents.addAll(otherChain.components);
              }
            }

            rows.add(_createRow(
              '${sample.sampleName} - $lastLinkName only',
              rowComponents,
              columns,
            ));
          }
        }
      }

      // 3. Full stain: All stains together, but split if they share the same last link
      if (includeFullStainRow) {
        final fullStainCombos = _generateFullStainCombinations(selectedChains);
        for (int i = 0; i < fullStainCombos.length; i++) {
          final suffix = fullStainCombos.length > 1 ? ' (Combo ${i + 1})' : '';
          rows.add(_createRow(
            '${sample.sampleName} - full stain$suffix',
            fullStainCombos[i],
            columns,
          ));
        }
      }
    }

    // Generate Metadata Rows (Ex, Em, Laser/Channel)
    final List<StainingTableRow> metadataRows = [
      _createMetadataRow('Ex (nm)', columns, wizard.panel, (c) => c.excitation?.toString() ?? ''),
      _createMetadataRow('Em (nm)', columns, wizard.panel, (c) => c.emission?.toString() ?? ''),
      _createMetadataRow('Laser/Channel', columns, wizard.panel, (c) => c.channel ?? ''),
    ];

    return StainingTableResult(
      stainColumns: columns,
      rows: rows,
      metadataRows: metadataRows,
    );
  }

  /// Groups selected chains by their last link to create compatible "Full Stain" combinations.
  /// If multiple chains share the same last link, they will be in different rows.
  List<List<StainComponent>> _generateFullStainCombinations(List<StainChain> selectedChains) {
    if (selectedChains.isEmpty) return [];

    // Map: Last Link Name -> List of Chains sharing it
    final Map<String, List<StainChain>> groups = {};
    for (var chain in selectedChains) {
      final lastLinkName = chain.components.last.name;
      groups.putIfAbsent(lastLinkName, () => []).add(chain);
    }

    // We need to pick exactly one chain from each group to form a "combination"
    List<List<StainChain>> combinations = [[]];
    
    for (var group in groups.values) {
      List<List<StainChain>> nextCombinations = [];
      for (var existingCombo in combinations) {
        for (var chain in group) {
          nextCombinations.add([...existingCombo, chain]);
        }
      }
      combinations = nextCombinations;
    }

    return combinations.map((combo) => combo.expand((c) => c.components).toList()).toList();
  }

  StainingTableRow _createRow(
    String name,
    List<StainComponent> activeComponents,
    List<String> allColumns,
  ) {
    final Map<String, bool> stainMap = {};
    for (var col in allColumns) {
      stainMap[col] = activeComponents.any((s) => s.name == col);
    }

    return StainingTableRow(
      rowName: name,
      totalStainsText: _formatTotalStains(activeComponents),
      stainMap: stainMap,
    );
  }

  StainingTableRow _createMetadataRow(
    String label,
    List<String> allColumns,
    List<StainChain> panel,
    String Function(StainChain) picker,
  ) {
    final Map<String, String> metaMap = {};
    for (var col in allColumns) {
      final chain = panel.cast<StainChain?>().firstWhere(
        (c) {
          if (c == null) return false;
          final comps = c.components;
          return comps.isNotEmpty && comps.last.name == col;
        },
        orElse: () => null,
      );
      
      metaMap[col] = chain != null ? picker(chain) : '';
    }

    return StainingTableRow(
      rowName: label,
      totalStainsText: '',
      stainMap: const {},
      isMetadataRow: true,
      metadataValues: metaMap,
    );
  }

  String _formatTotalStains(List<StainComponent> components) {
    if (components.isEmpty) return '-';
    final names = components.map((s) => s.name).toSet().toList();
    return names.join(' + ');
  }
}
