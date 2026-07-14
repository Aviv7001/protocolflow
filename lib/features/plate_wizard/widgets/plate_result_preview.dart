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
          Row(
            children: [
              Expanded(
                child: Text(
                  _plateTitle(table),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Full screen view',
                onPressed: () => _openFullScreenPlate(table, rows, cols),
                icon: const Icon(Icons.fullscreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TableExportActions(
            table: table,
            includeRowHeaders: true,
            child: _buildScrollablePlateBoard(controller, table, rows, cols),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollablePlateBoard(
    ScrollController controller,
    ProtocolTable table,
    int rows,
    int cols,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _buildPlateFrame(
        child: Scrollbar(
          controller: controller,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: _buildPlateBoard(table, rows, cols),
          ),
        ),
      ),
    );
  }

  Widget _buildPlateFrame({required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  Widget _buildPlateBoard(ProtocolTable table, int rows, int cols) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildColumnHeaders(cols),
        const SizedBox(height: 12),
        ...List.generate(
          rows,
          (rowIndex) => _buildPlateRow(table, rowIndex, cols),
        ),
      ],
    );
  }

  void _openFullScreenPlate(ProtocolTable table, int rows, int cols) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullScreenPlateView(
          title: _plateTitle(table),
          boardWidth: _plateBoardWidth(cols),
          boardHeight: _plateBoardHeight(rows),
          child: _buildPlateFrame(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: _buildPlateBoard(table, rows, cols),
            ),
          ),
        ),
      ),
    );
  }

  double _plateBoardWidth(int cols) => 32 + 35 + (cols * 59);

  double _plateBoardHeight(int rows) => 44 + 12 + (rows * 59) + 44;

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

class _FullScreenPlateView extends StatefulWidget {
  const _FullScreenPlateView({
    required this.title,
    required this.boardWidth,
    required this.boardHeight,
    required this.child,
  });

  final String title;
  final double boardWidth;
  final double boardHeight;
  final Widget child;

  @override
  State<_FullScreenPlateView> createState() => _FullScreenPlateViewState();
}

class _FullScreenPlateViewState extends State<_FullScreenPlateView> {
  final TransformationController _controller = TransformationController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  double _fitScale = 1;
  Size? _lastViewportSize;

  @override
  void dispose() {
    _controller.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Zoom out',
            onPressed: () => _scaleBy(0.82),
            icon: const Icon(Icons.zoom_out),
          ),
          IconButton(
            tooltip: 'Reset zoom',
            onPressed: _resetZoom,
            icon: const Icon(Icons.center_focus_strong),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: () => _scaleBy(1.22),
            icon: const Icon(Icons.zoom_in),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _scheduleAutoFit(constraints.biggest);
          final contentWidth = widget.boardWidth > constraints.maxWidth
              ? widget.boardWidth
              : constraints.maxWidth;
          final contentHeight = widget.boardHeight > constraints.maxHeight
              ? widget.boardHeight
              : constraints.maxHeight;

          return Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.vertical,
            child: SingleChildScrollView(
              controller: _verticalController,
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 20),
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 12, bottom: 12),
                  child: SizedBox(
                    width: contentWidth,
                    height: contentHeight,
                    child: Center(
                      child: InteractiveViewer(
                        transformationController: _controller,
                        minScale: 0.45,
                        maxScale: 4,
                        boundaryMargin: const EdgeInsets.all(80),
                        constrained: false,
                        trackpadScrollCausesScale: true,
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _scaleBy(double factor) {
    final next = _controller.value.clone()..scaleByDouble(factor, factor, 1, 1);
    setState(() => _controller.value = next);
  }

  void _resetZoom() {
    setState(() => _applyScale(_fitScale));
  }

  void _scheduleAutoFit(Size viewportSize) {
    if (_lastViewportSize == viewportSize) return;
    _lastViewportSize = viewportSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nextFitScale = _calculateFitScale(viewportSize);
      setState(() {
        _fitScale = nextFitScale;
        _applyScale(nextFitScale);
      });
    });
  }

  double _calculateFitScale(Size viewportSize) {
    const horizontalPadding = 44.0;
    const verticalPadding = 44.0;
    final availableWidth = (viewportSize.width - horizontalPadding).clamp(
      1.0,
      double.infinity,
    );
    final availableHeight = (viewportSize.height - verticalPadding).clamp(
      1.0,
      double.infinity,
    );
    final scaleX = availableWidth / widget.boardWidth;
    final scaleY = availableHeight / widget.boardHeight;
    final fitScale = widget.boardWidth >= widget.boardHeight ? scaleX : scaleY;
    return fitScale.clamp(0.45, 1.6).toDouble();
  }

  void _applyScale(double scale) {
    _controller.value = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);
  }
}
