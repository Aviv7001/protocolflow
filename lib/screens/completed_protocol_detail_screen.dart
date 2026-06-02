import 'dart:io';
import 'package:flutter/material.dart';
import 'package:protocolflow/models/completed_protocol.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/step_note.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/widgets/protocol_table_widget.dart';
import 'package:protocolflow/data/completed_protocols_data.dart';
import 'package:protocolflow/services/pdf_service.dart';
import 'package:protocolflow/services/export_service.dart';

class CompletedProtocolDetailScreen extends StatelessWidget {
  final CompletedProtocol completedProtocol;

  const CompletedProtocolDetailScreen({super.key, required this.completedProtocol});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Protocol?'),
        content: const Text('Are you sure you want to delete this completed protocol record? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              completedProtocols.removeWhere((p) => p.id == completedProtocol.id);
              await savePersistentProtocols();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Go back to list
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
                PdfService.exportToPdf(completedProtocol);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export as JSON'),
              onTap: () {
                Navigator.pop(context);
                ExportService().exportSingleCompletedProtocol(completedProtocol);
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
    final protocol = completedProtocol.protocol;
    final date = completedProtocol.completedAt;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Protocol Detail'),
        actions: [
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
            Text(
              protocol.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Completed on: $dateStr', style: const TextStyle(fontStyle: FontStyle.italic)),
            const Divider(height: 32),
            
            _buildSection(context, 'Objective', protocol.objective),
            _buildSection(context, 'Description', protocol.description),
            
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
            ..._buildNotesSection(
              completedProtocol.notes.where((n) => n.stepId == 'materials').toList(),
            ),
            
            const SizedBox(height: 24),
            Text('Steps', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ..._buildGroupedSteps(context),
            
            if (completedProtocol.notes.any((n) => n.stepId == 'overview')) ...[
              const SizedBox(height: 24),
              Text('General Notes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._buildNotesSection(
                completedProtocol.notes.where((n) => n.stepId == 'overview').toList(),
              ),
            ],
            
            // Supplementary Section
            _buildSupplementarySection(context),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSteps(BuildContext context) {
    final protocol = completedProtocol.protocol;
    final Map<String, List<ProtocolStep>> stepsByPhase = {};
    final sortedSteps = List<ProtocolStep>.from(protocol.steps)
      ..sort((a, b) => a.day.compareTo(b.day));

    bool hasPhases = sortedSteps.any((s) => s.phaseName != null && s.phaseName!.isNotEmpty);

    if (hasPhases) {
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
      int globalStepIdx = 0;
      for (var phase in phaseOrder) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(phase, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
        ));

        for (var step in stepsByPhase[phase]!) {
          widgets.add(_buildStepCard(context, step, globalStepIdx));
          globalStepIdx++;
        }
      }
      return widgets;
    } else {
      final Map<int, List<ProtocolStep>> stepsByDay = {};
      for (var step in sortedSteps) {
        stepsByDay.putIfAbsent(step.day, () => []).add(step);
      }
      final sortedDays = stepsByDay.keys.toList()..sort();

      List<Widget> widgets = [];
      int globalStepIdx = 0;

      for (var day in sortedDays) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Day $day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
        ));

        for (var step in stepsByDay[day]!) {
          widgets.add(_buildStepCard(context, step, globalStepIdx));
          globalStepIdx++;
        }
      }
      return widgets;
    }
  }

  Widget _buildStepCard(BuildContext context, ProtocolStep step, int index) {
    final stepNotes = completedProtocol.notes.where((n) => n.stepId == step.id).toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step ${index + 1}: ${step.title}', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(step.instructions),
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
              ...step.tableIds.map((id) {
                final table = completedProtocol.protocol.tables.firstWhere(
                  (t) => t.id == id,
                  orElse: () => ProtocolTable(id: 'err', title: 'Table Not Found'),
                );
                if (table.id == 'err') return const SizedBox.shrink();
                return ProtocolTableWidget(table: table);
              }),
            ],
            if (stepNotes.isNotEmpty) ...[
              const Divider(),
              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              ..._buildNotesSection(stepNotes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupplementarySection(BuildContext context) {
    final protocol = completedProtocol.protocol;
    final assignedTableIds = protocol.steps.expand((s) => s.tableIds).toSet();
    final unassignedTables = protocol.tables.where((t) => !assignedTableIds.contains(t.id)).toList();

    if (protocol.files.isEmpty && unassignedTables.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
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
          ...unassignedTables.map((table) => ProtocolTableWidget(table: table)),
        ],
      ],
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

  List<Widget> _buildNotesSection(List<StepNote> notes) {
    if (notes.isEmpty) return [];

    return [
      if (notes.any((n) => n.photoPaths.isNotEmpty))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            itemCount: notes.fold<int>(0, (sum, n) => sum + n.photoPaths.length),
            itemBuilder: (context, globalIdx) {
              int count = 0;
              int noteIdx = -1;
              int photoInNoteIdx = -1;
              String? path;

              for (int i = 0; i < notes.length; i++) {
                final n = notes[i];
                if (globalIdx < count + n.photoPaths.length) {
                  noteIdx = i + 1;
                  photoInNoteIdx = globalIdx - count + 1;
                  path = n.photoPaths[photoInNoteIdx - 1];
                  break;
                }
                count += n.photoPaths.length;
              }

              if (path == null) return const SizedBox.shrink();

              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$noteIdx.$photoInNoteIdx',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ...notes.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final note = entry.value;
        if (note.note.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:0.8),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.note,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      }),
    ];
  }
}
