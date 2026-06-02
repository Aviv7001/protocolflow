import 'package:flutter/material.dart';
import '../models/stain_definition.dart';
import '../models/staining_sample.dart';
import '../models/staining_wizard.dart';
import '../services/staining_table_generator_service.dart';
import '../widgets/staining_result_table.dart';

class StainingTableManagerScreen extends StatefulWidget {
  final StainingWizard wizard;
  final Function(StainingWizard) onUpdate;

  const StainingTableManagerScreen({super.key, required this.wizard, required this.onUpdate});

  @override
  State<StainingTableManagerScreen> createState() => _StainingTableManagerScreenState();
}

class _StainingTableManagerScreenState extends State<StainingTableManagerScreen> {
  late StainingWizard _wizard;
  final StainingTableGeneratorService _generator = StainingTableGeneratorService();
  static const double _uniformFontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _wizard = widget.wizard;
  }

  void _addChain() {
    setState(() {
      final newPanel = List<StainChain>.from(_wizard.panel);
      newPanel.add(StainChain(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chainName: 'Chain ${newPanel.length + 1}',
        primary: StainComponent(name: 'Primary Stain', level: StainLevel.primary),
      ));
      _wizard = _wizard.copyWith(panel: newPanel);
    });
  }

  void _removeChain(int index) {
    setState(() {
      final chainId = _wizard.panel[index].id;
      final newPanel = List<StainChain>.from(_wizard.panel)..removeAt(index);
      final newSamples = _wizard.samples.map((s) {
        if (s.selectedChainIds.contains(chainId)) {
          return s.copyWith(selectedChainIds: List<String>.from(s.selectedChainIds)..remove(chainId));
        }
        return s;
      }).toList();
      _wizard = _wizard.copyWith(panel: newPanel, samples: newSamples);
    });
  }

  void _updateChain(int index, StainChain newChain) {
    setState(() {
      final newPanel = List<StainChain>.from(_wizard.panel);
      newPanel[index] = newChain;
      _wizard = _wizard.copyWith(panel: newPanel);
    });
  }

  void _addSample() {
    setState(() {
      final newSamples = List<StainingSample>.from(_wizard.samples);
      newSamples.add(StainingSample(
        sampleName: 'Sample ${newSamples.length + 1}',
        selectedChainIds: [],
      ));
      _wizard = _wizard.copyWith(samples: newSamples);
    });
  }

  void _removeSample(int index) {
    setState(() {
      final newSamples = List<StainingSample>.from(_wizard.samples)..removeAt(index);
      _wizard = _wizard.copyWith(samples: newSamples);
    });
  }

  void _updateSample(int index, StainingSample newSample) {
    setState(() {
      final newSamples = List<StainingSample>.from(_wizard.samples);
      newSamples[index] = newSample;
      _wizard = _wizard.copyWith(samples: newSamples);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _generator.generateTable(
      _wizard,
      includeUnstainedControl: _wizard.includeUnstained,
      includeSecondaryOnlyControl: _wizard.includeSecondaryOnly,
      includeFullStainRow: _wizard.includeFullStain,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staining Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _handleDone(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOptionsCard(),
            const SizedBox(height: 24),
            Text('Panel Configuration', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addChain,
                icon: const Icon(Icons.add),
                label: const Text('Add Stain Chain', style: TextStyle(fontSize: _uniformFontSize)),
              ),
            ),
            const SizedBox(height: 12),
            ..._wizard.panel.asMap().entries.map((entry) => _buildChainCard(entry.key, entry.value)),
            if (_wizard.panel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _addChain,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Stain Chain', style: TextStyle(fontSize: _uniformFontSize)),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Text('Sample Setup', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addSample,
                icon: const Icon(Icons.add),
                label: const Text('Add Sample', style: TextStyle(fontSize: _uniformFontSize)),
              ),
            ),
            const SizedBox(height: 12),
            ..._wizard.samples.asMap().entries.map((entry) => _buildSampleCard(entry.key, entry.value)),
            if (_wizard.samples.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _addSample,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Sample', style: TextStyle(fontSize: _uniformFontSize)),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            if (result.rows.isNotEmpty) ...[
              Text('Generated Staining Table', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              StainingResultTable(wizard: _wizard, generator: _generator),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _handleDone(BuildContext context) async {
    final String? name = await _showSaveDialog(context, _wizard.title);
    if (name != null) {
      setState(() {
        _wizard = _wizard.copyWith(title: name);
      });
      widget.onUpdate(_wizard);
      if (context.mounted) {
        Navigator.pop(context, _wizard);
      }
    }
  }

  Future<String?> _showSaveDialog(BuildContext context, String suggestedName) async {
    String currentName = suggestedName;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Table'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Table Name', hintText: 'Enter table name...'),
          controller: TextEditingController(text: suggestedName),
          onChanged: (v) => currentName = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, currentName),
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _buildToggle('Unstained', _wizard.includeUnstained, (v) => setState(() => _wizard = _wizard.copyWith(includeUnstained: v))),
            _buildToggle('Last link only', _wizard.includeSecondaryOnly, (v) => setState(() => _wizard = _wizard.copyWith(includeSecondaryOnly: v))),
            _buildToggle('Full Stain', _wizard.includeFullStain, (v) => setState(() => _wizard = _wizard.copyWith(includeFullStain: v))),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
          Text(label, style: const TextStyle(fontSize: _uniformFontSize, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildChainCard(int index, StainChain chain) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, child: Text('${index + 1}', style: const TextStyle(fontSize: _uniformFontSize - 2))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Chain Name (e.g. Anti-CD4 Panel)', border: InputBorder.none, isDense: true),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: _uniformFontSize),
                    controller: TextEditingController(text: chain.chainName)..selection = TextSelection.fromPosition(TextPosition(offset: chain.chainName.length)),
                    onChanged: (v) => _updateChain(index, chain.copyWith(chainName: v)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removeChain(index),
                ),
              ],
            ),
            const Divider(),
            _buildComponentRow(
              'Primary',
              chain.primary,
              onUpdate: (c) => _updateChain(index, chain.copyWith(primary: c)),
              showAddNext: chain.secondary == null,
              onAddNext: () => _updateChain(index, chain.copyWith(secondary: StainComponent(name: 'Secondary', level: StainLevel.secondary))),
            ),
            if (chain.secondary != null)
              _buildComponentRow(
                'Secondary',
                chain.secondary!,
                onUpdate: (c) => _updateChain(index, chain.copyWith(secondary: c)),
                onRemove: () => _updateChain(index, chain.copyWith(removeSecondary: true, removeTertiary: true)),
                showAddNext: chain.tertiary == null,
                onAddNext: () => _updateChain(index, chain.copyWith(tertiary: StainComponent(name: 'Tertiary', level: StainLevel.tertiary))),
              ),
            if (chain.tertiary != null)
              _buildComponentRow(
                'Tertiary',
                chain.tertiary!,
                onUpdate: (c) => _updateChain(index, chain.copyWith(tertiary: c)),
                onRemove: () => _updateChain(index, chain.copyWith(removeTertiary: true)),
              ),
            const Divider(),
            Row(
              children: [
                _buildMetadataField('Ex (nm)', chain.excitation?.toString() ?? '', (v) => _updateChain(index, chain.copyWith(excitation: double.tryParse(v)))),
                const SizedBox(width: 8),
                _buildMetadataField('Em (nm)', chain.emission?.toString() ?? '', (v) => _updateChain(index, chain.copyWith(emission: double.tryParse(v)))),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Laser / Channel', isDense: true, border: OutlineInputBorder()),
                    controller: TextEditingController(text: chain.channel)..selection = TextSelection.fromPosition(TextPosition(offset: chain.channel?.length ?? 0)),
                    onChanged: (v) => _updateChain(index, chain.copyWith(channel: v)),
                    style: const TextStyle(fontSize: _uniformFontSize),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentRow(
    String label,
    StainComponent component, {
    required Function(StainComponent) onUpdate,
    VoidCallback? onRemove,
    bool showAddNext = false,
    VoidCallback? onAddNext,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: _uniformFontSize - 3, color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(labelText: 'Stain Name', isDense: true),
              controller: TextEditingController(text: component.name)..selection = TextSelection.fromPosition(TextPosition(offset: component.name.length)),
              onChanged: (v) => onUpdate(component.copyWith(name: v)),
              style: const TextStyle(fontSize: _uniformFontSize),
            ),
          ),
          if (onRemove != null)
            IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.orange), onPressed: onRemove, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          if (showAddNext)
            TextButton.icon(
              onPressed: onAddNext,
              icon: const Icon(Icons.add_link, size: 16),
              label: const Text('Next', style: TextStyle(fontSize: _uniformFontSize - 3)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataField(String label, String value, Function(String) onChanged) {
    return Expanded(
      child: TextField(
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        controller: TextEditingController(text: value)..selection = TextSelection.fromPosition(TextPosition(offset: value.length)),
        onChanged: onChanged,
        style: const TextStyle(fontSize: _uniformFontSize),
      ),
    );
  }

  Widget _buildSampleCard(int sampleIndex, StainingSample sample) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.indigo.withValues(alpha: 0.2))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
            child: Row(
              children: [
                const Icon(Icons.science, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Sample Name', border: InputBorder.none, isDense: true),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: _uniformFontSize),
                    controller: TextEditingController(text: sample.sampleName)..selection = TextSelection.fromPosition(TextPosition(offset: sample.sampleName.length)),
                    onChanged: (v) => _updateSample(sampleIndex, sample.copyWith(sampleName: v)),
                  ),
                ),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _removeSample(sampleIndex)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Chains:', style: TextStyle(fontSize: _uniformFontSize - 3, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _wizard.panel.map((chain) {
                    final isSelected = sample.selectedChainIds.contains(chain.id);
                    return FilterChip(
                      label: Text(chain.chainName.isEmpty ? chain.primary.name : chain.chainName, style: const TextStyle(fontSize: _uniformFontSize - 2)),
                      selected: isSelected,
                      onSelected: (selected) {
                        final newList = List<String>.from(sample.selectedChainIds);
                        if (selected) {
                          newList.add(chain.id);
                        } else {
                          newList.remove(chain.id);
                        }
                        _updateSample(sampleIndex, sample.copyWith(selectedChainIds: newList));
                      },
                      selectedColor: Colors.indigo.shade100,
                      checkmarkColor: Colors.indigo,
                    );
                  }).toList(),
                ),
                if (_wizard.panel.isEmpty)
                  const Text('No chains defined in panel yet.', style: TextStyle(fontSize: _uniformFontSize - 3, fontStyle: FontStyle.italic, color: Colors.orange)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
