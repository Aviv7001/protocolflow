import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/protocol.dart';
import '../models/material.dart';
import '../models/protocol_step.dart';
import '../models/protocol_table.dart';
import '../models/master_mix_wizard.dart';
import '../models/reagent_mix_wizard.dart';
import '../features/master_mix/services/master_mix_calculator_service.dart';
import '../features/reagent_mix/services/reagent_mix_calculator_service.dart';
import '../widgets/protocol_table_widget.dart';
import '../services/storage_service.dart';
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
  final List<ProtocolStep> _steps = [];
  final List<ProtocolTable> _tables = [];
  bool _usePhases = false;
  late final bool _isInProgress;

  @override
  void initState() {
    super.initState();
    _isInProgress = widget.lockedStepIds != null && widget.lockedStepIds!.isNotEmpty;
    
    if (widget.initialProtocol != null) {
      final p = widget.initialProtocol!;
      _titleController.text = p.title;
      _objectiveController.text = p.objective;
      _descriptionController.text = p.description;
      _materials.addAll(p.materials);
      _samples.addAll(p.samples);
      _steps.addAll(p.steps);
      _tables.addAll(p.tables);
      _usePhases = p.steps.any((s) => s.phaseName != null && s.phaseName!.isNotEmpty);
    }

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

  void _addNewMaterial() {
    setState(() {
      _materials.add(MaterialItem(
        id: 'mat_${DateTime.now().millisecondsSinceEpoch}',
        name: '',
        quantity: '',
        catalogNumber: '',
        manufacturer: '',
        location: '',
        stockConcentration: '',
      ));
    });
  }

  void _addNewSample() {
    setState(() {
      _samples.add('');
    });
  }

  void _addNewStep({String? phaseName}) {
    setState(() {
      int nextDay = 1;
      String? currentPhase = phaseName;
      if (_steps.isNotEmpty) {
        nextDay = _steps.last.day;
        currentPhase ??= _steps.last.phaseName;
      }
      _steps.add(ProtocolStep(
        id: 'step_${DateTime.now().millisecondsSinceEpoch}',
        title: '',
        instructions: '',
        actionItems: [],
        materials: [],
        actionTimers: {},
        day: nextDay,
        phaseName: currentPhase,
      ));
    });
  }

  void _addNewPhase() {
    setState(() {
      final phaseCount = _steps.map((s) => s.phaseName).toSet().length + 1;
      final newPhaseName = 'Phase $phaseCount';
      _addNewStep(phaseName: newPhaseName);
    });
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
          _tables.add(result);
          _syncMaterialsFromTable(result);
        } else if (result is List<ProtocolTable>) {
          for (final table in result) {
            _tables.add(table);
            _syncMaterialsFromTable(table);
          }
        }
      });
    }
  }

  void _syncMaterialsFromTable(ProtocolTable table) {
    // We re-sync all materials from all tables to ensure totals are correct
    final Map<String, double> totalVolumesUl = {};
    final Map<String, String> stockConcentrations = {};

    for (final t in _tables) {
      final wizardState = t.metadata['wizard_state'];
      if (wizardState == null) continue;

      if (t.type == TableType.masterMix) {
        try {
          final wizard = MasterMixWizard.fromJson(jsonDecode(wizardState));
          final result = MasterMixCalculatorService().calculateMasterMix(MasterMixInput(
            mixName: wizard.mixName,
            finalVolume: wizard.finalVolume,
            finalVolumeUnit: wizard.finalVolumeUnit,
            baseSolventName: wizard.baseSolventName,
            reagents: wizard.reagents.map((r) => r.toInput()).toList(),
          ));

          if (result.success) {
            for (var r in result.reagentResults) {
              if (r.reagentName.isNotEmpty) {
                totalVolumesUl[r.reagentName] = (totalVolumesUl[r.reagentName] ?? 0) + r.reagentVolumeUl;
                stockConcentrations[r.reagentName] = r.formattedStockConcentration;
              }
            }
            if (wizard.baseSolventName.isNotEmpty) {
              totalVolumesUl[wizard.baseSolventName] = (totalVolumesUl[wizard.baseSolventName] ?? 0) + result.baseSolventVolumeUl;
            }
          }
        } catch (e) {
          debugPrint('Error syncing MasterMix: $e');
        }
      } else if (t.type == TableType.reagentMix) {
        try {
          final wizard = ReagentMixWizard.fromJson(jsonDecode(wizardState));
          final service = ReagentMixCalculatorService();
          for (var r in wizard.reagents) {
            final input = ReagentMixInput(
              reagentName: r.name,
              stockConcentration: r.stockConc,
              stockUnit: r.stockUnit,
              workingConcentration: r.workingConc,
              workingUnit: r.workingUnit,
              volumePerTube: r.volPerSample,
              volumePerTubeUnit: r.volUnit,
              numberOfTubes: r.numSamples,
              molecularWeight: r.molecularWeight,
            );
            final result = service.calculateMix(input);
            if (result.success) {
              if (r.name.isNotEmpty) {
                totalVolumesUl[r.name] = (totalVolumesUl[r.name] ?? 0) + result.reagentVolumeUl;
                stockConcentrations[r.name] = '${r.stockConc} ${r.stockUnit.name}';
              }
              if (r.solvent.isNotEmpty) {
                totalVolumesUl[r.solvent] = (totalVolumesUl[r.solvent] ?? 0) + result.solventVolumeUl;
              }
            }
          }
        } catch (e) {
          debugPrint('Error syncing ReagentMix: $e');
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

        final index = _materials.indexWhere((m) => m.name.trim().toLowerCase() == name.trim().toLowerCase());
        if (index != -1) {
          // Update existing material quantity and stock conc
          _materials[index] = _materials[index].copyWith(
            quantity: qtyStr,
            stockConcentration: stock,
          );
        } else {
          // Add new material
          _materials.add(MaterialItem(
            id: 'mat_${DateTime.now().millisecondsSinceEpoch}_${_materials.length}',
            name: name,
            quantity: qtyStr,
            stockConcentration: stock,
          ));
        }
      }
    });
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
        content: const Text('You have unsaved changes. Are you sure you want to exit?'),
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
    if (_formKey.currentState!.validate()) {
      bool isUpdating = widget.initialProtocol != null && 
                       isTemplate == widget.initialProtocol!.isTemplate;
      
      String newId = isUpdating 
          ? widget.initialProtocol!.id 
          : 'proto_${DateTime.now().millisecondsSinceEpoch}';

      final newProtocol = Protocol(
        id: newId,
        title: _titleController.text,
        objective: _objectiveController.text,
        description: _descriptionController.text,
        materials: List.from(_materials),
        samples: List.from(_samples),
        steps: List.from(_steps),
        tables: List.from(_tables),
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

      if (mounted) {
        setState(() => _canActuallyPop = true);
        Navigator.pop(context, newProtocol);
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
        title: Text(widget.initialProtocol != null ? 'Edit Protocol' : 'Create Protocol'),
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
                validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const Divider(height: 32),
              
              _buildFieldSection('Objective', _objectiveController),
              _buildFieldSection('Description', _descriptionController, maxLines: 3),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(indent: 24, endIndent: 24, thickness: 1),
              ),

              _buildSectionHeader('Samples'),
              const SizedBox(height: 8),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _addNewSample,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Sample'),
                ),
              ),
              const SizedBox(height: 8),
              ..._samples.asMap().entries.map((entry) {
                final idx = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.grey)),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(hintText: 'Sample name (e.g. THP1 cell line)', border: InputBorder.none),
                          onChanged: (v) => _samples[idx] = v,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                        onPressed: () => setState(() => _samples.removeAt(idx)),
                      ),
                    ],
                  ),
                );
              }),
              if (_samples.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _addNewSample,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Sample'),
                  ),
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(indent: 24, endIndent: 24, thickness: 1),
              ),

              _buildSectionHeader('Material List'),
              const SizedBox(height: 8),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _addNewMaterial,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Material'),
                ),
              ),
              const SizedBox(height: 8),
              _buildMaterialsTable(),
              if (_materials.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _addNewMaterial,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Material'),
                  ),
                ),
              ],
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(indent: 24, endIndent: 24, thickness: 1),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Steps', style: Theme.of(context).textTheme.titleLarge),
                  Row(
                    children: [
                      const Text('Set Phases', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Switch(
                        value: _usePhases,
                        onChanged: _isInProgress ? null : (val) {
                          setState(() {
                            _usePhases = val;
                            if (_usePhases && _steps.isNotEmpty) {
                              // If enabling phases and we have steps, assign them to "Phase 1" if they don't have one
                              for (int i = 0; i < _steps.length; i++) {
                                if (_steps[i].phaseName == null || _steps[i].phaseName!.isEmpty) {
                                  _steps[i] = _steps[i].copyWith(phaseName: 'Phase 1');
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
              Center(
                child: ElevatedButton.icon(
                  onPressed: _addNewTable,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Table'),
                ),
              ),
              const SizedBox(height: 16),
              if (_tables.isEmpty)
                const Center(child: Text('No tables added.', style: TextStyle(color: Colors.grey)))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tables.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final table = entry.value;
                    return Stack(
                      children: [
                        ProtocolTableWidget(
                          table: table,
                          isReadOnly: false,
                          onSave: (updated) {
                            setState(() => _tables[idx] = updated);
                            _syncMaterialsFromTable(updated);
                          },
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                            onPressed: () => setState(() => _tables.removeAt(idx)),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              if (_tables.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _addNewTable,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Table'),
                  ),
                ),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildFieldSection(String label, TextEditingController controller, {int maxLines = 1, String? Function(String?)? validator}) {
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
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  List<Widget> _buildStepsSection() {
    if (!_usePhases) {
      return [
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _addNewStep(),
            icon: const Icon(Icons.add),
            label: const Text('Add Step'),
          ),
        ),
        const SizedBox(height: 8),
        ..._steps.asMap().entries.map((entry) => _buildStepEditor(entry.key, entry.value)),
        if (_steps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _addNewStep(),
              icon: const Icon(Icons.add),
              label: const Text('Add Step'),
            ),
          ),
        ],
      ];
    }

    // Grouping by phases
    final List<Widget> items = [];
    
    items.add(
      Center(
        child: ElevatedButton.icon(
          onPressed: _addNewPhase,
          icon: const Icon(Icons.library_add),
          label: const Text('Add New Phase'),
        ),
      ),
    );
    items.add(const SizedBox(height: 16));

    String? currentPhase;
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      if (step.phaseName != currentPhase || i == 0) {
        currentPhase = step.phaseName;
        items.add(_buildPhaseHeader(currentPhase, i));
      }
      items.add(_buildStepEditor(i, step));
      
      // If next step is different phase or this is last step
      bool isLastInPhase = i == _steps.length - 1 || _steps[i+1].phaseName != currentPhase;
      if (isLastInPhase) {
        final phaseSteps = _steps.where((s) => s.phaseName == currentPhase);
        final bool isPhaseLocked = phaseSteps.isNotEmpty && 
                                   phaseSteps.every((s) => widget.lockedStepIds?.contains(s.id) ?? false);
        
        if (!isPhaseLocked) {
          items.add(
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
              child: TextButton.icon(
                onPressed: () => _addNewStep(phaseName: currentPhase),
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
    final bool isPhaseLocked = phaseSteps.isNotEmpty && 
                               phaseSteps.every((s) => widget.lockedStepIds?.contains(s.id) ?? false);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPhaseLocked ? Colors.grey.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPhaseLocked ? Colors.grey.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.layers, size: 18, color: isPhaseLocked ? Colors.grey : Colors.blue),
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
    if (_materials.isEmpty) {
      return const Text('No materials added. Press + to add rows.', style: TextStyle(color: Colors.grey));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        horizontalMargin: 0,
        columns: const [
          DataColumn(label: SizedBox(width: 140, child: Text('Name'))),
          DataColumn(label: SizedBox(width: 80, child: Text('Qty'))),
          DataColumn(label: SizedBox(width: 100, child: Text('Stock Conc.'))),
          DataColumn(label: SizedBox(width: 100, child: Text('Catalog #'))),
          DataColumn(label: SizedBox(width: 100, child: Text('Mfr'))),
          DataColumn(label: SizedBox(width: 40, child: Text(''))),
        ],
        rows: _materials.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;

          return DataRow(
            key: ValueKey(item.id),
            cells: [
              DataCell(
                _MaterialCell(
                  initialValue: item.name,
                  onChanged: (v) => _materials[idx] = _materials[idx].copyWith(name: v),
                ),
              ),
              DataCell(
                _MaterialCell(
                  initialValue: item.quantity,
                  onChanged: (v) => _materials[idx] = _materials[idx].copyWith(quantity: v),
                ),
              ),
              DataCell(
                _MaterialCell(
                  initialValue: item.stockConcentration,
                  onChanged: (v) => _materials[idx] = _materials[idx].copyWith(stockConcentration: v),
                ),
              ),
              DataCell(
                _MaterialCell(
                  initialValue: item.catalogNumber,
                  onChanged: (v) => _materials[idx] = _materials[idx].copyWith(catalogNumber: v),
                ),
              ),
              DataCell(
                _MaterialCell(
                  initialValue: item.manufacturer,
                  onChanged: (v) => _materials[idx] = _materials[idx].copyWith(manufacturer: v),
                ),
              ),
              DataCell(IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => setState(() => _materials.removeAt(idx)),
              )),
            ],
          );
        }).toList(),
      ),
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
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: step.title,
                    readOnly: isLocked,
                    decoration: const InputDecoration(hintText: 'Step Title', border: InputBorder.none),
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: _uniformFontSize,
                      color: isLocked ? Colors.grey : null,
                    ),
                    onChanged: (v) => _steps[index] = _steps[index].copyWith(title: v),
                  ),
                ),
                if (!isLocked)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => setState(() => _steps.removeAt(index)),
                  ),
              ],
            ),
            TextFormField(
              initialValue: step.instructions,
              readOnly: isLocked,
              decoration: const InputDecoration(hintText: 'Instructions...', border: InputBorder.none),
              maxLines: null,
              style: TextStyle(
                fontSize: _uniformFontSize,
                color: isLocked ? Colors.grey : null,
              ),
              onChanged: (v) => _steps[index] = _steps[index].copyWith(instructions: v),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Actions', style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: _uniformFontSize,
                  color: isLocked ? Colors.grey : null,
                )),
                if (!isLocked)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18, color: Colors.green),
                    onPressed: () {
                      setState(() {
                        final newActions = List<String>.from(step.actionItems)..add('');
                        _steps[index] = step.copyWith(actionItems: newActions);
                      });
                    },
                  ),
              ],
            ),
            ...step.actionItems.asMap().entries.map((aEntry) {
              final aIdx = aEntry.key;
              final timer = step.actionTimers[aIdx] ?? 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.grey, fontSize: _uniformFontSize)),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        initialValue: step.actionItems[aIdx],
                        readOnly: isLocked,
                        decoration: const InputDecoration(hintText: 'Action', isDense: true, border: InputBorder.none),
                        style: TextStyle(
                          fontSize: _uniformFontSize,
                          color: isLocked ? Colors.grey : null,
                        ),
                        onChanged: (v) {
                          final newActions = List<String>.from(_steps[index].actionItems);
                          newActions[aIdx] = v;
                          _steps[index] = _steps[index].copyWith(actionItems: newActions);
                        },
                      ),
                    ),
                    IgnorePointer(
                      ignoring: isLocked,
                      child: _ActionTimerInput(
                        totalSeconds: timer,
                        onChanged: (newTotal) => _updateActionTimer(index, aIdx, newTotal),
                      ),
                    ),
                    if (!isLocked)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                        onPressed: () {
                      setState(() {
                        final newActions = List<String>.from(_steps[index].actionItems)..removeAt(aIdx);
                        final newTimers = Map<int, int>.from(_steps[index].actionTimers)..remove(aIdx);
                        // Re-index timers
                        final Map<int, int> fixedTimers = {};
                        newTimers.forEach((k, v) {
                          if (k < aIdx) {
                            fixedTimers[k] = v;
                          }
                          if (k > aIdx) {
                            fixedTimers[k - 1] = v;
                          }
                        });
                        _steps[index] = _steps[index].copyWith(actionItems: newActions, actionTimers: fixedTimers);
                      });
                    },
                      ),
                  ],
                ),
              );
            }),
            if (_tables.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Linked Tables', style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: _uniformFontSize,
                color: isLocked ? Colors.grey : null,
              )),
              Wrap(
                spacing: 4,
                children: _tables.map((t) {
                  final isSelected = step.tableIds.contains(t.id);
                  return FilterChip(
                    label: Text(t.title.isEmpty ? 'Untitled Table' : t.title, style: const TextStyle(fontSize: _uniformFontSize - 2)),
                    selected: isSelected,
                    onSelected: isLocked ? null : (val) {
                      setState(() {
                        final newTableIds = List<String>.from(step.tableIds);
                        if (val) {
                          newTableIds.add(t.id);
                        } else {
                          newTableIds.remove(t.id);
                        }
                        _steps[index] = step.copyWith(tableIds: newTableIds);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
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

}

class _ActionTimerInput extends StatefulWidget {
  final int totalSeconds;
  final Function(int) onChanged;

  const _ActionTimerInput({required this.totalSeconds, required this.onChanged});

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
    } else if (widget.totalSeconds % 3600 == 0) {
      _unit = 'H';
      _controller = TextEditingController(text: (widget.totalSeconds ~/ 3600).toString());
    } else if (widget.totalSeconds % 60 == 0) {
      _unit = 'M';
      _controller = TextEditingController(text: (widget.totalSeconds ~/ 60).toString());
    } else {
      _unit = 'S';
      _controller = TextEditingController(text: widget.totalSeconds.toString());
    }
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
            keyboardType: TextInputType.number,
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
    final val = int.tryParse(_controller.text) ?? 0;
    int total = 0;
    if (_unit == 'H') {
      total = val * 3600;
    } else if (_unit == 'M') {
      total = val * 60;
    } else {
      total = val;
    }
    widget.onChanged(total);
  }
}

class _PhaseNameField extends StatefulWidget {
  final String initialValue;
  final bool readOnly;
  final Function(String) onChanged;

  const _PhaseNameField({required this.initialValue, this.readOnly = false, required this.onChanged});

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
      decoration: const InputDecoration(hintText: 'Phase Name (e.g. Day 1)', border: InputBorder.none, isDense: true),
      style: TextStyle(fontWeight: FontWeight.bold, color: widget.readOnly ? Colors.grey : Colors.blue),
      onSubmitted: (v) {
        if (v != widget.initialValue) {
          widget.onChanged(v);
        }
      },
    );
  }
}

class _MaterialCell extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;

  const _MaterialCell({required this.initialValue, required this.onChanged});

  @override
  State<_MaterialCell> createState() => _MaterialCellState();
}

class _MaterialCellState extends State<_MaterialCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_MaterialCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
      style: const TextStyle(fontSize: 12),
      onChanged: widget.onChanged,
    );
  }
}
