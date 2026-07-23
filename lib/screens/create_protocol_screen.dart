import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/protocol.dart';
import '../models/material.dart';
import '../models/protocol_additional_data.dart';
import '../models/protocol_step.dart';
import '../models/protocol_table.dart';
import '../models/master_mix_wizard.dart';
import '../features/master_mix/services/master_mix_calculator_service.dart';
import '../theme/app_colors.dart';
import '../widgets/protocol_table_widget.dart';
import '../widgets/protocol_table_preview.dart';
import '../widgets/protocol_step_actions_table.dart';
import '../widgets/protocol_step_notes_table.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/picked_image_store.dart';
import '../services/storage_service.dart';
import '../utils/protocol_id.dart';
import '../widgets/local_image.dart';
import 'table_selection_screen.dart';

class CreateProtocolScreen extends StatefulWidget {
  final Protocol? initialProtocol;
  final List<String>? lockedStepIds;
  final String? targetPhase;
  final bool isAddingPhase;

  const CreateProtocolScreen({
    super.key,
    this.initialProtocol,
    this.lockedStepIds,
    this.targetPhase,
    this.isAddingPhase = false,
  });

  @override
  State<CreateProtocolScreen> createState() => _CreateProtocolScreenState();
}

class _CreateProtocolScreenState extends State<CreateProtocolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _descriptionController = TextEditingController();
  final StorageService _storageService = StorageService();

  final List<MaterialItem> _materials = [];
  final List<String> _samples = [];
  final List<String> _files = [];
  final List<ProtocolStep> _steps = [];
  final List<ProtocolTable> _tables = [];
  final List<ProtocolAdditionalData> _additionalData = [];
  late String _materialListTableId;
  bool _isMaterialListCollapsed = false;
  bool _usePhases = false;
  late final bool _isInProgress;
  ProtocolStep? _stepClipboard;
  bool _stepClipboardWasCut = false;

  @override
  void initState() {
    super.initState();
    _isInProgress =
        widget.lockedStepIds != null && widget.lockedStepIds!.isNotEmpty;

    if (widget.initialProtocol != null) {
      final p = widget.initialProtocol!;
      _titleController.text = p.title;
      _objectiveController.text = p.objective;
      _descriptionController.text = p.description;
      _materials.addAll(p.materials.map((m) => m.copyWith()));
      _samples.addAll(p.samples);
      _files.addAll(p.files);
      _steps.addAll(p.steps.map((s) => s.deepCopy()));
      _tables.addAll(p.tables.map((t) => t.deepCopy()));
      _additionalData.addAll(p.additionalData.map((d) => d.deepCopy()));
      _usePhases = p.steps.any(
        (s) => s.phaseName != null && s.phaseName!.isNotEmpty,
      );
    }

    _ensureMaterialListTable(widget.initialProtocol?.materialListTableId);

    if (widget.isAddingPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addNewPhase();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _objectiveController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<ProtocolTable> get _regularTables =>
      _tables.where((table) => table.type != TableType.materialList).toList();

  ProtocolTable get _materialListTable =>
      _tables.firstWhere((table) => table.id == _materialListTableId);

  void _ensureMaterialListTable(String? linkedTableId) {
    var index = linkedTableId == null
        ? -1
        : _tables.indexWhere((table) => table.id == linkedTableId);
    if (index == -1) {
      index = _tables.indexWhere(
        (table) => table.type == TableType.materialList,
      );
    }
    if (index >= 0) {
      _materialListTableId = _tables[index].id;
      _syncLegacyMaterialsFromTable(_tables[index]);
      return;
    }

    _materialListTableId =
        linkedTableId ??
        'material_list_${DateTime.now().microsecondsSinceEpoch}';
    _tables.insert(
      0,
      createMaterialListTable(
        id: _materialListTableId,
        data: _materials
            .map<List<dynamic>>(
              (material) => [
                material.name,
                material.quantity,
                material.stockConcentration,
                material.catalogNumber,
                material.manufacturer,
              ],
            )
            .toList(),
      ),
    );
  }

  void _updateMaterialListTable(ProtocolTable updated) {
    final index = _tables.indexWhere(
      (table) => table.id == _materialListTableId,
    );
    if (index == -1) return;
    final normalized = updated.copyWith(
      id: _materialListTableId,
      type: TableType.materialList,
      title: updated.title.isEmpty ? 'Material List' : updated.title,
    );
    _tables[index] = normalized;
    _syncLegacyMaterialsFromTable(normalized);
  }

  void _syncLegacyMaterialsFromTable(ProtocolTable table) {
    final previous = List<MaterialItem>.from(_materials);
    _materials
      ..clear()
      ..addAll(
        table.data
            .asMap()
            .entries
            .where((entry) {
              return entry.value.any(
                (cell) => cell.toString().trim().isNotEmpty,
              );
            })
            .map((entry) {
              final row = entry.value;
              String valueAt(int index) =>
                  index < row.length ? row[index].toString() : '';
              return MaterialItem(
                id: entry.key < previous.length
                    ? previous[entry.key].id
                    : 'mat_${table.id}_${entry.key + 1}',
                name: valueAt(0),
                quantity: valueAt(1),
                stockConcentration: valueAt(2),
                catalogNumber: valueAt(3),
                manufacturer: valueAt(4),
                location: entry.key < previous.length
                    ? previous[entry.key].location
                    : '',
              );
            }),
      );
  }

  void _addNewSample() {
    setState(() {
      _samples.add('');
    });
  }

  void _addNewStep({String? phaseName, int? insertIndex}) {
    setState(() {
      final newStep = _createBlankStep(
        phaseName: phaseName,
        insertIndex: insertIndex,
      );
      if (insertIndex == null || insertIndex >= _steps.length) {
        _steps.add(newStep);
      } else {
        _steps.insert(insertIndex, newStep);
      }
    });
  }

  ProtocolStep _createBlankStep({String? phaseName, int? insertIndex}) {
    int nextDay = 1;
    String? currentPhase = phaseName;
    if (_steps.isNotEmpty) {
      final sourceIndex = insertIndex == null
          ? _steps.length - 1
          : (insertIndex - 1).clamp(0, _steps.length - 1);
      final sourceStep = _steps[sourceIndex];
      nextDay = sourceStep.day;
      currentPhase ??= sourceStep.phaseName;
    }
    return ProtocolStep(
      id: 'step_${DateTime.now().microsecondsSinceEpoch}',
      title: '',
      instructions: '',
      actionItems: [],
      materials: [],
      actionTimers: {},
      day: nextDay,
      phaseName: currentPhase,
    );
  }

  ProtocolStep _cloneStepForInsert(ProtocolStep step, {required bool fromCut}) {
    if (fromCut) return step.deepCopy();
    return step.deepCopy().copyWith(
      id: 'step_${DateTime.now().microsecondsSinceEpoch}',
      title: step.title.isEmpty ? '' : '${step.title} (Copy)',
    );
  }

  void _copyStep(int index) {
    setState(() {
      _stepClipboard = _steps[index].deepCopy();
      _stepClipboardWasCut = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Step copied')));
  }

  void _cutStep(int index) {
    setState(() {
      _stepClipboard = _steps.removeAt(index).deepCopy();
      _stepClipboardWasCut = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Step cut')));
  }

  void _pasteStepAfter(int index) {
    final step = _stepClipboard;
    if (step == null) return;
    setState(() {
      _steps.insert(
        index + 1,
        _cloneStepForInsert(step, fromCut: _stepClipboardWasCut),
      );
      if (_stepClipboardWasCut) {
        _stepClipboard = null;
        _stepClipboardWasCut = false;
      }
    });
  }

  void _addNewPhase() {
    final phaseCount = _steps.map((s) => s.phaseName).toSet().length + 1;
    final newPhaseName = 'Phase $phaseCount';
    _addNewStep(phaseName: newPhaseName);
  }

  void _addNewTable() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const TableSelectionScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        if (result is ProtocolTable) {
          final coloredTable = _withTableColor(result);
          _tables.add(coloredTable);
          _syncMaterialsFromTable(coloredTable);
        } else if (result is List<ProtocolTable>) {
          for (final table in result) {
            final coloredTable = _withTableColor(table);
            _tables.add(coloredTable);
            _syncMaterialsFromTable(coloredTable);
          }
        }
      });
    }
  }

  Future<void> _addAdditionalData() async {
    final result = await _showAdditionalDataDialog();
    if (result == null) return;
    setState(() => _additionalData.add(result));
  }

  Future<void> _editAdditionalData(int index) async {
    final result = await _showAdditionalDataDialog(
      initial: _additionalData[index],
    );
    if (result == null) return;
    setState(() => _additionalData[index] = result);
  }

  Future<ProtocolAdditionalData?> _showAdditionalDataDialog({
    ProtocolAdditionalData? initial,
  }) async {
    final titleController = TextEditingController(text: initial?.title ?? '');
    final descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    final linkController = TextEditingController(text: initial?.link ?? '');
    final photoPaths = List<String>.from(initial?.photoPaths ?? []);
    final picker = ImagePicker();

    try {
      return await showDialog<ProtocolAdditionalData>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> addImages(Future<List<XFile>> pick) async {
              final images = await pick;
              if (images.isEmpty) return;
              final stored = <String>[];
              for (final image in images) {
                stored.add(await PickedImageStore.persistPickedImage(image));
              }
              setDialogState(() => photoPaths.addAll(stored));
            }

            return AlertDialog(
              title: Text(
                initial == null
                    ? 'Add Additional Data'
                    : 'Edit Additional Data',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        autofocus: true,
                      ),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description / notes',
                        ),
                        maxLines: 3,
                      ),
                      TextField(
                        controller: linkController,
                        decoration: const InputDecoration(
                          labelText: 'Link',
                          hintText: 'https://...',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      if (photoPaths.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 3 / 4,
                              ),
                          itemCount: photoPaths.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: buildLocalImage(photoPaths[index]),
                                ),
                                Positioned(
                                  top: -10,
                                  right: -10,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => setDialogState(
                                      () => photoPaths.removeAt(index),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final photo = await picker.pickImage(
                                source: ImageSource.camera,
                              );
                              if (photo == null) return;
                              await addImages(Future.value([photo]));
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                          TextButton.icon(
                            onPressed: () => addImages(picker.pickMultiImage()),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();
                    final link = linkController.text.trim();
                    if (title.isEmpty &&
                        description.isEmpty &&
                        link.isEmpty &&
                        photoPaths.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }
                    Navigator.pop(
                      context,
                      ProtocolAdditionalData(
                        id:
                            initial?.id ??
                            'data_${DateTime.now().microsecondsSinceEpoch}',
                        title: title.isEmpty ? 'Additional Data' : title,
                        description: description,
                        link: link,
                        photoPaths: List<String>.from(photoPaths),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      linkController.dispose();
    }
  }

  ProtocolTable _withTableColor(ProtocolTable table) {
    if (table.metadata.containsKey('typeColor')) return table;
    return table.copyWith(
      metadata: {
        ...table.metadata,
        'typeColor': _tableTypeColor(table.type).toARGB32().toRadixString(16),
      },
    );
  }

  Color _tableColor(ProtocolTable table) {
    final savedColor = table.metadata['typeColor'];
    if (savedColor != null) {
      final parsed = int.tryParse(savedColor, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return _tableTypeColor(table.type);
  }

  Color _tableTypeColor(TableType type) {
    switch (type) {
      case TableType.masterMix:
        return Colors.blue;
      case TableType.staining:
        return Colors.indigo;
      case TableType.serialDilution:
        return Colors.cyan;
      case TableType.plateLayout:
        return Colors.orange;
      case TableType.checklist:
        return Colors.green;
      case TableType.materialList:
        return Colors.teal;
      case TableType.generic:
        return Colors.grey;
    }
  }

  void _syncMaterialsFromTable(ProtocolTable table) {
    if (table.type == TableType.materialList) {
      setState(() => _syncLegacyMaterialsFromTable(table));
      return;
    }
    // We re-sync all materials from all tables to ensure totals are correct
    final Map<String, double> totalVolumesUl = {};
    final Map<String, String> stockConcentrations = {};

    for (final t in _tables) {
      final wizardState = t.metadata['wizard_state'];
      if (wizardState == null) continue;

      if (t.type == TableType.masterMix) {
        try {
          final wizard = MasterMixWizard.fromJson(jsonDecode(wizardState));
          final calculator = MasterMixCalculatorService();
          for (final mix in wizard.mixes) {
            final result = calculator.calculateMasterMix(mix.toInput());

            if (result.success) {
              for (final r in result.reagentResults) {
                if (r.reagentName.isNotEmpty) {
                  totalVolumesUl[r.reagentName] =
                      (totalVolumesUl[r.reagentName] ?? 0) + r.reagentVolumeUl;
                  stockConcentrations[r.reagentName] =
                      r.formattedStockConcentration;
                }
              }
              if (mix.baseSolventName.isNotEmpty) {
                totalVolumesUl[mix.baseSolventName] =
                    (totalVolumesUl[mix.baseSolventName] ?? 0) +
                    result.baseSolventVolumeUl;
              }
            }
          }
        } catch (e) {
          debugPrint('Error syncing MasterMix: $e');
        }
      }
    }

    if (totalVolumesUl.isEmpty) return;

    setState(() {
      for (final entry in totalVolumesUl.entries) {
        final name = entry.key;
        final volUl = entry.value;
        final stock = stockConcentrations[name] ?? '';
        final qtyStr = _formatVolumeUl(volUl);

        final index = _materials.indexWhere(
          (m) => m.name.trim().toLowerCase() == name.trim().toLowerCase(),
        );
        if (index != -1) {
          // Update existing material quantity and stock conc
          _materials[index] = _materials[index].copyWith(
            quantity: qtyStr,
            stockConcentration: stock,
          );
        } else {
          // Add new material
          _materials.add(
            MaterialItem(
              id: 'mat_${DateTime.now().millisecondsSinceEpoch}_${_materials.length}',
              name: name,
              quantity: qtyStr,
              stockConcentration: stock,
            ),
          );
        }
      }
      _replaceMaterialListRowsFromLegacyMaterials();
    });
  }

  void _replaceMaterialListRowsFromLegacyMaterials() {
    final index = _tables.indexWhere(
      (table) => table.id == _materialListTableId,
    );
    if (index == -1) return;
    final rows = _materials
        .map<List<dynamic>>(
          (material) => [
            material.name,
            material.quantity,
            material.stockConcentration,
            material.catalogNumber,
            material.manufacturer,
          ],
        )
        .toList();
    _tables[index] = createMaterialListTable(
      id: _materialListTableId,
      data: rows,
    ).copyWith(title: _tables[index].title);
  }

  String _formatVolumeUl(double ul) {
    if (ul >= 1000000) {
      return '${(ul / 1000000).toStringAsFixed(2)} L';
    } else if (ul >= 1000) {
      return '${(ul / 1000).toStringAsFixed(2)} mL';
    } else if (ul >= 1) {
      return '${ul.toStringAsFixed(1)} µL';
    } else {
      return '${(ul * 1000).toStringAsFixed(0)} nL';
    }
  }

  bool _canActuallyPop = false;

  Future<bool?> _showExitConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProtocol({bool isTemplate = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _syncAllActionsFromInstructions();

    if (_formKey.currentState!.validate()) {
      bool isUpdating =
          widget.initialProtocol != null &&
          isTemplate == widget.initialProtocol!.isTemplate;

      final now = DateTime.now();
      final signedInUser = AuthService.instance.currentUser;
      String newId = isUpdating
          ? widget.initialProtocol!.id
          : generateProtocolId(initials: signedInUser?.initials);
      if (newId.trim().isEmpty) {
        newId = generateProtocolId(initials: signedInUser?.initials);
      }
      _syncLegacyMaterialsFromTable(_materialListTable);

      final newProtocol = Protocol(
        id: newId,
        title: _titleController.text,
        objective: _objectiveController.text,
        description: _descriptionController.text,
        // Future Drive sync will use ownerId with protocolId to locate the
        // user's remote protocol record without depending on editable names.
        ownerId: signedInUser?.googleUserId ?? widget.initialProtocol?.ownerId,
        createdByName:
            signedInUser?.displayName ??
            signedInUser?.email ??
            widget.initialProtocol?.createdByName,
        createdAt: isUpdating ? widget.initialProtocol!.createdAt : now,
        updatedAt: now,
        schemaVersion: Protocol.currentSchemaVersion,
        syncStatus: signedInUser == null
            ? ProtocolSyncStatus.localOnly
            : ProtocolSyncStatus.modified,
        materials: _materials.map((m) => m.copyWith()).toList(),
        materialListTableId: _materialListTableId,
        samples: List.from(_samples),
        files: List.from(_files),
        steps: _steps.map((s) => s.deepCopy()).toList(),
        tables: _tables.map((table) => table.deepCopy()).toList(),
        additionalData: _additionalData.map((d) => d.deepCopy()).toList(),
        isTemplate: isTemplate,
      );

      final existingProtocols = await _storageService.loadProtocols();
      if (isUpdating) {
        final index = existingProtocols.indexWhere((p) => p.id == newId);
        if (index != -1) {
          existingProtocols[index] = newProtocol;
        } else {
          existingProtocols.add(newProtocol);
        }
      } else {
        existingProtocols.add(newProtocol);
      }
      await _storageService.saveProtocols(existingProtocols);
      final savedProtocol = signedInUser == null
          ? newProtocol
          : await DriveSyncService.instance.syncProtocolAfterLocalSave(
              newProtocol,
            );

      if (mounted) {
        setState(() => _canActuallyPop = true);
        Navigator.pop(context, savedProtocol);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canActuallyPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog();
        if (shouldPop ?? false) {
          if (context.mounted) {
            setState(() => _canActuallyPop = true);
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialProtocol != null
                ? 'Edit Protocol'
                : 'Create Protocol',
          ),
          actions: [
            PopupMenuButton<bool>(
              icon: const Icon(Icons.save),
              onSelected: (isTemplate) => _saveProtocol(isTemplate: isTemplate),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: false,
                  child: ListTile(
                    leading: Icon(Icons.save_outlined),
                    title: Text('Save Protocol'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: true,
                  child: ListTile(
                    leading: Icon(Icons.copy_all),
                    title: Text('Save as Template'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldSection(
                  'Protocol Title',
                  _titleController,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter a title'
                      : null,
                ),
                const Divider(height: 32),

                _buildFieldSection('Objective', _objectiveController),
                _buildFieldSection(
                  'Description',
                  _descriptionController,
                  maxLines: 3,
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(indent: 24, endIndent: 24, thickness: 1),
                ),

                _buildSectionHeader('Samples'),
                const SizedBox(height: 8),
                ..._samples.asMap().entries.map((entry) {
                  final idx = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.grey)),
                        Expanded(
                          child: TextFormField(
                            initialValue: entry.value,
                            decoration: const InputDecoration(
                              hintText: 'Sample name (e.g. THP1 cell line)',
                              border: InputBorder.none,
                            ),
                            onChanged: (v) => _samples[idx] = v,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              setState(() => _samples.removeAt(idx)),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _addNewSample,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Sample'),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(indent: 24, endIndent: 24, thickness: 1),
                ),

                _buildSectionHeader('Material List'),
                const SizedBox(height: 8),
                _buildMaterialsTable(),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(indent: 24, endIndent: 24, thickness: 1),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Steps',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        const Text(
                          'Set Phases',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Switch(
                          value: _usePhases,
                          onChanged: _isInProgress
                              ? null
                              : (val) {
                                  setState(() {
                                    _usePhases = val;
                                    if (_usePhases && _steps.isNotEmpty) {
                                      // If enabling phases and we have steps, assign them to "Phase 1" if they don't have one
                                      for (int i = 0; i < _steps.length; i++) {
                                        if (_steps[i].phaseName == null ||
                                            _steps[i].phaseName!.isEmpty) {
                                          _steps[i] = _steps[i].copyWith(
                                            phaseName: 'Phase 1',
                                          );
                                        }
                                      }
                                    }
                                  });
                                },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._buildStepsSection(),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(indent: 24, endIndent: 24, thickness: 1),
                ),

                _buildSectionHeader('Tables'),
                const SizedBox(height: 8),
                if (_regularTables.isEmpty)
                  const Center(
                    child: Text(
                      'No tables added.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _regularTables.map((table) {
                      return Stack(
                        children: [
                          ProtocolTableWidget(
                            table: table,
                            isReadOnly: false,
                            onSave: (updated) {
                              setState(() {
                                final index = _tables.indexWhere(
                                  (candidate) => candidate.id == table.id,
                                );
                                if (index != -1) _tables[index] = updated;
                              });
                              _syncMaterialsFromTable(updated);
                            },
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _tables.removeWhere(
                                  (candidate) => candidate.id == table.id,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _addNewTable,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Table'),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Additional Data'),
                const SizedBox(height: 8),
                if (_additionalData.isEmpty)
                  const Center(
                    child: Text(
                      'No additional data added.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ..._additionalData.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final data = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          data.photoPaths.isNotEmpty
                              ? Icons.photo_library_outlined
                              : Icons.link,
                        ),
                        title: Text(data.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data.description.isNotEmpty)
                              Text(
                                data.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (data.link.isNotEmpty)
                              Text(
                                data.link,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.blue),
                              ),
                            if (data.photoPaths.isNotEmpty)
                              Text('${data.photoPaths.length} photo(s)'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editAdditionalData(idx),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  setState(() => _additionalData.removeAt(idx)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _addAdditionalData,
                    icon: const Icon(Icons.add_link),
                    label: const Text('Add Additional Data'),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldSection(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          readOnly: _isInProgress,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Enter text...',
            fillColor: _isInProgress ? Colors.grey.shade100 : null,
            filled: _isInProgress,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(title, style: Theme.of(context).textTheme.titleLarge)],
    );
  }

  List<Widget> _buildStepsSection() {
    if (!_usePhases) {
      return [
        ..._steps.asMap().entries.map(
          (entry) => _buildStepEditor(entry.key, entry.value),
        ),
        const SizedBox(height: 8),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _addNewStep(),
            icon: const Icon(Icons.add),
            label: const Text('Add Step'),
          ),
        ),
      ];
    }

    // Grouping by phases
    final List<Widget> items = [];

    String? currentPhase;
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      if (step.phaseName != currentPhase || i == 0) {
        currentPhase = step.phaseName;
        items.add(_buildPhaseHeader(currentPhase, i));
      }
      items.add(_buildStepEditor(i, step));

      // If next step is different phase or this is last step
      bool isLastInPhase =
          i == _steps.length - 1 || _steps[i + 1].phaseName != currentPhase;
      if (isLastInPhase) {
        final phaseSteps = _steps.where((s) => s.phaseName == currentPhase);
        final bool isPhaseLocked =
            phaseSteps.isNotEmpty &&
            phaseSteps.every(
              (s) => widget.lockedStepIds?.contains(s.id) ?? false,
            );

        if (!isPhaseLocked) {
          items.add(
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
              child: TextButton.icon(
                onPressed: () =>
                    _addNewStep(phaseName: currentPhase, insertIndex: i + 1),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Step to Phase'),
              ),
            ),
          );
        }
      }
    }

    items.add(const SizedBox(height: 16));
    items.add(
      Center(
        child: ElevatedButton.icon(
          onPressed: _addNewPhase,
          icon: const Icon(Icons.library_add),
          label: const Text('Add New Phase'),
        ),
      ),
    );

    return items;
  }

  Widget _buildPhaseHeader(String? phaseName, int firstStepIdx) {
    String displayName = phaseName ?? 'Unnamed Phase';
    // Determine if this phase is locked (all its steps are locked)
    final phaseSteps = _steps.where((s) => s.phaseName == phaseName);
    final bool isPhaseLocked =
        phaseSteps.isNotEmpty &&
        phaseSteps.every((s) => widget.lockedStepIds?.contains(s.id) ?? false);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPhaseLocked
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPhaseLocked
              ? Colors.grey.withValues(alpha: 0.3)
              : Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers,
            size: 18,
            color: isPhaseLocked ? Colors.grey : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PhaseNameField(
              initialValue: displayName,
              readOnly: isPhaseLocked,
              onChanged: (v) {
                // Update all steps in this phase
                setState(() {
                  for (int i = 0; i < _steps.length; i++) {
                    if (_steps[i].phaseName == phaseName) {
                      _steps[i] = _steps[i].copyWith(phaseName: v);
                    }
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsTable() {
    return ProtocolTablePreview(
      table: _materialListTable,
      isReadOnly: _isInProgress,
      onSave: _isInProgress
          ? null
          : (updated) => setState(() => _updateMaterialListTable(updated)),
      isCollapsed: _isMaterialListCollapsed,
      onCollapsedChanged: (collapsed) =>
          setState(() => _isMaterialListCollapsed = collapsed),
    );
  }

  static const double _uniformFontSize = 14.0;

  Widget _buildStepEditor(int index, ProtocolStep step) {
    final bool isLocked = widget.lockedStepIds?.contains(step.id) ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isLocked ? Colors.grey.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isLocked ? Colors.grey : null,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: step.title,
                    readOnly: isLocked,
                    decoration: const InputDecoration(
                      hintText: 'Step Title',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _uniformFontSize,
                      color: isLocked ? Colors.grey : null,
                    ),
                    onChanged: (v) =>
                        _steps[index] = _steps[index].copyWith(title: v),
                  ),
                ),
                if (!isLocked) _buildStepActions(index, step),
              ],
            ),
            Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus && !isLocked) {
                  _syncActionsFromInstructions(index);
                }
              },
              child: TextFormField(
                key: ValueKey('instructions_${step.id}_${step.instructions}'),
                initialValue: step.instructions,
                readOnly: isLocked,
                decoration: const InputDecoration(
                  hintText:
                      'Instructions...\nStart action lines with - and protocol note lines with *.',
                  border: InputBorder.none,
                ),
                maxLines: null,
                style: TextStyle(
                  fontSize: _uniformFontSize,
                  color: isLocked ? Colors.grey : null,
                ),
                onChanged: (v) =>
                    _steps[index] = _steps[index].copyWith(instructions: v),
              ),
            ),
            if (step.actionItems.isEmpty)
              const Text(
                'No actions yet. Start a description line with - and a space, then leave the field.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: _uniformFontSize - 2,
                ),
              )
            else ...[
              const SizedBox(height: 8),
              ProtocolStepActionsTable(
                actions: step.actionItems,
                isLocked: isLocked,
                trailingBuilder: (context, actionIndex) {
                  final timer = step.actionTimers[actionIndex] ?? 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timer > 0)
                        Chip(
                          avatar: const Icon(Icons.timer_outlined, size: 16),
                          label: Text(_formatTimer(timer)),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (!isLocked)
                        PopupMenuButton<String>(
                          tooltip: 'Action options',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            switch (value) {
                              case 'timer':
                                _showActionTimerDialog(
                                  index,
                                  actionIndex,
                                  timer,
                                );
                                break;
                              case 'moveUp':
                                _moveAction(index, actionIndex, -1);
                                break;
                              case 'moveDown':
                                _moveAction(index, actionIndex, 1);
                                break;
                              case 'delete':
                                _deleteAction(index, actionIndex);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'timer',
                              child: ListTile(
                                leading: Icon(
                                  timer > 0
                                      ? Icons.timer_outlined
                                      : Icons.timer_off_outlined,
                                ),
                                title: Text(
                                  timer > 0 ? 'Edit Timer' : 'Set Timer',
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'moveUp',
                              enabled: actionIndex > 0,
                              child: const ListTile(
                                leading: Icon(Icons.keyboard_arrow_up),
                                title: Text('Move Up'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'moveDown',
                              enabled:
                                  actionIndex < step.actionItems.length - 1,
                              child: const ListTile(
                                leading: Icon(Icons.keyboard_arrow_down),
                                title: Text('Move Down'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                title: Text('Delete Action'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Protocol Step Notes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: _uniformFontSize,
                color: isLocked ? Colors.grey : null,
              ),
            ),
            const SizedBox(height: 4),
            if (step.notes.isEmpty)
              const Text(
                'No protocol notes yet. Start a description line with * and a space, then leave the field.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: _uniformFontSize - 2,
                ),
              )
            else
              ProtocolStepNotesTable(
                notes: step.notes,
                isLocked: isLocked,
                onMove: (noteIndex, direction) =>
                    _moveProtocolStepNote(index, noteIndex, direction),
                onDelete: (noteIndex) =>
                    _deleteProtocolStepNote(index, noteIndex),
              ),
            if (_regularTables.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Linked Tables',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _uniformFontSize,
                  color: isLocked ? Colors.grey : null,
                ),
              ),
              const SizedBox(height: 8),
              if (step.tableIds.isEmpty)
                const Text(
                  'No tables linked to this step.',
                  style: TextStyle(
                    fontSize: _uniformFontSize - 2,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                LinkedProtocolTablesSection(
                  tables: _linkedTablesForStep(step),
                  isReadOnly: isLocked,
                  onSave: isLocked
                      ? null
                      : (updated) {
                          setState(() {
                            final idx = _tables.indexWhere(
                              (t) => t.id == updated.id,
                            );
                            if (idx != -1) _tables[idx] = updated;
                          });
                        },
                  showOrderControls: !isLocked,
                  onMoveUp: (tableIndex) =>
                      _moveLinkedTable(index, tableIndex, -1),
                  onMoveDown: (tableIndex) =>
                      _moveLinkedTable(index, tableIndex, 1),
                  onUnlink: isLocked
                      ? null
                      : (table) => _unlinkTableFromStep(index, table.id),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _regularTables
                    .where((t) => !step.tableIds.contains(t.id))
                    .map((t) {
                      final tableColor = _tableColor(t);
                      return ActionChip(
                        avatar: Icon(
                          _tableTypeIcon(t.type),
                          size: 16,
                          color: tableColor,
                        ),
                        label: Text(
                          t.title.isEmpty ? 'Untitled Table' : t.title,
                          style: const TextStyle(
                            fontSize: _uniformFontSize - 2,
                          ),
                        ),
                        side: BorderSide(
                          color: tableColor.withValues(alpha: 0.5),
                        ),
                        onPressed: isLocked
                            ? null
                            : () {
                                setState(() {
                                  final currentStep = _steps[index];
                                  final newTableIds = List<String>.from(
                                    currentStep.tableIds,
                                  )..add(t.id);
                                  _steps[index] = currentStep.copyWith(
                                    tableIds: newTableIds,
                                  );
                                });
                              },
                      );
                    })
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepActions(int index, ProtocolStep step) {
    return PopupMenuButton<String>(
      tooltip: 'Step actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'insertAbove':
            _addNewStep(phaseName: step.phaseName, insertIndex: index);
            break;
          case 'insert':
            _addNewStep(phaseName: step.phaseName, insertIndex: index + 1);
            break;
          case 'paste':
            _pasteStepAfter(index);
            break;
          case 'copy':
            _copyStep(index);
            break;
          case 'cut':
            _cutStep(index);
            break;
          case 'delete':
            setState(() => _steps.removeAt(index));
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'insertAbove',
          child: ListTile(
            leading: Icon(Icons.vertical_align_top),
            title: Text('Insert Step Above'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'insert',
          child: ListTile(
            leading: Icon(Icons.add),
            title: Text('Insert Step Below'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'paste',
          enabled: _stepClipboard != null,
          child: const ListTile(
            leading: Icon(Icons.content_paste),
            title: Text('Paste Step Below'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'copy',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('Copy Step'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'cut',
          child: ListTile(
            leading: Icon(Icons.content_cut),
            title: Text('Cut Step'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Step'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  IconData _tableTypeIcon(TableType type) {
    switch (type) {
      case TableType.masterMix:
        return Icons.biotech;
      case TableType.staining:
        return Icons.color_lens;
      case TableType.serialDilution:
        return Icons.water_drop;
      case TableType.plateLayout:
        return Icons.grid_on;
      case TableType.checklist:
        return Icons.checklist;
      case TableType.materialList:
        return Icons.inventory_2_outlined;
      case TableType.generic:
        return Icons.table_chart;
    }
  }

  void _syncAllActionsFromInstructions() {
    for (var i = 0; i < _steps.length; i++) {
      if (widget.lockedStepIds?.contains(_steps[i].id) ?? false) continue;
      _syncActionsFromInstructions(i, rebuild: false);
    }
  }

  void _syncActionsFromInstructions(int stepIndex, {bool rebuild = true}) {
    final step = _steps[stepIndex];
    final parsed = _extractActionsAndNotesFromInstructions(step.instructions);
    if (parsed.actions.isEmpty &&
        parsed.notes.isEmpty &&
        parsed.instructions == step.instructions.trim()) {
      return;
    }

    final newActions = [...step.actionItems, ...parsed.actions];
    final newNotes = [...step.notes, ...parsed.notes];
    final parsedTimers = _preserveTimers(
      oldActions: step.actionItems,
      oldTimers: step.actionTimers,
      newActions: newActions,
    );

    if (_listEquals(step.actionItems, newActions) &&
        _listEquals(step.notes, newNotes) &&
        step.instructions == parsed.instructions &&
        _mapEquals(step.actionTimers, parsedTimers)) {
      return;
    }

    void update() {
      _steps[stepIndex] = step.copyWith(
        instructions: parsed.instructions,
        actionItems: newActions,
        actionTimers: parsedTimers,
        notes: newNotes,
      );
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
  }

  ({List<String> actions, List<String> notes, String instructions})
  _extractActionsAndNotesFromInstructions(String instructions) {
    final actions = <String>[];
    final notes = <String>[];
    final current = <String>[];
    final keptInstructionLines = <String>[];
    _StepIntakeKind currentKind = _StepIntakeKind.none;

    void flushCurrent() {
      final text = current.join('\n').trim();
      if (text.isNotEmpty) {
        switch (currentKind) {
          case _StepIntakeKind.action:
            actions.add(text);
            break;
          case _StepIntakeKind.note:
            notes.add(text);
            break;
          case _StepIntakeKind.none:
            break;
        }
      }
      current.clear();
    }

    for (final line in instructions.split(RegExp(r'\r?\n'))) {
      final trimmedLeft = line.trimLeft();
      if (RegExp(r'^-\s+').hasMatch(trimmedLeft)) {
        flushCurrent();
        currentKind = _StepIntakeKind.action;
        current.add(trimmedLeft.substring(1).trim());
      } else if (RegExp(r'^\*\s+').hasMatch(trimmedLeft)) {
        flushCurrent();
        currentKind = _StepIntakeKind.note;
        current.add(trimmedLeft.substring(1).trim());
      } else if (RegExp(r'^[-*]\S').hasMatch(trimmedLeft)) {
        flushCurrent();
        currentKind = _StepIntakeKind.none;
        keptInstructionLines.add(line);
      } else if (currentKind != _StepIntakeKind.none) {
        current.add(line.trim());
      } else {
        keptInstructionLines.add(line);
      }
    }
    flushCurrent();

    return (
      actions: actions,
      notes: notes,
      instructions: keptInstructionLines.join('\n').trim(),
    );
  }

  Map<int, int> _preserveTimers({
    required List<String> oldActions,
    required Map<int, int> oldTimers,
    required List<String> newActions,
  }) {
    final timers = <int, int>{};
    final usedOldIndexes = <int>{};

    for (var newIndex = 0; newIndex < newActions.length; newIndex++) {
      for (var oldIndex = 0; oldIndex < oldActions.length; oldIndex++) {
        if (usedOldIndexes.contains(oldIndex)) continue;
        if (oldActions[oldIndex] != newActions[newIndex]) continue;

        final timer = oldTimers[oldIndex];
        if (timer != null && timer > 0) timers[newIndex] = timer;
        usedOldIndexes.add(oldIndex);
        break;
      }
    }

    return timers;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _moveAction(int stepIndex, int actionIndex, int delta) {
    final newIndex = actionIndex + delta;
    final step = _steps[stepIndex];
    if (newIndex < 0 || newIndex >= step.actionItems.length) return;

    setState(() {
      final actions = List<String>.from(step.actionItems);
      final action = actions.removeAt(actionIndex);
      actions.insert(newIndex, action);

      final timers = Map<int, int>.from(step.actionTimers);
      final movedTimer = timers.remove(actionIndex);
      final swappedTimer = timers.remove(newIndex);
      if (movedTimer != null) timers[newIndex] = movedTimer;
      if (swappedTimer != null) timers[actionIndex] = swappedTimer;

      _steps[stepIndex] = step.copyWith(
        actionItems: actions,
        actionTimers: timers,
      );
    });
  }

  void _deleteAction(int stepIndex, int actionIndex) {
    final step = _steps[stepIndex];
    setState(() {
      final actions = List<String>.from(step.actionItems)
        ..removeAt(actionIndex);
      final oldTimers = Map<int, int>.from(step.actionTimers)
        ..remove(actionIndex);
      final timers = <int, int>{};
      for (final entry in oldTimers.entries) {
        timers[entry.key > actionIndex ? entry.key - 1 : entry.key] =
            entry.value;
      }

      _steps[stepIndex] = step.copyWith(
        actionItems: actions,
        actionTimers: timers,
      );
    });
  }

  void _moveProtocolStepNote(int stepIndex, int noteIndex, int delta) {
    final newIndex = noteIndex + delta;
    final step = _steps[stepIndex];
    if (newIndex < 0 || newIndex >= step.notes.length) return;

    setState(() {
      final notes = List<String>.from(step.notes);
      final note = notes.removeAt(noteIndex);
      notes.insert(newIndex, note);
      _steps[stepIndex] = step.copyWith(notes: notes);
    });
  }

  void _deleteProtocolStepNote(int stepIndex, int noteIndex) {
    final step = _steps[stepIndex];
    setState(() {
      final notes = List<String>.from(step.notes)..removeAt(noteIndex);
      _steps[stepIndex] = step.copyWith(notes: notes);
    });
  }

  Future<void> _showActionTimerDialog(
    int stepIndex,
    int actionIndex,
    int initialTimer,
  ) async {
    var selectedTimer = initialTimer;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Action Timer'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return _ActionTimerInput(
              totalSeconds: selectedTimer,
              onChanged: (newTotal) =>
                  setDialogState(() => selectedTimer = newTotal),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 0),
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, selectedTimer),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    _updateActionTimer(stepIndex, actionIndex, result);
  }

  String _formatTimer(int totalSeconds) {
    if (totalSeconds >= 3600) {
      final hours = totalSeconds / 3600;
      return '${_formatTimerNumber(hours)} h';
    }
    if (totalSeconds >= 60) {
      final minutes = totalSeconds / 60;
      return '${_formatTimerNumber(minutes)} min';
    }
    return '$totalSeconds sec';
  }

  String _formatTimerNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _updateActionTimer(int stepIdx, int actionIdx, int totalSeconds) {
    setState(() {
      final step = _steps[stepIdx];
      final newTimers = Map<int, int>.from(step.actionTimers);
      if (totalSeconds > 0) {
        newTimers[actionIdx] = totalSeconds;
      } else {
        newTimers.remove(actionIdx);
      }
      _steps[stepIdx] = step.copyWith(actionTimers: newTimers);
    });
  }

  List<ProtocolTable> _linkedTablesForStep(ProtocolStep step) {
    final linkedTables = <ProtocolTable>[];
    for (final id in step.tableIds) {
      for (final table in _tables) {
        if (table.id == id) {
          linkedTables.add(table);
          break;
        }
      }
    }
    return linkedTables;
  }

  void _moveLinkedTable(int stepIndex, int tableIndex, int delta) {
    final newIndex = tableIndex + delta;
    final ids = List<String>.from(_steps[stepIndex].tableIds);
    if (newIndex < 0 || newIndex >= ids.length) return;

    setState(() {
      final id = ids.removeAt(tableIndex);
      ids.insert(newIndex, id);
      _steps[stepIndex] = _steps[stepIndex].copyWith(tableIds: ids);
    });
  }

  void _unlinkTableFromStep(int stepIndex, String tableId) {
    setState(() {
      final ids = List<String>.from(_steps[stepIndex].tableIds)
        ..remove(tableId);
      _steps[stepIndex] = _steps[stepIndex].copyWith(tableIds: ids);
    });
  }
}

enum _StepIntakeKind { none, action, note }

class _ActionTimerInput extends StatefulWidget {
  final int totalSeconds;
  final Function(int) onChanged;

  const _ActionTimerInput({
    required this.totalSeconds,
    required this.onChanged,
  });

  @override
  State<_ActionTimerInput> createState() => _ActionTimerInputState();
}

class _ActionTimerInputState extends State<_ActionTimerInput> {
  late String _unit;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _determineUnitAndValue();
  }

  void _determineUnitAndValue() {
    if (widget.totalSeconds == 0) {
      _unit = 'M';
      _controller = TextEditingController();
    } else if (widget.totalSeconds >= 3600) {
      _unit = 'H';
      _controller = TextEditingController(
        text: _formatDecimal(widget.totalSeconds / 3600),
      );
    } else if (widget.totalSeconds >= 60) {
      _unit = 'M';
      _controller = TextEditingController(
        text: _formatDecimal(widget.totalSeconds / 60),
      );
    } else {
      _unit = 'S';
      _controller = TextEditingController(text: widget.totalSeconds.toString());
    }
  }

  String _formatDecimal(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 45,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => _updateValue(),
          ),
        ),
        const SizedBox(width: 4),
        DropdownButton<String>(
          value: _unit,
          isDense: true,
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 13, color: Colors.black),
          items: const [
            DropdownMenuItem(value: 'H', child: Text('H')),
            DropdownMenuItem(value: 'M', child: Text('M')),
            DropdownMenuItem(value: 'S', child: Text('S')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _unit = v);
              _updateValue();
            }
          },
        ),
      ],
    );
  }

  void _updateValue() {
    final val = double.tryParse(_controller.text) ?? 0;
    int total = 0;
    if (_unit == 'H') {
      total = (val * 3600).round();
    } else if (_unit == 'M') {
      total = (val * 60).round();
    } else {
      total = val.round();
    }
    widget.onChanged(total);
  }
}

class _PhaseNameField extends StatefulWidget {
  final String initialValue;
  final bool readOnly;
  final Function(String) onChanged;

  const _PhaseNameField({
    required this.initialValue,
    this.readOnly = false,
    required this.onChanged,
  });

  @override
  State<_PhaseNameField> createState() => _PhaseNameFieldState();
}

class _PhaseNameFieldState extends State<_PhaseNameField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      if (_controller.text != widget.initialValue) {
        widget.onChanged(_controller.text);
      }
    }
  }

  @override
  void didUpdateWidget(_PhaseNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      readOnly: widget.readOnly,
      decoration: const InputDecoration(
        hintText: 'Phase Name (e.g. Day 1)',
        border: InputBorder.none,
        isDense: true,
      ),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: widget.readOnly ? Colors.grey : Colors.blue,
      ),
      onSubmitted: (v) {
        if (v != widget.initialValue) {
          widget.onChanged(v);
        }
      },
      onChanged: widget.onChanged,
    );
  }
}
