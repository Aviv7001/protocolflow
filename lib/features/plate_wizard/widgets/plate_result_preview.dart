import 'package:flutter/material.dart';

import '../../../models/plate_wizard.dart';
import '../../../models/protocol_table.dart';
import '../../../services/table_export_service.dart';
import '../../../widgets/table_export_actions.dart';

class PlateResultPreview extends StatefulWidget {
  final PlateLayoutWizard wizard;

  const PlateResultPreview({super.key, required this.wizard});

  @override
  State<PlateResultPreview> createState() => _PlateResultPreviewState();
}

class _PlateResultPreviewState extends State<PlateResultPreview> {
  final Map<int, ScrollController> _scrollControllers = {};
  final _exportService = const TableExportService();

  @override
  void dispose() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wizard.items.isEmpty) return const SizedBox.shrink();

    final tables = widget.wizard.generateTables();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _exportLongFormat(tables),
            icon: const Icon(Icons.view_list, size: 18),
            label: const Text('Export long Excel'),
          ),
        ),
        const SizedBox(height: 16),
        ...tables.asMap().entries.map(
          (entry) => _buildPlateGrid(entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildPlateGrid(int index, ProtocolTable table) {
    final rows = int.tryParse(table.metadata['rows'] ?? '8') ?? 8;
    final cols = int.tryParse(table.metadata['columns'] ?? '12') ?? 12;
    final controller = _scrollControllers.putIfAbsent(
      index,
      () => ScrollController(),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _plateTitle(table),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          TableExportActions(
            table: table,
            includeRowHeaders: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Scrollbar(
                  controller: controller,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Column(
                      children: [
                        _buildColumnHeaders(cols),
                        const SizedBox(height: 12),
                        ...List.generate(
                          rows,
                          (rowIndex) => _buildPlateRow(table, rowIndex, cols),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(int cols) {
    return Row(
      children: [
        const SizedBox(width: 35),
        ...List.generate(
          cols,
          (index) => SizedBox(
            width: 58,
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlateRow(ProtocolTable table, int rowIndex, int cols) {
    return Row(
      children: [
        SizedBox(
          width: 35,
          child: Text(
            String.fromCharCode(65 + rowIndex),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        ...List.generate(
          cols,
          (colIndex) => _buildWell(table, rowIndex, colIndex),
        ),
      ],
    );
  }

  Widget _buildWell(ProtocolTable table, int rowIndex, int colIndex) {
    final content = table.data[rowIndex][colIndex].toString();
    final colorHex = table.cellColors[rowIndex][colIndex];
    var bgColor = Colors.grey.shade50;
    if (colorHex.isNotEmpty) {
      bgColor = Color(
        int.parse(colorHex.replaceFirst('#', '0xFF')),
      ).withValues(alpha: 0.8);
    }

    final parts = content.split('\n');
    final name = parts.isNotEmpty ? parts[0] : '';
    final condition = parts.length > 1 ? parts[1] : '';
    final dilution = parts.length > 2 ? parts[2] : '';

    return Container(
      width: 55,
      height: 55,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: content.isNotEmpty
              ? Colors.grey.shade400
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: content.isEmpty
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (condition.isNotEmpty)
                  Text(
                    condition,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dilution.isNotEmpty)
                  Text(
                    dilution,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
    );
  }

  String _plateTitle(ProtocolTable table) {
    final plateNumber =
        table.metadata['plateNumber'] ??
        ((int.tryParse(table.metadata['plateIndex'] ?? '') ?? 0) + 1)
            .toString();
    final totalPlates = int.tryParse(table.metadata['totalPlates'] ?? '') ?? 1;
    if (totalPlates <= 1 && table.title.isNotEmpty) return table.title;
    return table.title.contains(plateNumber)
        ? table.title
        : '${table.title} $plateNumber';
  }

  Future<void> _exportLongFormat(List<ProtocolTable> tables) async {
    await _exportService.exportPlateLongToExcel(
      tables,
      title: widget.wizard.title,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Long-format Excel export ready')),
    );
  }
}
