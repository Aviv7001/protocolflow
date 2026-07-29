import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/completed_protocol.dart';
import '../models/project.dart';
import '../models/protocol.dart';
import '../models/protocol_table.dart';
import '../models/task.dart';
import '../services/dashboard_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

enum DashboardRange { sevenDays, thirtyDays, ninetyDays, allTime }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _service = DashboardService();
  DashboardData? _data;
  Object? _error;
  DashboardRange _range = DashboardRange.thirtyDays;
  String? _selectedProjectId;
  static const String _allProjectsFilter = '__all__';
  static const String _unassignedProjectsFilter = '__unassigned__';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.load();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    await _load();
  }

  Widget _refreshable(Widget child) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1800,
                minHeight: math.max(0, constraints.maxHeight - 40),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _refreshable(
        _DashboardMessage(
          icon: Icons.error_outline,
          title: 'Dashboard could not be loaded',
          actionLabel: 'Try again',
          onAction: () {
            setState(() => _error = null);
            _load();
          },
        ),
      );
    }
    final data = _data;
    if (data == null) {
      return _refreshable(const Center(child: CircularProgressIndicator()));
    }

    final completed = data.completedProtocols
        .where((item) => _inRange(item.completedAt))
        .toList();
    final created = data.protocols
        .where((item) => _inRange(item.createdAt))
        .toList();
    final filteredProtocols = data.protocols
        .where(_matchesSelectedProject)
        .toList();
    final filteredRunning = data.runningProtocols
        .where((item) => _matchesSelectedProject(item.protocol))
        .toList();
    final filteredCompleted = completed
        .where((item) => _matchesSelectedProject(item.protocol))
        .toList();
    final filteredCreated = created.where(_matchesSelectedProject).toList();

    return _refreshable(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _responsivePanels([
            _DashboardPanel(
              title: 'Protocol activity',
              subtitle: 'Created and completed runs',
              child: _buildProjectAwarePanelChild(
                _buildActivityChart(filteredCreated, filteredCompleted),
              ),
            ),
            _DashboardPanel(
              title: 'Today\'s task status',
              subtitle: '${data.todayTasks.length} tasks',
              child: _buildTaskChart(data.todayTasks),
            ),
          ]),
          const SizedBox(height: 16),
          _responsivePanels([
            _DashboardPanel(
              title: 'Protocol status',
              subtitle: 'Library and run distribution',
              child: _buildProjectAwarePanelChild(
                _buildProtocolStatus(
                  protocols: filteredProtocols,
                  runningCount: filteredRunning.length,
                  completedCount: filteredCompleted.length,
                ),
              ),
            ),
            _DashboardPanel(
              title: 'Most used protocols',
              subtitle: 'Ranked by completed runs',
              child: _buildTopProtocols(completed),
            ),
          ]),
          const SizedBox(height: 16),
          _responsivePanels([
            _DashboardPanel(
              title: 'Activity heatmap',
              subtitle: 'Created protocols and completed runs',
              child: _buildHeatmap(data),
            ),
            _DashboardPanel(
              title: 'Lab tool tables',
              subtitle: 'Generated and saved table inventory',
              child: _buildToolUsage(data),
            ),
          ]),
          const SizedBox(height: 16),
          _responsivePanels([
            _DashboardPanel(
              title: 'Running now',
              subtitle: '${data.runningProtocols.length} active runs',
              child: _buildRunning(data),
            ),
            _DashboardPanel(
              title: 'Recently completed',
              subtitle: 'Latest protocol runs',
              child: _buildRecentCompleted(data.completedProtocols),
            ),
            _DashboardPanel(
              title: 'Recent tables',
              subtitle: '${data.savedTables.length} saved tables',
              child: _buildRecentTables(data.savedTables),
            ),
            _DashboardPanel(
              title: 'Recent exports',
              subtitle: '${data.exports.length} recorded exports',
              child: _buildRecentExports(data),
            ),
          ], minPanelWidth: 300),
          const SizedBox(height: 16),
          _responsivePanels([
            _DashboardPanel(
              title: 'Data footprint',
              subtitle: 'Estimated local and Drive sync payload size',
              child: _buildDataFootprint(
                data.footprint,
                hasDriveAccount: data.hasDriveAccount,
              ),
            ),
            _DashboardPanel(
              title: 'Data health',
              subtitle: 'Google Drive synchronization and attention items',
              child: _buildDataHealth(data),
            ),
          ], minPanelWidth: 420),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text(
              'Protocol activity, task progress, and lab data at a glance.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        );
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 14),
              _buildRangeControl(compact: true),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            SizedBox(width: 460, child: _buildRangeControl()),
          ],
        );
      },
    );
  }

  Widget _buildRangeControl({bool compact = false}) {
    final control = SegmentedButton<DashboardRange>(
      segments: DashboardRange.values
          .map(
            (range) => ButtonSegment(
              value: range,
              label: Text(
                compact ? _compactRangeLabel(range) : _rangeLabel(range),
              ),
            ),
          )
          .toList(),
      selected: {_range},
      onSelectionChanged: (selection) {
        setState(() => _range = selection.first);
      },
    );
    if (!compact) return control;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: control,
    );
  }

  Widget _responsivePanels(
    List<Widget> panels, {
    double minPanelWidth = 380,
    int maxColumns = 2,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          math.min(
            maxColumns,
            math.min(
              panels.length,
              (constraints.maxWidth / minPanelWidth).floor(),
            ),
          ),
        );
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final panelMinHeight = constraints.maxWidth >= 1200
            ? 300.0
            : constraints.maxWidth >= 900
            ? 260.0
            : 0.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: panels
              .map(
                (panel) => SizedBox(
                  width: width,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: panelMinHeight),
                    child: panel,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  double _chartHeight() {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1500) return 260;
    if (width >= 1100) return 225;
    return 190;
  }

  Widget _buildActivityChart(
    List<Protocol> created,
    List<CompletedProtocol> completed,
  ) {
    final points = _activityPoints(created, completed);
    if (points.every((point) => point.created == 0 && point.completed == 0)) {
      return const _EmptyChart('No protocol activity in this period.');
    }
    final maxValue = points.fold<int>(
      1,
      (value, point) =>
          math.max(value, math.max(point.created, point.completed)),
    );
    return Column(
      children: [
        const _Legend(
          items: [
            _LegendData('Created', AppColors.primary),
            _LegendData('Completed', AppColors.success),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _chartHeight(),
          child: LineChart(
            LineChartData(
              maxY: maxValue.toDouble() + 1,
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context).dividerColor,
                  strokeWidth: 1,
                ),
              ),
              lineBarsData: [
                _activityLine(
                  points.map((point) => point.created).toList(),
                  AppColors.primary,
                ),
                _activityLine(
                  points.map((point) => point.completed).toList(),
                  AppColors.success,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: points
              .map(
                (point) => Expanded(
                  child: Text(
                    point.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTaskChart(List<Task> tasks) {
    final values = TaskStatus.values
        .map((status) => tasks.where((task) => task.status == status).length)
        .toList();
    if (tasks.isEmpty) return const _EmptyChart('No tasks for today.');
    const colors = [AppColors.textSecondary, AppColors.info, AppColors.success];
    final chart = SizedBox(
      height: _chartHeight(),
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 42,
          sectionsSpace: 2,
          sections: List.generate(
            values.length,
            (index) => PieChartSectionData(
              value: values[index].toDouble(),
              color: colors[index],
              title: values[index] == 0 ? '' : '${values[index]}',
              radius: 42,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
    const legend = _Legend(
      vertical: true,
      items: [
        _LegendData('Not started', AppColors.textSecondary),
        _LegendData('In progress', AppColors.info),
        _LegendData('Completed', AppColors.success),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [chart, const SizedBox(height: 10), legend],
          );
        }
        return Row(
          children: [
            Expanded(child: chart),
            const SizedBox(width: 12),
            const Flexible(child: legend),
          ],
        );
      },
    );
  }

  LineChartBarData _activityLine(List<int> values, Color color) {
    return LineChartBarData(
      spots: values
          .asMap()
          .entries
          .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
          .toList(),
      color: color,
      barWidth: 3,
      dotData: FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _buildProjectAwarePanelChild(Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildProjectFilter(), const SizedBox(height: 12), child],
    );
  }

  Widget _buildProjectFilter() {
    final project = _selectedProject();
    final color = project == null
        ? AppColors.primary
        : Color(project.colorValue);
    return PopupMenuButton<String>(
      tooltip: 'Filter by project',
      initialValue: _selectedProjectId ?? _allProjectsFilter,
      onSelected: (value) => setState(
        () => _selectedProjectId = value == _allProjectsFilter ? null : value,
      ),
      itemBuilder: (context) {
        final data = _data;
        final projects = data?.projects ?? const <Project>[];
        return [
          const PopupMenuItem<String>(
            value: _allProjectsFilter,
            child: ListTile(
              leading: Icon(Icons.all_inbox_outlined),
              title: Text('All projects'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          for (final project in projects)
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
            value: _unassignedProjectsFilter,
            child: ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('Unassigned'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ];
      },
      child: Chip(
        avatar: Icon(_projectFilterIcon(), color: color, size: 18),
        label: Text(_projectFilterLabel()),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
    );
  }

  Widget _buildProtocolStatus({
    required List<Protocol> protocols,
    required int runningCount,
    required int completedCount,
  }) {
    final values = [
      protocols.where((item) => item.isTemplate).length,
      protocols.where((item) => !item.isTemplate).length,
      runningCount,
      completedCount,
    ];
    if (values.every((value) => value == 0)) {
      return const _EmptyChart('No protocol data yet.');
    }
    const colors = [
      Color(0xFF7B61A8),
      AppColors.primary,
      AppColors.info,
      AppColors.success,
    ];
    final chart = SizedBox(
      height: _chartHeight(),
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 38,
          sectionsSpace: 2,
          sections: List.generate(
            values.length,
            (index) => PieChartSectionData(
              value: values[index].toDouble(),
              color: colors[index],
              title: values[index] == 0 ? '' : '${values[index]}',
              radius: 44,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
    const legend = _Legend(
      vertical: true,
      items: [
        _LegendData('Templates', Color(0xFF7B61A8)),
        _LegendData('Ready', AppColors.primary),
        _LegendData('Running', AppColors.info),
        _LegendData('Completed', AppColors.success),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [chart, const SizedBox(height: 10), legend],
          );
        }
        return Row(
          children: [
            Expanded(child: chart),
            const SizedBox(width: 12),
            const Flexible(child: legend),
          ],
        );
      },
    );
  }

  Widget _buildTopProtocols(List<CompletedProtocol> completed) {
    final counts = <String, int>{};
    for (final item in completed) {
      counts.update(
        item.protocol.title,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const _EmptyChart('Complete a protocol to build usage rankings.');
    }
    final top = entries.take(5).toList();
    final maxValue = top.first.value;
    return Column(
      children: top
          .map(
            (entry) => _RankBar(
              label: entry.key,
              value: entry.value,
              maxValue: maxValue,
              color: AppColors.primary,
            ),
          )
          .toList(),
    );
  }

  Widget _buildHeatmap(DashboardData data) {
    final today = _day(DateTime.now());
    final counts = <DateTime, int>{};
    for (final protocol in data.protocols) {
      counts.update(
        _day(protocol.createdAt),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    for (final item in data.completedProtocols) {
      counts.update(
        _day(item.completedAt),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final days = List.generate(
      35,
      (index) => today.subtract(Duration(days: 34 - index)),
    );
    final maxValue = counts.values.fold<int>(1, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: days.map((day) {
            final count = counts[day] ?? 0;
            final opacity = count == 0 ? 0.08 : 0.2 + (count / maxValue) * 0.8;
            return Tooltip(
              message: '${_dateLabel(day)}: $count activities',
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        const Text(
          'Last 35 days',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildToolUsage(DashboardData data) {
    final tables = <String, ProtocolTable>{};
    for (final table in data.savedTables) {
      tables[table.id] = table;
    }
    for (final protocol in data.protocols) {
      for (final table in protocol.tables) {
        tables[table.id] = table;
      }
    }
    final counts = <TableType, int>{};
    for (final table in tables.values) {
      counts.update(table.type, (value) => value + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const _EmptyChart('Generated lab-tool tables will appear here.');
    }
    final maxValue = entries.first.value;
    const colors = [
      AppColors.info,
      Color(0xFF7B61A8),
      AppColors.success,
      Color(0xFFCE7A24),
      AppColors.primary,
      Color(0xFFB14C68),
      AppColors.textSecondary,
    ];
    return Column(
      children: entries
          .asMap()
          .entries
          .map(
            (entry) => _RankBar(
              label: _tableTypeLabel(entry.value.key),
              value: entry.value.value,
              maxValue: maxValue,
              color: colors[entry.key % colors.length],
            ),
          )
          .toList(),
    );
  }

  Widget _buildRunning(DashboardData data) {
    if (data.runningProtocols.isEmpty) {
      return const _EmptyChart('No protocols are running.');
    }
    return Column(
      children: data.runningProtocols
          .take(4)
          .map(
            (item) => _ActivityRow(
              icon: Icons.play_circle_outline,
              color: AppColors.info,
              title: item.protocol.title,
              subtitle: 'Started ${_dateLabel(item.startedAt)}',
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecentCompleted(List<CompletedProtocol> items) {
    final sorted = [...items]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    if (sorted.isEmpty) return const _EmptyChart('No completed protocols yet.');
    return Column(
      children: sorted
          .take(4)
          .map(
            (item) => _ActivityRow(
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              title: item.protocol.title,
              subtitle: _dateLabel(item.completedAt),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecentTables(List<ProtocolTable> tables) {
    if (tables.isEmpty) return const _EmptyChart('No saved tables yet.');
    return Column(
      children: tables.reversed
          .take(4)
          .map(
            (table) => _ActivityRow(
              icon: Icons.table_chart_outlined,
              color: AppColors.primary,
              title: table.title.isEmpty ? 'Untitled table' : table.title,
              subtitle: _tableTypeLabel(table.type),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecentExports(DashboardData data) {
    if (data.exports.isEmpty) {
      return const _EmptyChart('New exports will be recorded here.');
    }
    return Column(
      children: data.exports
          .take(4)
          .map(
            (record) => _ActivityRow(
              icon: Icons.ios_share_outlined,
              color: const Color(0xFFB14C68),
              title: record.label,
              subtitle: '${record.format} - ${_dateLabel(record.createdAt)}',
            ),
          )
          .toList(),
    );
  }

  Widget _buildDataHealth(DashboardData data) {
    final protocols = data.protocols.where((item) => !item.isTemplate).toList();
    final templates = data.protocols.where((item) => item.isTemplate).toList();
    final tableCount = data.savedTables.length;
    final tableHealth = switch (data.savedTablesSyncState) {
      SavedTablesSyncState.synced => _SyncHealth(synced: tableCount),
      SavedTablesSyncState.pending => _SyncHealth(pending: tableCount),
      SavedTablesSyncState.error => _SyncHealth(issues: tableCount),
    };

    return Column(
      children: [
        const _DataHealthHeader(),
        const Divider(height: 20),
        _DataHealthRow(
          icon: Icons.folder_copy_outlined,
          label: 'Projects',
          health: _SyncHealth.fromBundleState(
            total: data.projects.length,
            state: data.projectsSyncState,
          ),
        ),
        _DataHealthRow(
          icon: Icons.article_outlined,
          label: 'Protocols',
          health: _SyncHealth.fromProtocols(protocols),
        ),
        _DataHealthRow(
          icon: Icons.copy_all_outlined,
          label: 'Templates',
          health: _SyncHealth.fromProtocols(templates),
        ),
        _DataHealthRow(
          icon: Icons.check_circle_outline,
          label: 'Completed runs',
          health: _SyncHealth.fromCompletedProtocols(data.completedProtocols),
        ),
        _DataHealthRow(
          icon: Icons.table_chart_outlined,
          label: 'Tables',
          health: tableHealth,
        ),
        _DataHealthRow(
          icon: Icons.today_outlined,
          label: 'Today tasks',
          health: _SyncHealth.fromBundleState(
            total: data.todayTasks.length,
            state: data.tasksSyncState,
          ),
        ),
        _DataHealthRow(
          icon: Icons.history_outlined,
          label: 'Task history',
          health: _SyncHealth.fromBundleState(
            total: data.taskHistory.length,
            state: data.tasksSyncState,
          ),
        ),
        _DataHealthRow(
          icon: Icons.straighten,
          label: 'Measuring tools',
          health: _SyncHealth.fromBundleState(
            total: data.measuringTools.length,
            state: data.measuringToolsSyncState,
          ),
        ),
        const Divider(height: 24),
        Row(
          children: [
            const Icon(
              Icons.play_circle_outline,
              color: AppColors.info,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('Unfinished runs')),
            Text(
              '${data.runningProtocols.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataFootprint(
    DashboardFootprint footprint, {
    required bool hasDriveAccount,
  }) {
    final colors = [
      AppColors.primary,
      const Color(0xFF7B61A8),
      AppColors.success,
      AppColors.info,
      const Color(0xFFCE7A24),
      const Color(0xFFB14C68),
    ];
    final segments = footprint.segments.asMap().entries.map((entry) {
      return _FootprintSegmentView(
        label: entry.value.label,
        localBytes: entry.value.localBytes,
        syncBytes: entry.value.syncBytes,
        color: colors[entry.key % colors.length],
      );
    }).toList();

    if (footprint.localBytes == 0 && footprint.syncBytes == 0) {
      return const _EmptyChart('No stored ProtocolFlow data yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FootprintBar(
          label: 'Local browser data',
          totalBytes: footprint.localBytes,
          segments: segments
              .map(
                (segment) => _FootprintBarSegment(
                  bytes: segment.localBytes,
                  color: segment.color,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        _FootprintBar(
          label: hasDriveAccount ? 'Drive payload estimate' : 'Drive sync data',
          totalBytes: hasDriveAccount ? footprint.syncBytes : 0,
          unavailableLabel: hasDriveAccount ? null : 'Not signed in',
          segments: segments
              .map(
                (segment) => _FootprintBarSegment(
                  bytes: hasDriveAccount ? segment.syncBytes : 0,
                  color: segment.color,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: segments
              .map(
                (segment) => _FootprintLegendItem(
                  label: segment.label,
                  color: segment.color,
                  localBytes: segment.localBytes,
                  syncBytes: segment.syncBytes,
                  hasDriveAccount: hasDriveAccount,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  bool _matchesSelectedProject(Protocol protocol) {
    final selected = _selectedProjectId;
    if (selected == null) return true;
    final projectId = protocol.projectId;
    if (selected == _unassignedProjectsFilter) {
      final projects = _data?.projects ?? const <Project>[];
      return projectId == null ||
          projectId.isEmpty ||
          !projects.any((project) => project.id == projectId);
    }
    return projectId == selected;
  }

  Project? _selectedProject() {
    final projects = _data?.projects ?? const <Project>[];
    for (final project in projects) {
      if (project.id == _selectedProjectId) return project;
    }
    return null;
  }

  IconData _projectFilterIcon() {
    if (_selectedProjectId == _unassignedProjectsFilter) {
      return Icons.folder_off_outlined;
    }
    if (_selectedProjectId == null) return Icons.all_inbox_outlined;
    return Icons.folder_outlined;
  }

  String _projectFilterLabel() {
    if (_selectedProjectId == null) return 'All projects';
    if (_selectedProjectId == _unassignedProjectsFilter) return 'Unassigned';
    return _selectedProject()?.name ?? 'Unassigned';
  }

  bool _inRange(DateTime value) {
    final days = switch (_range) {
      DashboardRange.sevenDays => 7,
      DashboardRange.thirtyDays => 30,
      DashboardRange.ninetyDays => 90,
      DashboardRange.allTime => null,
    };
    return days == null ||
        value.isAfter(DateTime.now().subtract(Duration(days: days)));
  }

  List<_ActivityPoint> _activityPoints(
    List<Protocol> created,
    List<CompletedProtocol> completed,
  ) {
    var days = switch (_range) {
      DashboardRange.sevenDays => 7,
      DashboardRange.thirtyDays => 30,
      DashboardRange.ninetyDays => 90,
      DashboardRange.allTime => 365,
    };
    if (_range == DashboardRange.allTime) {
      final dates = [
        ...created.map((item) => item.createdAt),
        ...completed.map((item) => item.completedAt),
      ];
      if (dates.isNotEmpty) {
        final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
        days = math.max(7, DateTime.now().difference(earliest).inDays + 1);
      }
    }
    const buckets = 7;
    final bucketDays = math.max(1, (days / buckets).ceil());
    final end = _day(DateTime.now()).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: bucketDays * buckets));
    return List.generate(buckets, (index) {
      final from = start.add(Duration(days: bucketDays * index));
      final to = from.add(Duration(days: bucketDays));
      return _ActivityPoint(
        label: '${from.month}/${from.day}',
        created: created
            .where(
              (item) =>
                  !item.createdAt.isBefore(from) && item.createdAt.isBefore(to),
            )
            .length,
        completed: completed
            .where(
              (item) =>
                  !item.completedAt.isBefore(from) &&
                  item.completedAt.isBefore(to),
            )
            .length,
      );
    });
  }

  String _rangeLabel(DashboardRange range) => switch (range) {
    DashboardRange.sevenDays => '7 days',
    DashboardRange.thirtyDays => '30 days',
    DashboardRange.ninetyDays => '90 days',
    DashboardRange.allTime => 'All time',
  };

  String _compactRangeLabel(DashboardRange range) => switch (range) {
    DashboardRange.sevenDays => '7d',
    DashboardRange.thirtyDays => '30d',
    DashboardRange.ninetyDays => '90d',
    DashboardRange.allTime => 'All',
  };

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _tableTypeLabel(TableType type) => switch (type) {
    TableType.generic => 'Generic',
    TableType.materialList => 'Material list',
    TableType.plateLayout => 'Plate layout',
    TableType.masterMix => 'Master mix',
    TableType.checklist => 'Checklist',
    TableType.staining => 'Staining',
    TableType.serialDilution => 'Serial dilution',
  };
}

class _DashboardPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _DashboardPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final expanded = MediaQuery.sizeOf(context).width >= 1100;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(expanded ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: expanded ? 22 : 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String text;
  const _EmptyChart(this.text);
  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).width >= 1100 ? 190 : 120,
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}

class _LegendData {
  final String label;
  final Color color;
  const _LegendData(this.label, this.color);
}

class _Legend extends StatelessWidget {
  final List<_LegendData> items;
  final bool vertical;
  const _Legend({required this.items, this.vertical = false});
  @override
  Widget build(BuildContext context) {
    final children = items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, color: item.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(item.label, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        )
        .toList();
    return vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          )
        : Wrap(children: children);
  }
}

class _FootprintSegmentView {
  final String label;
  final int localBytes;
  final int syncBytes;
  final Color color;

  const _FootprintSegmentView({
    required this.label,
    required this.localBytes,
    required this.syncBytes,
    required this.color,
  });
}

class _FootprintBarSegment {
  final int bytes;
  final Color color;

  const _FootprintBarSegment({required this.bytes, required this.color});
}

class _FootprintBar extends StatelessWidget {
  final String label;
  final int totalBytes;
  final List<_FootprintBarSegment> segments;
  final String? unavailableLabel;

  const _FootprintBar({
    required this.label,
    required this.totalBytes,
    required this.segments,
    this.unavailableLabel,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSegments = segments
        .where((segment) => segment.bytes > 0)
        .toList();
    final isUnavailable = unavailableLabel != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              unavailableLabel ?? _formatBytes(totalBytes),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: isUnavailable || visibleSegments.isEmpty
              ? const SizedBox.expand()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final total = visibleSegments.fold<int>(
                      0,
                      (sum, segment) => sum + segment.bytes,
                    );
                    final minWidth =
                        visibleSegments.length * 6 <= constraints.maxWidth
                        ? 6.0
                        : 0.0;
                    final proportionalWidth =
                        constraints.maxWidth -
                        minWidth * visibleSegments.length;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(color: AppColors.surfaceContainer),
                        ),
                        Row(
                          children: visibleSegments.map((segment) {
                            final exactWidth =
                                minWidth +
                                proportionalWidth * segment.bytes / total;
                            return Container(
                              width: exactWidth,
                              color: segment.color,
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FootprintLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final int localBytes;
  final int syncBytes;
  final bool hasDriveAccount;

  const _FootprintLegendItem({
    required this.label,
    required this.color,
    required this.localBytes,
    required this.syncBytes,
    required this.hasDriveAccount,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 136, maxWidth: 180),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hasDriveAccount
                      ? '${_formatBytes(localBytes)} local, ${_formatBytes(syncBytes)} sync'
                      : '${_formatBytes(localBytes)} local',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

class _RankBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;
  const _RankBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: value / maxValue,
          minHeight: 8,
          color: color,
          backgroundColor: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(icon, color: color),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14),
    ),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
  );
}

class _SyncHealth {
  final int synced;
  final int pending;
  final int issues;

  const _SyncHealth({this.synced = 0, this.pending = 0, this.issues = 0});

  int get total => synced + pending + issues;

  factory _SyncHealth.fromProtocols(List<Protocol> protocols) {
    var synced = 0;
    var pending = 0;
    var issues = 0;
    for (final protocol in protocols) {
      switch (protocol.syncStatus) {
        case ProtocolSyncStatus.synced:
          synced++;
        case ProtocolSyncStatus.localOnly:
        case ProtocolSyncStatus.modified:
          pending++;
        case ProtocolSyncStatus.conflict:
        case ProtocolSyncStatus.error:
          issues++;
      }
    }
    return _SyncHealth(synced: synced, pending: pending, issues: issues);
  }

  factory _SyncHealth.fromCompletedProtocols(List<CompletedProtocol> items) {
    var synced = 0;
    var pending = 0;
    var issues = 0;
    for (final item in items) {
      switch (item.syncStatus) {
        case ProtocolSyncStatus.synced:
          synced++;
        case ProtocolSyncStatus.localOnly:
        case ProtocolSyncStatus.modified:
          pending++;
        case ProtocolSyncStatus.conflict:
        case ProtocolSyncStatus.error:
          issues++;
      }
    }
    return _SyncHealth(synced: synced, pending: pending, issues: issues);
  }

  factory _SyncHealth.fromBundleState({
    required int total,
    required SyncBundleState state,
  }) {
    return switch (state) {
      SyncBundleState.synced => _SyncHealth(synced: total),
      SyncBundleState.pending => _SyncHealth(pending: total),
      SyncBundleState.error => _SyncHealth(issues: total),
    };
  }
}

class _DataHealthHeader extends StatelessWidget {
  const _DataHealthHeader();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      SizedBox(width: 30),
      Expanded(child: SizedBox()),
      _HealthColumnLabel('Total'),
      _HealthColumnLabel('Synced'),
      _HealthColumnLabel('Pending'),
      _HealthColumnLabel('Issues'),
    ],
  );
}

const double _healthColumnWidth = 44;

class _HealthColumnLabel extends StatelessWidget {
  final String label;
  const _HealthColumnLabel(this.label);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _healthColumnWidth,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
    ),
  );
}

class _DataHealthRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final _SyncHealth health;

  const _DataHealthRow({
    required this.icon,
    required this.label,
    required this.health,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        _HealthValue(value: health.total),
        _HealthValue(
          key: Key('data-health-${label.toLowerCase()}-synced'),
          value: health.synced,
          color: AppColors.success,
        ),
        _HealthValue(value: health.pending, color: AppColors.warning),
        _HealthValue(value: health.issues, color: AppColors.error),
      ],
    ),
  );
}

class _HealthValue extends StatelessWidget {
  final int value;
  final Color? color;

  const _HealthValue({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _healthColumnWidth,
    child: Text(
      '$value',
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _DashboardMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 38, color: AppColors.error),
        const SizedBox(height: 12),
        Text(title),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    ),
  );
}

class _ActivityPoint {
  final String label;
  final int created;
  final int completed;
  const _ActivityPoint({
    required this.label,
    required this.created,
    required this.completed,
  });
}
