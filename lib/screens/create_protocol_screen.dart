import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/protocol.dart';
import '../models/protocol_publication.dart';
import '../models/project.dart';
import '../models/material.dart';
import '../models/protocol_additional_data.dart';
import '../models/protocol_step.dart';
import '../models/protocol_table.dart';
import '../models/master_mix_wizard.dart';
import '../features/master_mix/services/master_mix_calculator_service.dart';
import '../theme/app_colors.dart';
import '../widgets/protocol_table_preview.dart';
import '../widgets/protocol_step_actions_table.dart';
import '../widgets/protocol_step_notes_table.dart';
import '../widgets/protocolflow_app_bar.dart';
import '../widgets/protocolflow_ui.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/picked_image_store.dart';
import '../services/storage_service.dart';
import '../utils/protocol_id.dart';
import '../widgets/local_image.dart';
import 'table_selection_screen.dart';

class CreateProtocolScreen extends StatefulWidget {
  final Protocol? initialProtocol;
  final String? initialProjectId;
  final List<String>? lockedStepIds;
  final String? targetPhase;
  final bool isAddingPhase;

  const CreateProtocolScreen({
    super.key,
    this.initialProtocol,
    this.initialProjectId,
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
  List<Project> _projects = [];
  String? _selectedProjectId;
  late String _materialListTableId;
  bool _isMaterialListCollapsed = false;
  bool _usePhases = false;
  late final bool _isInProgress;
  ProtocolStep? _stepClipboard;
  bool _stepClipboardWasCut = false;
  final Map<String, FocusNode> _instructionFocusNodes = {};
  final Map<String, int> _instructionFieldVersions = {};

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
      _selectedProjectId = (p.projectId == null || p.projectId!.isEmpty)
          ? null
          : p.projectId;
      _materials.addAll(p.materials.map((m) => m.copyWith()));
      _samples.addAll(p.samples);
      _files.addAll(p.files);
      _steps.addAll(p.steps.map((s) => s.deepCopy()));
      _tables.addAll(p.tables.map((t) => t.deepCopy()));
      _additionalData.addAll(p.additionalData.map((d) => d.deepCopy()));
      _usePhases = p.steps.any(
        (s) => s.phaseName != null && s.phaseName!.isNotEmpty,
      );
    } else {
      _selectedProjectId = widget.initialProjectId;
    }

    _ensureMaterialListTable(widget.initialProtocol?.materialListTableId);
    _loadProjects();

    if (widget.isAddingPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addNewPhase();
      });
    }
  }

  Future<void> _loadProjects() async {
    final projects = await _storageService.loadProjects();
    if (mounted) setState(() => _projects = projects);
  }

  @override
  void dispose() {
    for (final focusNode in _instructionFocusNodes.values) {
      focusNode.dispose();
    }
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
    setState(() {
      final marker = '__new_phase_${DateTime.now().microsecondsSinceEpoch}';
      _steps.add(_createBlankStep(phaseName: marker));
      _renumberDefaultPhases(insertedMarker: marker);
    });
  }

  List<({String? name, int start, int end})> _phaseRanges() {
    if (_steps.isEmpty) return [];
    final ranges = <({String? name, int start, int end})>[];
    var start = 0;
    var phaseName = _steps.first.phaseName;
    for (var index = 1; index < _steps.length; index++) {
      if (_steps[index].phaseName == phaseName) continue;
      ranges.add((name: phaseName, start: start, end: index - 1));
      start = index;
      phaseName = _steps[index].phaseName;
    }
    ranges.add((name: phaseName, start: start, end: _steps.length - 1));
    return ranges;
  }

  bool _rangeContainsLockedStep(({String? name, int start, int end}) range) {
    for (var index = range.start; index <= range.end; index++) {
      if (widget.lockedStepIds?.contains(_steps[index].id) ?? false) {
        return true;
      }
    }
    return false;
  }

  void _renumberDefaultPhases({String? insertedMarker}) {
    final defaultPhaseName = RegExp(r'^Phase \d+$');
    final ranges = _phaseRanges();
    for (var phaseIndex = 0; phaseIndex < ranges.length; phaseIndex++) {
      final range = ranges[phaseIndex];
      final shouldRenumber =
          range.name == insertedMarker ||
          (range.name != null && defaultPhaseName.hasMatch(range.name!));
      if (!shouldRenumber) continue;
      final name = 'Phase ${phaseIndex + 1}';
      for (var stepIndex = range.start; stepIndex <= range.end; stepIndex++) {
        _steps[stepIndex] = _steps[stepIndex].copyWith(phaseName: name);
      }
    }
  }

  void _insertPhaseAfterStep(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= _steps.length - 1) return;
    final sourcePhase = _steps[stepIndex].phaseName;
    if (_steps[stepIndex + 1].phaseName != sourcePhase) return;

    var endIndex = stepIndex + 1;
    while (endIndex + 1 < _steps.length &&
        _steps[endIndex + 1].phaseName == sourcePhase) {
      endIndex++;
    }
    for (var index = stepIndex + 1; index <= endIndex; index++) {
      if (widget.lockedStepIds?.contains(_steps[index].id) ?? false) return;
    }

    setState(() {
      final marker = '__new_phase_${DateTime.now().microsecondsSinceEpoch}';
      for (var index = stepIndex + 1; index <= endIndex; index++) {
        _steps[index] = _steps[index].copyWith(phaseName: marker);
      }
      _renumberDefaultPhases(insertedMarker: marker);
    });
  }

  void _movePhase(int firstStepIndex, int direction) {
    final ranges = _phaseRanges();
    final phaseIndex = ranges.indexWhere(
      (range) => range.start == firstStepIndex,
    );
    if (phaseIndex <= 0 || (direction != -1 && direction != 1)) return;

    final currentRange = ranges[phaseIndex];
    final previousRange = ranges[phaseIndex - 1];
    final movingUp = direction == -1;
    final donorRange = movingUp ? previousRange : currentRange;
    if (donorRange.end == donorRange.start ||
        _rangeContainsLockedStep(currentRange) ||
        _rangeContainsLockedStep(previousRange)) {
      return;
    }

    setState(() {
      final transferredStepIndex = movingUp
          ? previousRange.end
          : currentRange.start;
      final targetPhaseName = movingUp ? currentRange.name : previousRange.name;
      _steps[transferredStepIndex] = _steps[transferredStepIndex].copyWith(
        phaseName: targetPhaseName,
      );
    });
  }

  Future<void> _deletePhase(int firstStepIndex) async {
    final ranges = _phaseRanges();
    final phaseIndex = ranges.indexWhere(
      (range) => range.start == firstStepIndex,
    );
    if (phaseIndex < 0 || _rangeContainsLockedStep(ranges[phaseIndex])) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete phase?'),
        content: Text(
          ranges.length == 1
              ? 'The phase grouping will be removed. All protocol steps will be preserved.'
              : 'The phase will be merged with the adjacent phase. All protocol steps will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete phase'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      if (ranges.length == 1) {
        _usePhases = false;
        for (var index = 0; index < _steps.length; index++) {
          _steps[index] = _steps[index].copyWith(clearPhaseName: true);
        }
        return;
      }

      final targetRange = phaseIndex > 0
          ? ranges[phaseIndex - 1]
          : ranges[phaseIndex + 1];
      final sourceRange = ranges[phaseIndex];
      for (var index = sourceRange.start; index <= sourceRange.end; index++) {
        _steps[index] = _steps[index].copyWith(phaseName: targetRange.name);
      }
      _renumberDefaultPhases();
    });
  }

  void _addNewTable() async {
    final result = await showTableToolPicker(context);

    if (result != null) {
      setState(() {
        final coloredTable = _withTableColor(result);
        _tables.add(coloredTable);
        _syncMaterialsFromTable(coloredTable);
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
                                      color: AppColors.error,
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
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
        projectId: _selectedProjectId,
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
        publication: isUpdating && widget.initialProtocol!.publication != null
            ? widget.initialProtocol!.publication!.copyWith(
                status: ProtocolPublicationStatus.changesUnpublished,
              )
            : null,
        importSource: isUpdating ? widget.initialProtocol!.importSource : null,
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
        backgroundColor: AppColors.scaffoldBackground,
        appBar: ProtocolFlowAppBar(
          title: 'Protocol Builder',
          actions: [
            PopupMenuButton<bool>(
              tooltip: 'Save protocol',
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1000;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 24 : 12,
                  desktop ? 24 : 16,
                  desktop ? 24 : 12,
                  80,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: _buildBuilderWorkspace(desktop: desktop),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBuilderWorkspace({required bool desktop}) {
    final status = widget.initialProtocol == null
        ? 'NEW PROTOCOL'
        : widget.initialProtocol!.isTemplate
        ? 'EDITING TEMPLATE'
        : 'EDITING PROTOCOL';
    final statusIcon = widget.initialProtocol?.isTemplate ?? false
        ? Icons.copy_all_outlined
        : Icons.edit_note_outlined;

    final statusBadge = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('protocol-builder-status'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              status,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statusBadge,
          const SizedBox(height: 20),
          _buildProtocolInformationSection(),
          const SizedBox(height: 24),
          _buildSamplesSection(),
          const SizedBox(height: 24),
          _buildMaterialsSection(),
          const SizedBox(height: 24),
          _buildStepsArea(),
          const SizedBox(height: 24),
          _buildTablesSection(),
          const SizedBox(height: 24),
          _buildAdditionalDataSection(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        statusBadge,
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProtocolInformationSection(),
                  const SizedBox(height: 24),
                  _buildTablesSection(),
                  const SizedBox(height: 24),
                  _buildAdditionalDataSection(),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSamplesSection(),
                  const SizedBox(height: 24),
                  _buildMaterialsSection(),
                  const SizedBox(height: 24),
                  _buildStepsArea(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProtocolInformationSection() {
    return _buildSectionSurface(
      key: const Key('builder-protocol-information'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Protocol Information'),
          const SizedBox(height: 16),
          _buildProtocolTitleSection(),
          _buildFieldSection('Objective', _objectiveController, maxLines: 2),
          _buildFieldSection(
            'Description',
            _descriptionController,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildSamplesSection() {
    return _buildSectionSurface(
      key: const Key('builder-samples'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Samples'),
          const SizedBox(height: 12),
          if (_samples.isEmpty)
            _buildEmptyState('No samples added.')
          else
            ..._samples.asMap().entries.map((entry) {
              final index = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.biotech_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: entry.value,
                        readOnly: _isInProgress,
                        decoration: const InputDecoration(
                          hintText: 'Sample name (e.g. THP1 cell line)',
                        ),
                        onChanged: (value) => _samples[index] = value,
                      ),
                    ),
                    if (!_isInProgress)
                      IconButton(
                        tooltip: 'Remove sample',
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: AppColors.error,
                        ),
                        onPressed: () =>
                            setState(() => _samples.removeAt(index)),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _isInProgress ? null : _addNewSample,
              icon: const Icon(Icons.add),
              label: const Text('Add Sample'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsSection() {
    return _buildSectionSurface(
      key: const Key('builder-materials'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Material List'),
          const SizedBox(height: 10),
          _buildMaterialsTable(),
        ],
      ),
    );
  }

  Widget _buildStepsArea() {
    return _buildSectionSurface(
      key: const Key('builder-steps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final phases = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Set Phases',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Switch(
                    value: _usePhases,
                    onChanged: _isInProgress ? null : _setPhasesEnabled,
                  ),
                ],
              );
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildSectionHeader('Steps'), phases],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildSectionHeader('Steps')),
                  phases,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ..._buildStepsSection(),
        ],
      ),
    );
  }

  void _setPhasesEnabled(bool enabled) {
    setState(() {
      _usePhases = enabled;
      if (_steps.isEmpty) return;
      if (!_usePhases) {
        for (var index = 0; index < _steps.length; index++) {
          _steps[index] = _steps[index].copyWith(clearPhaseName: true);
        }
        return;
      }
      for (var index = 0; index < _steps.length; index++) {
        if (_steps[index].phaseName == null ||
            _steps[index].phaseName!.isEmpty) {
          _steps[index] = _steps[index].copyWith(phaseName: 'Phase 1');
        }
      }
    });
  }

  Widget _buildTablesSection() {
    return _buildSectionSurface(
      key: const Key('builder-tables'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Tables'),
          const SizedBox(height: 10),
          if (_regularTables.isEmpty)
            _buildEmptyState('No tables added.')
          else
            LinkedProtocolTablesSection(
              tables: _regularTables,
              isReadOnly: _isInProgress,
              initiallyCollapsed: true,
              onSave: _isInProgress
                  ? null
                  : (updated) {
                      setState(() {
                        final index = _tables.indexWhere(
                          (candidate) => candidate.id == updated.id,
                        );
                        if (index != -1) _tables[index] = updated;
                      });
                      _syncMaterialsFromTable(updated);
                    },
              onDelete: _isInProgress ? null : _removeTable,
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _isInProgress ? null : _addNewTable,
              icon: const Icon(Icons.add),
              label: const Text('Add Table'),
            ),
          ),
        ],
      ),
    );
  }

  void _removeTable(ProtocolTable table) {
    setState(() {
      _tables.removeWhere((candidate) => candidate.id == table.id);
      for (var index = 0; index < _steps.length; index++) {
        _steps[index] = _steps[index].copyWith(
          tableIds: _steps[index].tableIds
              .where((id) => id != table.id)
              .toList(),
        );
      }
    });
  }

  Widget _buildAdditionalDataSection() {
    return _buildSectionSurface(
      key: const Key('builder-additional-data'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Additional Data'),
          const SizedBox(height: 10),
          if (_additionalData.isEmpty)
            _buildEmptyState('No additional data added.')
          else
            ..._additionalData.asMap().entries.map((entry) {
              final index = entry.key;
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
                          style: const TextStyle(color: AppColors.info),
                        ),
                      if (data.photoPaths.isNotEmpty)
                        Text('${data.photoPaths.length} photo(s)'),
                    ],
                  ),
                  trailing: _isInProgress
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit additional data',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editAdditionalData(index),
                            ),
                            IconButton(
                              tooltip: 'Delete additional data',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () => setState(
                                () => _additionalData.removeAt(index),
                              ),
                            ),
                          ],
                        ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _isInProgress ? null : _addAdditionalData,
              icon: const Icon(Icons.add_link),
              label: const Text('Add Additional Data'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSurface({Key? key, required Widget child}) {
    final expanded = MediaQuery.sizeOf(context).width >= 1000;
    return Card(
      key: key,
      margin: EdgeInsets.zero,
      child: Padding(padding: EdgeInsets.all(expanded ? 24 : 16), child: child),
    );
  }

  Widget _buildEmptyState(String message) {
    return ProtocolFlowEmptyState(message: message);
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
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          readOnly: _isInProgress,
          decoration: InputDecoration(
            hintText: 'Enter text...',
            fillColor: _isInProgress ? Colors.grey.shade100 : null,
            filled: _isInProgress,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProtocolTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final label = Text(
              'Protocol Title',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            );
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: 8),
                  _buildProjectMenuChip(),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: 12),
                Flexible(child: _buildProjectMenuChip()),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('protocol-title-field'),
          controller: _titleController,
          minLines: 1,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          validator: (value) =>
              value == null || value.isEmpty ? 'Please enter a title' : null,
          readOnly: _isInProgress,
          decoration: InputDecoration(
            hintText: 'Enter text...',
            fillColor: _isInProgress ? Colors.grey.shade100 : null,
            filled: _isInProgress,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProjectMenuChip() {
    final project = _selectedProject();
    final color = project == null ? Colors.grey : Color(project.colorValue);

    return PopupMenuButton<String>(
      enabled: !_isInProgress,
      tooltip: 'Choose project',
      initialValue: _selectedProjectId ?? '__unassigned__',
      onSelected: (value) async {
        if (value == '__create__') {
          await _createProject();
          return;
        }
        setState(() {
          _selectedProjectId = value == '__unassigned__' ? null : value;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: '__unassigned__',
          child: ListTile(
            leading: Icon(Icons.folder_off_outlined),
            title: Text('Unassigned'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        for (final project in _projects)
          PopupMenuItem<String>(
            value: project.id,
            child: ListTile(
              leading: Icon(
                Icons.folder_outlined,
                color: Color(project.colorValue),
              ),
              title: Text(project.name),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__create__',
          child: ListTile(
            leading: Icon(Icons.create_new_folder_outlined),
            title: Text('Create project'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Chip(
        avatar: Icon(
          project == null ? Icons.folder_off_outlined : Icons.folder_outlined,
          color: color,
          size: 18,
        ),
        label: Text(project?.name ?? 'Unassigned'),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
    );
  }

  Project? _selectedProject() {
    for (final project in _projects) {
      if (project.id == _selectedProjectId) return project;
    }
    return null;
  }

  Future<void> _createProject() async {
    final controller = TextEditingController();
    _ProjectDialogContent.lastSelectedColor = AppColors.primary;
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('New Project'),
          content: _ProjectDialogContent(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty) return;
      final existing = _projects
          .where((project) => project.name.toLowerCase() == name.toLowerCase())
          .cast<Project?>()
          .firstWhere((project) => project != null, orElse: () => null);
      if (existing != null) {
        setState(() => _selectedProjectId = existing.id);
        return;
      }

      final project = Project(
        id: 'project_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        colorValue: _ProjectDialogContent.lastSelectedColor.toARGB32(),
      );
      await _storageService.upsertProject(project);
      if (!mounted) return;
      setState(() {
        _projects = [
          ..._projects,
          project,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _selectedProjectId = project.id;
      });
    } finally {
      controller.dispose();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  List<Widget> _buildStepsSection() {
    if (!_usePhases) {
      return [
        ..._steps.asMap().entries.map(
          (entry) => _buildTimelineStep(entry.key, entry.value),
        ),
        const SizedBox(height: 8),
        Center(
          child: FilledButton.icon(
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
      items.add(_buildTimelineStep(i, step));

      final canCreateBoundary =
          i < _steps.length - 1 && _steps[i + 1].phaseName == currentPhase;
      if (canCreateBoundary) {
        items.add(_buildInsertPhaseButton(i));
      }

      // If next step is different phase or this is last step
      bool isLastInPhase =
          i == _steps.length - 1 || _steps[i + 1].phaseName != currentPhase;
      if (isLastInPhase) {
        final targetPhaseName = currentPhase;
        final targetInsertIndex = i + 1;
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
                onPressed: () => _addNewStep(
                  phaseName: targetPhaseName,
                  insertIndex: targetInsertIndex,
                ),
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
        child: FilledButton.icon(
          onPressed: _addNewPhase,
          icon: const Icon(Icons.library_add),
          label: const Text('Add New Phase'),
        ),
      ),
    );

    return items;
  }

  Widget _buildTimelineStep(int index, ProtocolStep step) {
    return CustomPaint(
      key: Key('step-connector-${index + 1}'),
      painter: _StepTimelinePainter(
        drawAbove: index > 0,
        drawBelow: index < _steps.length - 1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  key: Key('step-number-${index + 1}'),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.onPrimaryContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: KeyedSubtree(
              key: Key('step-card-${index + 1}'),
              child: KeyedSubtree(
                key: ValueKey('step-editor-${step.id}'),
                child: _buildStepEditor(index, step),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsertPhaseButton(int stepIndex) {
    var endIndex = stepIndex + 1;
    final phaseName = _steps[stepIndex].phaseName;
    while (endIndex + 1 < _steps.length &&
        _steps[endIndex + 1].phaseName == phaseName) {
      endIndex++;
    }
    var hasLockedTail = false;
    for (var index = stepIndex + 1; index <= endIndex; index++) {
      if (widget.lockedStepIds?.contains(_steps[index].id) ?? false) {
        hasLockedTail = true;
        break;
      }
    }

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: Container(width: 2, color: AppColors.outlineVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                const Expanded(child: Divider()),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: Key('insert-phase-after-${stepIndex + 1}'),
                  onPressed: hasLockedTail
                      ? null
                      : () => _insertPhaseAfterStep(stepIndex),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Insert phase'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: Divider()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseHeader(String? phaseName, int firstStepIdx) {
    String displayName = phaseName ?? 'Unnamed Phase';
    final ranges = _phaseRanges();
    final phaseIndex = ranges.indexWhere(
      (range) => range.start == firstStepIdx,
    );
    final range = ranges[phaseIndex];
    final isPhaseLocked = _rangeContainsLockedStep(range);
    final canMoveUp =
        phaseIndex > 0 &&
        ranges[phaseIndex - 1].end > ranges[phaseIndex - 1].start &&
        !isPhaseLocked &&
        !_rangeContainsLockedStep(ranges[phaseIndex - 1]);
    final canMoveDown =
        phaseIndex > 0 &&
        range.end > range.start &&
        !isPhaseLocked &&
        !_rangeContainsLockedStep(ranges[phaseIndex - 1]);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPhaseLocked
            ? Colors.grey.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPhaseLocked
              ? Colors.grey.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers,
            size: 18,
            color: isPhaseLocked ? Colors.grey : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PhaseNameField(
              initialValue: displayName,
              readOnly: isPhaseLocked,
              onChanged: (v) {
                setState(() {
                  for (var index = range.start; index <= range.end; index++) {
                    _steps[index] = _steps[index].copyWith(phaseName: v);
                  }
                });
              },
            ),
          ),
          PopupMenuButton<_PhaseMenuAction>(
            key: Key('phase-menu-${firstStepIdx + 1}'),
            tooltip: 'Phase actions',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _PhaseMenuAction.moveUp:
                  _movePhase(firstStepIdx, -1);
                  return;
                case _PhaseMenuAction.moveDown:
                  _movePhase(firstStepIdx, 1);
                  return;
                case _PhaseMenuAction.delete:
                  _deletePhase(firstStepIdx);
                  return;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _PhaseMenuAction.moveUp,
                enabled: canMoveUp,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.arrow_upward),
                  title: Text('Move phase up'),
                ),
              ),
              PopupMenuItem(
                value: _PhaseMenuAction.moveDown,
                enabled: canMoveDown,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.arrow_downward),
                  title: Text('Move phase down'),
                ),
              ),
              PopupMenuItem(
                value: _PhaseMenuAction.delete,
                enabled: !isPhaseLocked,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: AppColors.error),
                  title: Text('Delete phase'),
                ),
              ),
            ],
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
                Expanded(
                  child: TextFormField(
                    key: Key('step-title-field-${index + 1}'),
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
            SizedBox(
              key: Key('step-title-instructions-gap-${index + 1}'),
              height: 12,
            ),
            KeyedSubtree(
              key: Key('step-instructions-field-${index + 1}'),
              child: TextFormField(
                key: ValueKey(
                  'instructions_${step.id}_${_instructionFieldVersions[step.id] ?? 0}',
                ),
                focusNode: _instructionFocusNode(step.id),
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
                onTapOutside: (_) {
                  if (!isLocked) _instructionFocusNode(step.id).unfocus();
                },
                onEditingComplete: () {
                  if (!isLocked) _instructionFocusNode(step.id).unfocus();
                },
                onChanged: (value) {
                  _steps[index] = _steps[index].copyWith(instructions: value);
                },
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
                onEdit: (actionIndex, action) =>
                    _editAction(index, actionIndex, action),
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
                onEdit: (noteIndex, note) =>
                    _editProtocolStepNote(index, noteIndex, note),
                onMove: (noteIndex, direction) =>
                    _moveProtocolStepNote(index, noteIndex, direction),
                onDelete: (noteIndex) =>
                    _deleteProtocolStepNote(index, noteIndex),
              ),
            const SizedBox(height: 8),
            _buildStepTableLinks(index, step, isLocked: isLocked),
            SizedBox(
              key: Key('step-linked-tables-bottom-gap-${index + 1}'),
              height: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTableLinks(
    int stepIndex,
    ProtocolStep step, {
    required bool isLocked,
  }) {
    final linkedTables = _linkedTablesForStep(step);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopupMenuButton<String>(
          key: Key('step-table-menu-${stepIndex + 1}'),
          enabled: !isLocked,
          tooltip: 'Link tables to step ${stepIndex + 1}',
          onSelected: (value) {
            if (value == '__add_table__') {
              _addNewTable();
              return;
            }
            _toggleTableLink(stepIndex, value);
          },
          itemBuilder: (context) => [
            if (_regularTables.isEmpty)
              const PopupMenuItem<String>(
                enabled: false,
                child: ListTile(
                  leading: Icon(Icons.table_chart_outlined),
                  title: Text('No tables available'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            for (final table in _regularTables)
              PopupMenuItem<String>(
                value: table.id,
                child: ListTile(
                  leading: Icon(
                    _tableTypeIcon(table.type),
                    color: _tableColor(table),
                  ),
                  title: Text(
                    table.title.isEmpty ? 'Untitled Table' : table.title,
                  ),
                  trailing: step.tableIds.contains(table.id)
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: '__add_table__',
              child: ListTile(
                leading: Icon(Icons.add_chart_outlined),
                title: Text('Add table'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link,
                  size: 20,
                  color: isLocked ? Colors.grey : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Link table',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: _uniformFontSize,
                    color: isLocked ? Colors.grey : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (linkedTables.isEmpty)
          const Text(
            'No tables linked to this step.',
            style: TextStyle(
              fontSize: _uniformFontSize - 2,
              color: AppColors.textSecondary,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: linkedTables.map((table) {
              final tableColor = _tableColor(table);
              return InputChip(
                key: Key('linked-table-${step.id}-${table.id}'),
                avatar: Icon(
                  _tableTypeIcon(table.type),
                  size: 16,
                  color: tableColor,
                ),
                label: Text(
                  table.title.isEmpty ? 'Untitled Table' : table.title,
                  style: const TextStyle(fontSize: _uniformFontSize - 2),
                ),
                side: BorderSide(color: tableColor.withValues(alpha: 0.5)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: isLocked
                    ? null
                    : () => _unlinkTableFromStep(stepIndex, table.id),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _toggleTableLink(int stepIndex, String tableId) {
    if (stepIndex < 0 || stepIndex >= _steps.length) return;
    if (!_regularTables.any((table) => table.id == tableId)) return;

    setState(() {
      final step = _steps[stepIndex];
      final tableIds = List<String>.from(step.tableIds);
      if (tableIds.contains(tableId)) {
        tableIds.remove(tableId);
      } else {
        tableIds.add(tableId);
      }
      _steps[stepIndex] = step.copyWith(tableIds: tableIds);
    });
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
            leading: Icon(Icons.delete, color: AppColors.error),
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

  FocusNode _instructionFocusNode(String stepId) {
    return _instructionFocusNodes.putIfAbsent(stepId, () {
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (focusNode.hasFocus || !mounted) return;

        final stepIndex = _steps.indexWhere((step) => step.id == stepId);
        if (stepIndex == -1) return;
        if (widget.lockedStepIds?.contains(stepId) ?? false) return;
        _syncActionsFromInstructions(stepIndex);
      });
      return focusNode;
    });
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
      _instructionFieldVersions[step.id] =
          (_instructionFieldVersions[step.id] ?? 0) + 1;
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
    final keptInstructionLines = <String>[];

    for (final line in instructions.split(RegExp(r'\r?\n'))) {
      final trimmedLeft = line.trimLeft();
      if (RegExp(r'^-\s+').hasMatch(trimmedLeft)) {
        final action = trimmedLeft.substring(1).trim();
        if (action.isNotEmpty) actions.add(action);
      } else if (RegExp(r'^\*\s+').hasMatch(trimmedLeft)) {
        final note = trimmedLeft.substring(1).trim();
        if (note.isNotEmpty) notes.add(note);
      } else {
        keptInstructionLines.add(line);
      }
    }

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

  Future<void> _editAction(
    int stepIndex,
    int actionIndex,
    String action,
  ) async {
    final updated = await _showListItemEditDialog(
      title: 'Edit Action',
      label: 'Action',
      initialValue: action,
    );
    if (updated == null || !mounted) return;
    if (stepIndex >= _steps.length ||
        actionIndex >= _steps[stepIndex].actionItems.length) {
      return;
    }

    setState(() {
      final step = _steps[stepIndex];
      final actions = List<String>.from(step.actionItems);
      actions[actionIndex] = updated;
      _steps[stepIndex] = step.copyWith(actionItems: actions);
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

  Future<void> _editProtocolStepNote(
    int stepIndex,
    int noteIndex,
    String note,
  ) async {
    final updated = await _showListItemEditDialog(
      title: 'Edit Protocol Step Note',
      label: 'Protocol step note',
      initialValue: note,
    );
    if (updated == null || !mounted) return;
    if (stepIndex >= _steps.length ||
        noteIndex >= _steps[stepIndex].notes.length) {
      return;
    }

    setState(() {
      final step = _steps[stepIndex];
      final notes = List<String>.from(step.notes);
      notes[noteIndex] = updated;
      _steps[stepIndex] = step.copyWith(notes: notes);
    });
  }

  Future<String?> _showListItemEditDialog({
    required String title,
    required String label,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: null,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      return result;
    } finally {
      controller.dispose();
    }
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
          FilledButton(
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

  void _unlinkTableFromStep(int stepIndex, String tableId) {
    setState(() {
      final ids = List<String>.from(_steps[stepIndex].tableIds)
        ..remove(tableId);
      _steps[stepIndex] = _steps[stepIndex].copyWith(tableIds: ids);
    });
  }
}

class _StepTimelinePainter extends CustomPainter {
  const _StepTimelinePainter({
    required this.drawAbove,
    required this.drawBelow,
  });

  final bool drawAbove;
  final bool drawBelow;

  static const double _markerCenterX = 22;
  static const double _markerCenterY = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const x = _markerCenterX;

    if (drawAbove) {
      _drawDottedLine(canvas, paint, Offset(x, 0), Offset(x, _markerCenterY));
    }
    if (drawBelow) {
      _drawDottedLine(
        canvas,
        paint,
        Offset(x, _markerCenterY),
        Offset(x, size.height),
      );
    }
  }

  void _drawDottedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    const dashLength = 3.0;
    const gapLength = 4.0;
    var y = start.dy;
    while (y < end.dy) {
      final dashEnd = (y + dashLength).clamp(start.dy, end.dy);
      canvas.drawLine(Offset(start.dx, y), Offset(end.dx, dashEnd), paint);
      y += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _StepTimelinePainter oldDelegate) {
    return drawAbove != oldDelegate.drawAbove ||
        drawBelow != oldDelegate.drawBelow;
  }
}

class _ProjectDialogContent extends StatefulWidget {
  static Color lastSelectedColor = AppColors.primary;

  final TextEditingController controller;

  const _ProjectDialogContent({required this.controller});

  @override
  State<_ProjectDialogContent> createState() => _ProjectDialogContentState();
}

class _ProjectDialogContentState extends State<_ProjectDialogContent> {
  static const _colors = [
    AppColors.primary,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.blueGrey,
  ];

  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = _ProjectDialogContent.lastSelectedColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 18),
        const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in _colors)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() => _selectedColor = color);
                  _ProjectDialogContent.lastSelectedColor = color;
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColor == color
                          ? Colors.black87
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _selectedColor == color
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

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
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => _updateValue(),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 64,
          child: DropdownButtonFormField<String>(
            initialValue: _unit,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 4),
            ),
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

enum _PhaseMenuAction { moveUp, moveDown, delete }

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
