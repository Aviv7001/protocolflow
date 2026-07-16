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
  final _exportService = const TableExportService();

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
          (entry) => _buildPlateGrid(entry.key, entry.value, tables),
        ),
      ],
    );
  }

  Widget _buildPlateGrid(
    int index,
    ProtocolTable table,
    List<ProtocolTable> tables,
  ) {
    final rows = int.tryParse(table.metadata['rows'] ?? '8') ?? 8;
    final cols = int.tryParse(table.metadata['columns'] ?? '12') ?? 12;

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
                onPressed: () => _openFullScreenPlate(tables, index),
                icon: const Icon(Icons.fullscreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TableExportActions(
            table: table,
            includeRowHeaders: true,
            child: _buildFittedPlateBoard(table, rows, cols),
          ),
        ],
      ),
    );
  }

  Widget _buildFittedPlateBoard(ProtocolTable table, int rows, int cols) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const framePadding = EdgeInsets.fromLTRB(16, 16, 16, 28);
        final boardWidth = _plateBoardWidth(
          cols + 1,
        ); // +1 so the columns wont over flow the container
        final boardHeight = _plateBoardHeight(rows);
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : boardWidth;
        final scale = availableWidth < boardWidth
            ? (availableWidth / boardWidth).clamp(0.2, 1.0).toDouble()
            : 1.0;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: boardWidth * scale,
            height: boardHeight * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: boardWidth,
                maxWidth: boardWidth,
                minHeight: boardHeight,
                maxHeight: boardHeight,
                child: SizedBox(
                  width: boardWidth,
                  height: boardHeight,
                  child: _buildPlateFrame(
                    child: Padding(
                      padding: framePadding,
                      child: _buildPlateBoard(table, rows, cols),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

  void _openFullScreenPlate(List<ProtocolTable> tables, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullScreenPlateView(
          initialIndex: initialIndex,
          pages: tables.map((table) {
            final rows = int.tryParse(table.metadata['rows'] ?? '8') ?? 8;
            final cols = int.tryParse(table.metadata['columns'] ?? '12') ?? 12;
            return _FullScreenPlatePage(
              title: _plateTitle(table),
              rows: rows,
              cols: cols,
              boardWidth: _plateBoardWidth(cols + 1),
              boardHeight: _plateBoardHeight(rows),
              child: _buildPlateFrame(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: _buildPlateBoard(table, rows, cols),
                ),
              ),
            );
          }).toList(),
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
    final content = _cellText(table, rowIndex, colIndex);
    final colorHex = _cellColor(table, rowIndex, colIndex);
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

  String _cellText(ProtocolTable table, int rowIndex, int colIndex) {
    if (rowIndex < 0 ||
        colIndex < 0 ||
        rowIndex >= table.data.length ||
        colIndex >= table.data[rowIndex].length) {
      return '';
    }
    return table.data[rowIndex][colIndex]?.toString() ?? '';
  }

  String _cellColor(ProtocolTable table, int rowIndex, int colIndex) {
    if (rowIndex < 0 ||
        colIndex < 0 ||
        rowIndex >= table.cellColors.length ||
        colIndex >= table.cellColors[rowIndex].length) {
      return '';
    }
    return table.cellColors[rowIndex][colIndex];
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

class _FullScreenPlatePage {
  const _FullScreenPlatePage({
    required this.title,
    required this.rows,
    required this.cols,
    required this.boardWidth,
    required this.boardHeight,
    required this.child,
  });

  final String title;
  final int rows;
  final int cols;
  final double boardWidth;
  final double boardHeight;
  final Widget child;
}

class _FullScreenPlateView extends StatefulWidget {
  const _FullScreenPlateView({required this.pages, required this.initialIndex});

  final List<_FullScreenPlatePage> pages;
  final int initialIndex;

  @override
  State<_FullScreenPlateView> createState() => _FullScreenPlateViewState();
}

class _FullScreenPlateViewState extends State<_FullScreenPlateView> {
  final TransformationController _controller = TransformationController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  double _fitScale = 1;
  Size? _lastViewportSize;
  late int _plateIndex;

  _FullScreenPlatePage get _page => widget.pages[_plateIndex];

  @override
  void initState() {
    super.initState();
    _plateIndex = widget.pages.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.pages.length - 1);
  }

  @override
  void didUpdateWidget(covariant _FullScreenPlateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_plateIndex >= widget.pages.length) {
      _plateIndex = widget.pages.isEmpty ? 0 : widget.pages.length - 1;
      _lastViewportSize = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(_page.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
          final contentWidth = _page.boardWidth > constraints.maxWidth
              ? _page.boardWidth
              : constraints.maxWidth;
          final contentHeight = _page.boardHeight > constraints.maxHeight
              ? _page.boardHeight
              : constraints.maxHeight;

          return Stack(
            children: [
              Scrollbar(
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
                            child: _page.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.pages.length > 1)
                Positioned(right: 16, bottom: 16, child: _buildPlatePager()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlatePager() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Plate ${_plateIndex + 1}/${widget.pages.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            _pagerButton(
              tooltip: 'Previous plate',
              icon: Icons.chevron_left,
              onPressed: _plateIndex > 0
                  ? () => _setPlateIndex(_plateIndex - 1)
                  : null,
            ),
            _pagerButton(
              tooltip: 'Next plate',
              icon: Icons.chevron_right,
              onPressed: _plateIndex < widget.pages.length - 1
                  ? () => _setPlateIndex(_plateIndex + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagerButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
    );
  }

  void _setPlateIndex(int index) {
    setState(() {
      _plateIndex = index;
      _lastViewportSize = null;
      if (_horizontalController.hasClients) _horizontalController.jumpTo(0);
      if (_verticalController.hasClients) _verticalController.jumpTo(0);
    });
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
    final scaleX = availableWidth / _page.boardWidth;
    final scaleY = availableHeight / _page.boardHeight;
    final fitScale = _page.cols >= _page.rows ? scaleX : scaleY;
    return fitScale.clamp(0.45, 1.6).toDouble();
  }

  void _applyScale(double scale) {
    _controller.value = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);
  }
}
