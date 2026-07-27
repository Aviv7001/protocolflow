import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
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
  final Set<String> _expandedCategories = {};
  final Set<String> _expandedSubcategories = {};

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Measuring Tools',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _buildResetAction(),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTools,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: _buildGroupedToolSections(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedToolSections() {
    if (_tools.isEmpty) {
      return [
        const SizedBox(height: 80),
        Center(
          child: Text(
            'No measuring tools configured.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ];
    }

    final categories = <String, List<MeasuringTool>>{};
    for (final tool in _tools) {
      categories.putIfAbsent(_categoryLabel(tool), () => []).add(tool);
    }

    final categoryOrder = ['Liquid', 'Solid'];
    final orderedCategories = [
      ...categoryOrder.where(categories.containsKey),
      ...categories.keys.where((category) => !categoryOrder.contains(category)),
    ];

    return [
      for (final category in orderedCategories)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCategorySection(category, categories[category]!),
        ),
    ];
  }

  Widget _buildCategorySection(String category, List<MeasuringTool> tools) {
    final activeCount = tools.where((tool) => tool.active).length;
    final isExpanded = _expandedCategories.contains(category);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            onTap: () => _toggleCategory(category),
            leading: Icon(_categoryIcon(category), color: AppColors.primary),
            title: Text(
              category,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('$activeCount/${tools.length} active'),
            trailing: IconButton(
              tooltip: isExpanded
                  ? 'Shrink $category tools'
                  : 'Expand $category tools',
              onPressed: () => _toggleCategory(category),
              icon: Icon(isExpanded ? Icons.unfold_less : Icons.unfold_more),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: _buildSubcategorySections(category, tools),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleCategory(String category) {
    setState(() {
      if (!_expandedCategories.remove(category)) {
        _expandedCategories.add(category);
      }
    });
  }

  List<Widget> _buildSubcategorySections(
    String category,
    List<MeasuringTool> tools,
  ) {
    final subcategories = <String, List<MeasuringTool>>{};
    for (final tool in tools) {
      subcategories.putIfAbsent(tool.toolType, () => []).add(tool);
    }
    final names = subcategories.keys.toList()
      ..sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
      );

    return [
      for (final name in names)
        Padding(
          padding: EdgeInsets.only(bottom: name == names.last ? 0 : 10),
          child: _buildSubcategorySection(category, name, subcategories[name]!),
        ),
    ];
  }

  Widget _buildSubcategorySection(
    String category,
    String subcategory,
    List<MeasuringTool> tools,
  ) {
    final key = '$category|$subcategory';
    final activeCount = tools.where((tool) => tool.active).length;
    final isExpanded = _expandedSubcategories.contains(key);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            dense: true,
            tileColor: AppColors.surfaceContainer,
            onTap: () => _toggleSubcategory(key),
            title: Text(
              subcategory,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('$activeCount/${tools.length} active'),
            trailing: IconButton(
              tooltip: isExpanded
                  ? 'Shrink $subcategory tools'
                  : 'Expand $subcategory tools',
              onPressed: () => _toggleSubcategory(key),
              icon: Icon(isExpanded ? Icons.unfold_less : Icons.unfold_more),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final tool in tools) ...[
                    _buildToolCard(tool),
                    if (tool != tools.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleSubcategory(String key) {
    setState(() {
      if (!_expandedSubcategories.remove(key)) {
        _expandedSubcategories.add(key);
      }
    });
  }

  Widget _buildToolCard(MeasuringTool tool) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tool.toolType} - rank ${tool.accuracyRank}',
                      style: Theme.of(context).textTheme.bodySmall,
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
            children: tool.isMassTool
                ? [
                    _infoChip('Min', _formatMassMg(tool.minMassMg)),
                    _infoChip(
                      'Preferred min',
                      _formatMassMg(tool.preferredMinMassMg),
                    ),
                    _infoChip('Max', _formatMassMg(tool.maxMassMg)),
                    _infoChip(
                      'Readability',
                      _formatMassMg(tool.incrementMassMg),
                    ),
                  ]
                : [
                    _infoChip('Min', '${tool.minVolumeUl} uL'),
                    _infoChip('Max', '${tool.maxVolumeUl} uL'),
                    _infoChip('Increment', '${tool.incrementUl} uL'),
                  ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Edit ${tool.toolName}',
                onPressed: () => _editTool(existing: tool),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete ${tool.toolName}',
                onPressed: () => _deleteTool(tool),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
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

  String _categoryLabel(MeasuringTool tool) {
    if (tool.isMassTool) return 'Solid';
    return tool.category.isEmpty ? 'Liquid' : tool.category;
  }

  IconData _categoryIcon(String category) {
    return category.toLowerCase() == 'solid'
        ? Icons.scale_outlined
        : Icons.water_drop_outlined;
  }

  String _formatMassMg(double? mg) {
    if (mg == null) return '-';
    if (mg >= 1000) return '${(mg / 1000).toStringAsFixed(3)} g';
    if (mg >= 1) return '${mg.toStringAsFixed(3)} mg';
    return '${(mg * 1000).toStringAsFixed(3)} ug';
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
  late final TextEditingController _preferredMinController;
  late final TextEditingController _maxController;
  late final TextEditingController _incrementController;
  late final TextEditingController _rankController;
  late String _category;
  late String _toolType;
  late bool _active;

  static const List<String> _categories = ['Liquid', 'Solid'];
  static const Map<String, List<String>> _toolTypes = {
    'Liquid': [
      'Micropipette',
      'serological pipette',
      'Measuring cylinder',
      'Custom',
    ],
    'Solid': [
      'Microbalance',
      'Analytical balance',
      'Top-loading balance',
      'Custom',
    ],
  };

  @override
  void initState() {
    super.initState();
    final tool = widget.tool;
    _category = tool?.category ?? 'Liquid';
    if (tool?.isMassTool ?? false) _category = 'Solid';
    _toolType = tool?.toolType ?? _toolTypes[_category]!.first;
    _nameController = TextEditingController(text: tool?.toolName ?? '');
    _minController = TextEditingController(
      text: _numberText(
        _category == 'Solid' ? tool?.minMassMg : tool?.minVolumeUl,
      ),
    );
    _preferredMinController = TextEditingController(
      text: _numberText(tool?.preferredMinMassMg),
    );
    _maxController = TextEditingController(
      text: _numberText(
        _category == 'Solid' ? tool?.maxMassMg : tool?.maxVolumeUl,
      ),
    );
    _incrementController = TextEditingController(
      text: _numberText(
        _category == 'Solid' ? tool?.incrementMassMg : tool?.incrementUl,
      ),
    );
    _rankController = TextEditingController(
      text: tool?.accuracyRank.toString() ?? '1',
    );
    _active = tool?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minController.dispose();
    _preferredMinController.dispose();
    _maxController.dispose();
    _incrementController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSolid = _category == 'Solid';
    final currentTypes = _toolTypes[_category]!;
    if (!currentTypes.contains(_toolType)) {
      _toolType = currentTypes.first;
    }

    return AlertDialog(
      title: Text(widget.tool == null ? 'Add Tool' : 'Edit Tool'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _category = value;
                  _toolType = _toolTypes[value]!.first;
                });
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _toolType,
              decoration: const InputDecoration(labelText: 'Subcategory'),
              items: currentTypes
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
              decoration: InputDecoration(
                labelText: isSolid
                    ? 'Minimum mass (mg)'
                    : 'Minimum volume (uL)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (isSolid)
              TextField(
                controller: _preferredMinController,
                decoration: const InputDecoration(
                  labelText: 'Preferred minimum mass (mg)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            TextField(
              controller: _maxController,
              decoration: InputDecoration(
                labelText: isSolid
                    ? 'Maximum mass (mg)'
                    : 'Maximum volume (uL)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _incrementController,
              decoration: InputDecoration(
                labelText: isSolid ? 'Readability (mg)' : 'Increment (uL)',
              ),
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
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final min = double.tryParse(_minController.text);
    final preferredMin = double.tryParse(_preferredMinController.text);
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

    final isSolid = _category == 'Solid';
    Navigator.pop(
      context,
      MeasuringTool(
        id: widget.tool?.id ?? 'tool_${DateTime.now().millisecondsSinceEpoch}',
        category: _category,
        toolType: _toolType,
        toolName: _nameController.text.trim(),
        unit: isSolid ? 'mg' : 'uL',
        minVolumeUl: isSolid ? 0 : min,
        maxVolumeUl: isSolid ? 0 : max,
        incrementUl: isSolid ? 0 : increment,
        minMassMg: isSolid ? min : null,
        preferredMinMassMg: isSolid ? preferredMin : null,
        maxMassMg: isSolid ? max : null,
        incrementMassMg: isSolid ? increment : null,
        accuracyRank: rank,
        active: _active,
      ),
    );
  }

  String _numberText(double? value) {
    if (value == null || value == 0) return '';
    return value.toString();
  }
}
