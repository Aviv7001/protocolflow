import 'package:flutter/material.dart';

import '../models/measuring_tool.dart';
import '../services/measuring_tool_service.dart';

class MeasuringToolsManagerScreen extends StatefulWidget {
  final bool embedded;
  const MeasuringToolsManagerScreen({super.key, this.embedded = false});

  @override
  State<MeasuringToolsManagerScreen> createState() =>
      _MeasuringToolsManagerScreenState();
}

class _MeasuringToolsManagerScreenState
    extends State<MeasuringToolsManagerScreen> {
  final MeasuringToolService _service = MeasuringToolService.instance;
  List<MeasuringTool> _tools = const [];

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  Future<void> _loadTools() async {
    final tools = await _service.loadTools();
    if (!mounted) return;
    setState(() => _tools = tools);
  }

  Future<void> _saveTools(List<MeasuringTool> tools) async {
    await _service.saveTools(tools);
    if (!mounted) return;
    setState(() => _tools = tools);
  }

  Future<void> _editTool({MeasuringTool? existing}) async {
    final tool = await showDialog<MeasuringTool>(
      context: context,
      builder: (context) => _MeasuringToolDialog(tool: existing),
    );
    if (tool == null) return;

    final updated = [..._tools];
    final index = updated.indexWhere((item) => item.id == tool.id);
    if (index == -1) {
      updated.add(tool);
    } else {
      updated[index] = tool;
    }
    await _saveTools(updated);
  }

  Future<void> _deleteTool(MeasuringTool tool) async {
    final updated = _tools.where((item) => item.id != tool.id).toList();
    await _saveTools(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Measuring Tools'),
              actions: [_buildResetAction()],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTool(),
        icon: const Icon(Icons.add),
        label: const Text('Add Tool'),
      ),
      body: Column(
        children: [
          if (widget.embedded)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildResetAction(),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _tools.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tool = _tools[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tool.toolName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${tool.toolType} • rank ${tool.accuracyRank}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: tool.active,
                              onChanged: (value) async {
                                await _saveTools([
                                  for (final item in _tools)
                                    if (item.id == tool.id)
                                      item.copyWith(active: value)
                                    else
                                      item,
                                ]);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _infoChip('Min', '${tool.minVolumeUl} uL'),
                            _infoChip('Max', '${tool.maxVolumeUl} uL'),
                            _infoChip('Increment', '${tool.incrementUl} uL'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _editTool(existing: tool),
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: () => _deleteTool(tool),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetAction() {
    return IconButton(
      tooltip: 'Reset to default tools',
      onPressed: () async {
        await _service.resetToDefaults();
        await _loadTools();
      },
      icon: const Icon(Icons.restart_alt),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _MeasuringToolDialog extends StatefulWidget {
  final MeasuringTool? tool;

  const _MeasuringToolDialog({this.tool});

  @override
  State<_MeasuringToolDialog> createState() => _MeasuringToolDialogState();
}

class _MeasuringToolDialogState extends State<_MeasuringToolDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final TextEditingController _incrementController;
  late final TextEditingController _rankController;
  late String _toolType;
  late bool _active;

  static const List<String> _toolTypes = [
    'Micropipette',
    'serological pipette',
    'Measuring cylinder',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    final tool = widget.tool;
    _nameController = TextEditingController(text: tool?.toolName ?? '');
    _minController = TextEditingController(
      text: tool?.minVolumeUl.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: tool?.maxVolumeUl.toString() ?? '',
    );
    _incrementController = TextEditingController(
      text: tool?.incrementUl.toString() ?? '',
    );
    _rankController = TextEditingController(
      text: tool?.accuracyRank.toString() ?? '1',
    );
    _toolType = tool?.toolType ?? 'Micropipette';
    _active = tool?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _incrementController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tool == null ? 'Add Tool' : 'Edit Tool'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _toolType,
              decoration: const InputDecoration(labelText: 'Tool type'),
              items: _toolTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _toolType = value);
              },
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tool name'),
            ),
            TextField(
              controller: _minController,
              decoration: const InputDecoration(
                labelText: 'Minimum volume (uL)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _maxController,
              decoration: const InputDecoration(
                labelText: 'Maximum volume (uL)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _incrementController,
              decoration: const InputDecoration(labelText: 'Increment (uL)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _rankController,
              decoration: const InputDecoration(labelText: 'Accuracy rank'),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: const Text('Active'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final min = double.tryParse(_minController.text);
            final max = double.tryParse(_maxController.text);
            final increment = double.tryParse(_incrementController.text);
            final rank = int.tryParse(_rankController.text);
            if (_nameController.text.trim().isEmpty ||
                min == null ||
                max == null ||
                increment == null ||
                rank == null) {
              return;
            }
            Navigator.pop(
              context,
              MeasuringTool(
                id:
                    widget.tool?.id ??
                    'tool_${DateTime.now().millisecondsSinceEpoch}',
                toolType: _toolType,
                toolName: _nameController.text.trim(),
                minVolumeUl: min,
                maxVolumeUl: max,
                incrementUl: increment,
                accuracyRank: rank,
                active: _active,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
