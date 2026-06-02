import 'package:flutter/material.dart';
import '../models/protocol.dart';
import '../models/active_protocol.dart';
import '../models/protocol_step.dart';
import '../models/protocol_table.dart';
import '../data/completed_protocols_data.dart';
import '../services/storage_service.dart';
import '../widgets/protocol_table_widget.dart';
import '../services/pdf_service.dart';
import '../services/export_service.dart';
import 'run_protocol_screen.dart';
import 'create_protocol_screen.dart';

class ProtocolDetailScreen extends StatefulWidget {
  final Protocol protocol;
  final ActiveProtocol? activeState;

  const ProtocolDetailScreen({super.key, required this.protocol, this.activeState});

  @override
  State<ProtocolDetailScreen> createState() => _ProtocolDetailScreenState();
}

class _ProtocolDetailScreenState extends State<ProtocolDetailScreen> {
  late Protocol protocol;
  ActiveProtocol? activeState;

  @override
  void initState() {
    super.initState();
    protocol = widget.protocol;
    activeState = widget.activeState;
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Protocol?'),
        content: const Text('Are you sure you want to delete this protocol from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldNavigator = Navigator.of(context);
              final dialogNavigator = Navigator.of(dialogContext);
              
              final existingProtocols = await StorageService().loadProtocols();
              existingProtocols.removeWhere((p) => p.id == protocol.id);
              await StorageService().saveProtocols(existingProtocols);
              
              if (mounted) {
                if (dialogContext.mounted) dialogNavigator.pop(); // Close dialog
                scaffoldNavigator.pop(); // Go back to list
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editProtocol(BuildContext context) async {
    final updatedProtocol = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProtocolScreen(initialProtocol: protocol),
      ),
    );

    if (updatedProtocol != null && updatedProtocol is Protocol) {
      setState(() {
        protocol = updatedProtocol;
        if (activeState != null) {
          activeState = activeState!.copyWith(protocol: updatedProtocol);
          // Sync with global state
          int idx = runningProtocols.indexWhere((p) => p.protocol.id == protocol.id);
          if (idx != -1) {
            runningProtocols[idx] = activeState!;
            savePersistentProtocols();
          }
        }
      });
    }
  }

  void _exportProtocol(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                PdfService.exportProtocolToPdf(protocol);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export as JSON'),
              onTap: () {
                Navigator.pop(context);
                ExportService().exportSingleTemplate(protocol);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_view),
              title: const Text('Export as Excel (XLSX) (Coming Soon)'),
              enabled: false,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedSteps = protocol.sortedSteps;
    
    final bool hasPhases = sortedSteps.any((s) => s.phaseName != null && s.phaseName!.isNotEmpty);
    String fabLabel = 'Run Protocol';
    int? nextPhaseStartIdx;
    int? nextPhaseEndIdx;

    if (hasPhases) {
      final Map<String, List<ProtocolStep>> stepsByPhase = {};
      final List<String> phaseOrder = [];
      for (var step in sortedSteps) {
        final phase = step.phaseName ?? 'General';
        if (!stepsByPhase.containsKey(phase)) {
          phaseOrder.add(phase);
          stepsByPhase[phase] = [];
        }
        stepsByPhase[phase]!.add(step);
      }

      int currentGlobalIdx = 0;
      bool foundNext = false;
      for (var phase in phaseOrder) {
        final phaseSteps = stepsByPhase[phase]!;
        final bool isPhaseDone = activeState != null && 
            phaseSteps.every((s) => activeState!.completedStepIds.contains(s.id));
        
        if (!isPhaseDone) {
          fabLabel = 'Run $phase';
          nextPhaseStartIdx = currentGlobalIdx;
          nextPhaseEndIdx = currentGlobalIdx + phaseSteps.length - 1;
          foundNext = true;
          break;
        }
        currentGlobalIdx += phaseSteps.length;
      }
      
      if (!foundNext) {
        fabLabel = 'Protocol Completed';
      }
    } else {
      // Handle Day grouping if no phases but multiple days
      final Map<int, List<ProtocolStep>> stepsByDay = {};
      for (var step in sortedSteps) {
        stepsByDay.putIfAbsent(step.day, () => []).add(step);
      }
      final sortedDays = stepsByDay.keys.toList()..sort();
      
      if (sortedDays.length > 1) {
        int currentGlobalIdx = 0;
        bool foundNext = false;
        for (var day in sortedDays) {
          final daySteps = stepsByDay[day]!;
          final bool isDayDone = activeState != null && 
              daySteps.every((s) => activeState!.completedStepIds.contains(s.id));
          
          if (!isDayDone) {
            fabLabel = 'Run Day $day';
            nextPhaseStartIdx = currentGlobalIdx;
            nextPhaseEndIdx = currentGlobalIdx + daySteps.length - 1;
            foundNext = true;
            break;
          }
          currentGlobalIdx += daySteps.length;
        }
        if (!foundNext) fabLabel = 'Protocol Completed';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protocol Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editProtocol(context),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _exportProtocol(context),
            tooltip: 'Export',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    protocol.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (protocol.isTemplate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      'TEMPLATE',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),
            
            _buildSection(context, 'Objective', protocol.objective),
            _buildSection(context, 'Description', protocol.description),
            
            if (protocol.samples.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Samples', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...protocol.samples.map((sample) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text('• $sample'),
              )),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),
            Text('Material List', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (protocol.materials.isEmpty)
              const Text('No materials listed.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Catalog #')),
                    DataColumn(label: Text('Manufacturer')),
                    DataColumn(label: Text('Location')),
                    DataColumn(label: Text('Stock Conc.')),
                  ],
                  rows: protocol.materials.map((m) => DataRow(
                    cells: [
                      DataCell(Text(m.name)),
                      DataCell(Text(m.quantity)),
                      DataCell(Text(m.catalogNumber)),
                      DataCell(Text(m.manufacturer)),
                      DataCell(Text(m.location)),
                      DataCell(Text(m.stockConcentration)),
                    ],
                  )).toList(),
                ),
              ),
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Steps', style: Theme.of(context).textTheme.titleLarge),
                if (activeState != null)
                  ElevatedButton.icon(
                    onPressed: () => _editProtocol(context),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Phase', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildGroupedSteps(context),
            
            // Supplementary Section
            _buildSupplementarySection(context),

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: (fabLabel == 'Protocol Completed' || protocol.isTemplate) ? null : FloatingActionButton.extended(
        onPressed: () {
          if (activeState != null) {
            activeProtocol = activeState;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RunProtocolScreen(
                protocol: protocol,
                initialStepIndex: nextPhaseStartIdx,
                finalStepIndex: nextPhaseEndIdx,
              ),
            ),
          );
        },
        label: Text(fabLabel),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }

  List<Widget> _buildGroupedSteps(BuildContext context) {
    final Map<String, List<ProtocolStep>> stepsByPhase = {};
    final sortedSteps = protocol.sortedSteps;

    bool hasPhases = sortedSteps.any((s) => s.phaseName != null && s.phaseName!.isNotEmpty);

    if (hasPhases) {
      // Group by phase name in order of appearance
      final List<String> phaseOrder = [];
      for (var step in sortedSteps) {
        final phase = step.phaseName ?? 'General';
        if (!stepsByPhase.containsKey(phase)) {
          phaseOrder.add(phase);
          stepsByPhase[phase] = [];
        }
        stepsByPhase[phase]!.add(step);
      }

      List<Widget> widgets = [];
      int currentGlobalIdx = 0;
      for (var phase in phaseOrder) {
        final phaseSteps = stepsByPhase[phase]!;
        final startIdx = currentGlobalIdx;
        final endIdx = currentGlobalIdx + phaseSteps.length - 1;
        
        final bool isPhaseDone = activeState != null && 
            phaseSteps.every((s) => activeState!.completedStepIds.contains(s.id));

        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: isPhaseDone ? BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ) : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(phase, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    if (isPhaseDone) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    ],
                  ],
                ),
                if (!isPhaseDone && !protocol.isTemplate)
                  TextButton.icon(
                  onPressed: () {
                    if (activeState != null) {
                      activeProtocol = activeState;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RunProtocolScreen(
                          protocol: protocol,
                          initialStepIndex: startIdx,
                          finalStepIndex: endIdx,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  label: Text(isPhaseDone ? 'Run Again' : 'Run $phase', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ));

        for (var step in phaseSteps) {
          widgets.add(_buildStepCard(context, step, currentGlobalIdx));
          currentGlobalIdx++;
        }
      }
      return widgets;
    } else {
      // Fallback to Day grouping
      final Map<int, List<ProtocolStep>> stepsByDay = {};
      for (var step in sortedSteps) {
        stepsByDay.putIfAbsent(step.day, () => []).add(step);
      }
      final sortedDays = stepsByDay.keys.toList()..sort();

      List<Widget> widgets = [];
      int currentGlobalIdx = 0;

      for (var day in sortedDays) {
        final daySteps = stepsByDay[day]!;
        final startIdx = currentGlobalIdx;
        final endIdx = currentGlobalIdx + daySteps.length - 1;

        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Day $day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                if (!protocol.isTemplate)
                  TextButton.icon(
                    onPressed: () {
                  if (activeState != null) {
                    activeProtocol = activeState;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RunProtocolScreen(
                        protocol: protocol,
                        initialStepIndex: startIdx,
                        finalStepIndex: endIdx,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: Text('Run Day $day', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ));

        for (var step in daySteps) {
          widgets.add(_buildStepCard(context, step, currentGlobalIdx));
          currentGlobalIdx++;
        }
      }
      return widgets;
    }
  }

  Widget _buildStepCard(BuildContext context, ProtocolStep step, int index) {
    final bool isDone = activeState != null && activeState!.completedStepIds.contains(step.id);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isDone ? Colors.green.withValues(alpha: 0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Step ${index + 1}: ${step.title}', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: isDone ? Colors.green.shade700 : null,
                    )),
                ),
                if (isDone) const Icon(Icons.check, color: Colors.green, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(step.instructions, style: TextStyle(color: isDone ? Colors.grey : null)),
            if (step.actionItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...step.actionItems.asMap().entries.map((aEntry) {
                final item = aEntry.value;
                final timer = step.actionTimers[aEntry.key];
                String timerStr = '';
                if (timer != null) {
                  if (timer >= 3600) {
                    timerStr = ' (${timer ~/ 3600}h)';
                  } else if (timer >= 60) {
                    timerStr = ' (${timer ~/ 60}m)';
                  } else {
                    timerStr = ' (${timer}s)';
                  }
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('  - '),
                    Expanded(child: Text('$item$timerStr')),
                  ],
                );
              }),
            ],
            if (step.tableIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: step.tableIds.map((id) {
                  final table = protocol.tables.firstWhere(
                    (t) => t.id == id,
                    orElse: () => ProtocolTable(id: 'err', title: 'Table Not Found'),
                  );
                  if (table.id == 'err') return const SizedBox.shrink();
                  return ProtocolTableWidget(table: table);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(content),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSupplementarySection(BuildContext context) {
    final assignedTableIds = protocol.steps.expand((s) => s.tableIds).toSet();
    final unassignedTables = protocol.tables.where((t) => !assignedTableIds.contains(t.id)).toList();

    if (protocol.files.isEmpty && unassignedTables.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        Text('Supplementary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (protocol.files.isNotEmpty) ...[
          const Text('Attached Files:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ...protocol.files.map((file) => ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(file),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          )),
          const SizedBox(height: 16),
        ],
        if (unassignedTables.isNotEmpty) ...[
          const Text('Reference Tables:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: unassignedTables.map((table) => ProtocolTableWidget(table: table)).toList(),
          ),
        ],
      ],
    );
  }
}
