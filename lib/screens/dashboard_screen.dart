import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/completed_protocol.dart';
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
                maxWidth: 1440,
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
    final completedTasks = [
      ...data.taskHistory.where(
        (task) => task.completedAt != null && _inRange(task.completedAt!),
      ),
      ...data.todayTasks.where((task) => task.status == TaskStatus.completed),
    ];
    final durations = completed
        .where((item) => item.startedAt != null)
        .map((item) => item.completedAt.difference(item.startedAt!))
        .where((duration) => !duration.isNegative)
        .toList();

    return _refreshable(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildKpis(
            data,
            created,
            completed,
            completedTasks.length,
            durations,
          ),
          const SizedBox(height: 16),
          _responsivePanels([
            _DashboardPanel(
              title: 'Protocol activity',
              subtitle: 'Created and completed runs',
              child: _buildActivityChart(created, completed),
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
              child: _buildProtocolStatus(data, completed.length),
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
          _DashboardPanel(
            title: 'Data health',
            subtitle: 'Google Drive synchronization and attention items',
            child: _buildDataHealth(data),
          ),
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
    return SegmentedButton<DashboardRange>(
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
  }

  Widget _buildKpis(
    DashboardData data,
    List<Protocol> created,
    List<CompletedProtocol> completed,
    int completedTaskCount,
    List<Duration> durations,
  ) {
    final average = durations.isEmpty
        ? null
        : Duration(
            milliseconds:
                durations.fold<int>(
                  0,
                  (sum, item) => sum + item.inMilliseconds,
                ) ~/
                durations.length,
          );
    final items = [
      _KpiData(
        'Active runs',
        '${data.runningProtocols.length}',
        Icons.play_circle_outline,
        AppColors.info,
      ),
      _KpiData(
        'Completed',
        '${completed.length}',
        Icons.check_circle_outline,
        AppColors.success,
      ),
      _KpiData(
        'Protocols created',
        '${created.where((item) => !item.isTemplate).length}',
        Icons.article_outlined,
        AppColors.primary,
      ),
      _KpiData(
        'Saved tables',
        '${data.savedTables.length}',
        Icons.table_chart_outlined,
        const Color(0xFF7B61A8),
      ),
      _KpiData(
        'Tasks completed',
        '$completedTaskCount',
        Icons.task_alt,
        const Color(0xFFCE7A24),
      ),
      _KpiData(
        'Average duration',
        average == null ? 'No timing data' : _formatDuration(average),
        Icons.timer_outlined,
        const Color(0xFFB14C68),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 6
            : constraints.maxWidth >= 650
            ? 3
            : 2;
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((item) => SizedBox(width: width, child: _KpiTile(item)))
              .toList(),
        );
      },
    );
  }

  Widget _responsivePanels(List<Widget> panels, {double minPanelWidth = 380}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          math.min(
            panels.length,
            (constraints.maxWidth / minPanelWidth).floor(),
          ),
        );
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: panels
              .map((panel) => SizedBox(width: width, child: panel))
              .toList(),
        );
      },
    );
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
          height: 190,
          child: BarChart(
            BarChartData(
              maxY: maxValue.toDouble() + 1,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context).dividerColor,
                  strokeWidth: 1,
                ),
              ),
              barGroups: points.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barsSpace: 3,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.created.toDouble(),
                      color: AppColors.primary,
                      width: 10,
                      borderRadius: BorderRadius.zero,
                    ),
                    BarChartRodData(
                      toY: entry.value.completed.toDouble(),
                      color: AppColors.success,
                      width: 10,
                      borderRadius: BorderRadius.zero,
                    ),
                  ],
                );
              }).toList(),
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
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 190,
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
          ),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: _Legend(
            vertical: true,
            items: [
              _LegendData('Not started', AppColors.textSecondary),
              _LegendData('In progress', AppColors.info),
              _LegendData('Completed', AppColors.success),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolStatus(DashboardData data, int completedCount) {
    final values = [
      data.protocols.where((item) => item.isTemplate).length,
      data.protocols.where((item) => !item.isTemplate).length,
      data.runningProtocols.length,
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
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 190,
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
          ),
        ),
        const Flexible(
          child: _Legend(
            vertical: true,
            items: [
              _LegendData('Templates', Color(0xFF7B61A8)),
              _LegendData('Ready', AppColors.primary),
              _LegendData('Running', AppColors.info),
              _LegendData('Completed', AppColors.success),
            ],
          ),
        ),
      ],
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
          icon: Icons.table_chart_outlined,
          label: 'Tables',
          health: tableHealth,
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

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${math.max(1, duration.inMinutes)}m';
  }

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
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

class _KpiTile extends StatelessWidget {
  final _KpiData data;
  const _KpiTile(this.data);
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.color, size: 22),
          const SizedBox(height: 10),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyChart extends StatelessWidget {
  final String text;
  const _EmptyChart(this.text);
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
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

class _HealthColumnLabel extends StatelessWidget {
  final String label;
  const _HealthColumnLabel(this.label);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
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
    width: 52,
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
