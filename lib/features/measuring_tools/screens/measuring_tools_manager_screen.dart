import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/protocolflow_app_bar.dart';
import '../../../widgets/protocolflow_ui.dart';
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
          : ProtocolFlowAppBar(
              title: 'Measuring Tools',
              actions: [_buildResetAction()],
            ),
      body: ProtocolFlowContentBoundary(
        child: RefreshIndicator(
          onRefresh: _loadTools,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              if (widget.embedded)
                ProtocolFlowScreenHeader(
                  title: 'Measuring Tools',
                  subtitle: 'Configure the equipment used in calculations.',
                  actions: [_buildResetAction()],
                )
              else
                const Text(
                  'Configure the equipment used in calculations.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _editTool(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Tool'),
                ),
              ),
              const SizedBox(height: 24),
              ..._buildToolSections(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildToolSections() {
    if (_tools.isEmpty) {
      return [
        ProtocolFlowEmptyState(
          icon: Icons.straighten_outlined,
          title: 'No measuring tools configured.',
          message: 'Add the equipment available in your lab.',
          actionLabel: 'Add Tool',
          onAction: () => _editTool(),
        ),
      ];
    }

    final categories = <String, List<MeasuringTool>>{};
    for (final tool in _tools) {
      categories.putIfAbsent(_categoryLabel(tool), () => []).add(tool);
    }

    for (final tools in categories.values) {
      tools.sort((left, right) {
        final type = left.toolType.toLowerCase().compareTo(
          right.toolType.toLowerCase(),
        );
        return type != 0
            ? type
            : left.toolName.toLowerCase().compareTo(
                right.toolName.toLowerCase(),
              );
      });
    }

    const categoryOrder = ['Liquid', 'Solid'];
    final orderedCategories = [
      ...categoryOrder.where(categories.containsKey),
      ...categories.keys.where((category) => !categoryOrder.contains(category)),
    ];

    return [
      for (var index = 0; index < orderedCategories.length; index++) ...[
        _buildToolSection(
          orderedCategories[index],
          categories[orderedCategories[index]]!,
        ),
        if (index < orderedCategories.length - 1) const SizedBox(height: 20),
      ],
    ];
  }

  Widget _buildToolSection(String category, List<MeasuringTool> tools) {
    final activeCount = tools.where((tool) => tool.active).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '${category.toUpperCase()}  $activeCount/${tools.length} ACTIVE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < tools.length; index++) ...[
                _buildToolTile(tools[index]),
                if (index < tools.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolTile(MeasuringTool tool) {
    final color = tool.active ? AppColors.primary : AppColors.textDisabled;
    return ListTile(
      key: Key('measuring-tool-${tool.id}'),
      leading: Icon(
        tool.isMassTool ? Icons.scale_outlined : Icons.straighten_outlined,
        color: color,
      ),
      title: Text(tool.toolName),
      subtitle: Text(_toolSubtitle(tool)),
      onTap: () => _editTool(existing: tool),
      trailing: PopupMenuButton<_ToolAction>(
        tooltip: 'Manage ${tool.toolName}',
        onSelected: (action) => _handleToolAction(tool, action),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _ToolAction.edit,
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _ToolAction.toggleActive,
            child: ListTile(
              leading: Icon(
                tool.active
                    ? Icons.pause_circle_outline
                    : Icons.check_circle_outline,
              ),
              title: Text(tool.active ? 'Deactivate' : 'Activate'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: _ToolAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete', style: TextStyle(color: AppColors.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleToolAction(MeasuringTool tool, _ToolAction action) async {
    switch (action) {
      case _ToolAction.edit:
        await _editTool(existing: tool);
      case _ToolAction.toggleActive:
        await _saveTools([
          for (final item in _tools)
            if (item.id == tool.id)
              item.copyWith(active: !item.active)
            else
              item,
        ]);
      case _ToolAction.delete:
        await _deleteTool(tool);
    }
  }

  String _toolSubtitle(MeasuringTool tool) {
    if (tool.isMassTool) {
      return '${tool.toolType} - ${_formatMassMg(tool.minMassMg)}-${_formatMassMg(tool.maxMassMg)} - ${tool.active ? 'Active' : 'Inactive'}';
    }
    return '${tool.toolType} - ${tool.minVolumeUl}-${tool.maxVolumeUl} uL - ${tool.active ? 'Active' : 'Inactive'}';
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

  String _categoryLabel(MeasuringTool tool) {
    if (tool.isMassTool) return 'Solid';
    return tool.category.isEmpty ? 'Liquid' : tool.category;
  }

  String _formatMassMg(double? mg) {
    if (mg == null) return '-';
    if (mg >= 1000) return '${(mg / 1000).toStringAsFixed(3)} g';
    if (mg >= 1) return '${mg.toStringAsFixed(3)} mg';
    return '${(mg * 1000).toStringAsFixed(3)} ug';
  }
}

enum _ToolAction { edit, toggleActive, delete }

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
