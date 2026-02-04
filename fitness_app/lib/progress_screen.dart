import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_log.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _apiService = DatabaseService();
  String? _selectedMenu;
  List<WorkoutLog> _workoutLogs = [];
  List<String> _availableMenus = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Map<DateTime, double> _dailyWeights = {};
  int? _touchedIndex;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _fetchWorkoutLogs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchWorkoutLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final logs = await _apiService.getLogs();
      final uniqueMenus = logs.map((log) => log.menuTitle).toSet().toList();
      uniqueMenus.sort();

      setState(() {
        _workoutLogs = logs;
        _availableMenus = uniqueMenus;
        _selectedMenu = uniqueMenus.isNotEmpty ? uniqueMenus.first : null;
        _isLoading = false;
      });
      _animationController.forward(from: 0);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load workout logs: $e';
        _isLoading = false;
      });
    }
  }

  void _onMenuSelected(String menu) {
    if (_selectedMenu != menu) {
      setState(() {
        _selectedMenu = menu;
        _touchedIndex = null;
      });
      _animationController.forward(from: 0);
    }
  }

  List<FlSpot> _generateChartData() {
    if (_selectedMenu == null || _workoutLogs.isEmpty) {
      return [];
    }

    final filteredLogs = _workoutLogs
        .where((log) => log.menuTitle == _selectedMenu)
        .sorted((a, b) => a.completedDate.compareTo(b.completedDate))
        .toList();

    _dailyWeights.clear();
    for (var log in filteredLogs) {
      if (log.workoutDetails != null && log.workoutDetails!.contains('@')) {
        final weightString =
            log.workoutDetails!.split('@')[1].trim().split('kg')[0].trim();
        final weight = double.tryParse(weightString);
        if (weight != null) {
          final date = DateUtils.dateOnly(log.completedDate);
          _dailyWeights[date] = weight;
        }
      }
    }

    final List<FlSpot> spots = [];
    int index = 0;
    _dailyWeights.keys.sorted((a, b) => a.compareTo(b)).forEach((date) {
      spots.add(FlSpot(index.toDouble(), _dailyWeights[date]!));
      index++;
    });

    return spots;
  }

  List<DateTime> _getSortedDates() {
    return _dailyWeights.keys.sorted((a, b) => a.compareTo(b)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchWorkoutLogs,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    if (_workoutLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center,
                size: 64, color: colorScheme.outline.withAlpha((255 * 0.5).round())),
            const SizedBox(height: 16),
            Text(
              'トレーニング履歴がありません',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Text(
              'ワークアウトを完了すると\nここに進捗が表示されます',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.outline.withAlpha((255 * 0.7).round())),
            ),
          ],
        ),
      );
    }

    final spots = _generateChartData();
    final sortedDates = _getSortedDates();

    return Column(
      children: [
        // Header with title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.trending_up, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '重量推移',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Menu selection chips
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _availableMenus.length,
            itemBuilder: (context, index) {
              final menu = _availableMenus[index];
              final isSelected = menu == _selectedMenu;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(menu),
                  selected: isSelected,
                  onSelected: (_) => _onMenuSelected(menu),
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.onPrimaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  elevation: isSelected ? 2 : 0,
                  pressElevation: 4,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Selected point info card
        if (_touchedIndex != null && _touchedIndex! < sortedDates.length)
          _buildSelectedPointCard(sortedDates, spots, colorScheme, theme),

        // Chart
        Expanded(
          child: spots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart,
                          size: 48, color: colorScheme.outline.withAlpha((255 * 0.5).round())),
                      const SizedBox(height: 12),
                      Text(
                        'このメニューの重量データがありません',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 20, 16),
                      child: InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        minScale: 0.5,
                        maxScale: 3.0,
                        child: _buildChart(spots, sortedDates, colorScheme),
                      ),
                    );
                  },
                ),
        ),

        // Statistics summary
        if (spots.isNotEmpty) _buildStatisticsSummary(spots, colorScheme, theme),
      ],
    );
  }

  Widget _buildSelectedPointCard(List<DateTime> sortedDates, List<FlSpot> spots,
      ColorScheme colorScheme, ThemeData theme) {
    final date = sortedDates[_touchedIndex!];
    final weight = spots[_touchedIndex!].y;

    // Calculate change from previous point
    String changeText = '';
    Color changeColor = colorScheme.onSurface;
    IconData changeIcon = Icons.remove;

    if (_touchedIndex! > 0) {
      final prevWeight = spots[_touchedIndex! - 1].y;
      final change = weight - prevWeight;
      if (change > 0) {
        changeText = '+${change.toStringAsFixed(1)}kg';
        changeColor = Colors.green;
        changeIcon = Icons.arrow_upward;
      } else if (change < 0) {
        changeText = '${change.toStringAsFixed(1)}kg';
        changeColor = Colors.red;
        changeIcon = Icons.arrow_downward;
      } else {
        changeText = '±0kg';
        changeIcon = Icons.remove;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha((255 * 0.3).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withAlpha((255 * 0.3).round())),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                DateFormat('yyyy/MM/dd').format(date),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${weight.toStringAsFixed(1)}kg',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          if (changeText.isNotEmpty)
            Row(
              children: [
                Icon(changeIcon, color: changeColor, size: 20),
                const SizedBox(width: 4),
                Text(
                  changeText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChart(
      List<FlSpot> spots, List<DateTime> sortedDates, ColorScheme colorScheme) {
    final minY = (spots.map((s) => s.y).minOrNull ?? 0) - 5;
    final maxY = (spots.map((s) => s.y).maxOrNull ?? 0) + 5;

    // Animate the spots
    final animatedSpots = spots.map((spot) {
      return FlSpot(spot.x, spot.y * _animation.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outline.withAlpha((255 * 0.2).round()),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: spots.length > 10 ? (spots.length / 5).ceil().toDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedDates.length) {
                  return SideTitleWidget(
                    meta: meta,
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: Text(
                        DateFormat('M/d').format(sortedDates[index]),
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                        ),
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}kg',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: animatedSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            barWidth: 3,
            color: colorScheme.primary,
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
              ],
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withAlpha((255 * 0.3).round()),
                  colorScheme.primary.withAlpha((255 * 0.05).round()),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isTouched = index == _touchedIndex;
                return FlDotCirclePainter(
                  radius: isTouched ? 8 : 4,
                  color: isTouched ? colorScheme.tertiary : colorScheme.primary,
                  strokeWidth: isTouched ? 3 : 2,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
          ),
        ],
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY * _animation.value,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (event is FlTapUpEvent || event is FlLongPressEnd) {
              if (response != null && response.lineBarSpots != null) {
                if (response.lineBarSpots!.isNotEmpty) {
                  setState(() {
                    _touchedIndex = response.lineBarSpots!.first.spotIndex;
                  });
                }
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (touchedSpot) =>
                colorScheme.inverseSurface.withValues(alpha: 0.9),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final index = touchedSpot.spotIndex;
                if (index >= 0 && index < sortedDates.length) {
                  final date = sortedDates[index];
                  return LineTooltipItem(
                    '${DateFormat('MM/dd').format(date)}\n${touchedSpot.y.toStringAsFixed(1)}kg',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: colorScheme.primary.withAlpha((255 * 0.5).round()),
                  strokeWidth: 2,
                  dashArray: [5, 5],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 8,
                      color: colorScheme.tertiary,
                      strokeWidth: 3,
                      strokeColor: colorScheme.surface,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildStatisticsSummary(
      List<FlSpot> spots, ColorScheme colorScheme, ThemeData theme) {
    final weights = spots.map((s) => s.y).toList();
    final minWeight = weights.min;
    final maxWeight = weights.max;
    final avgWeight = weights.reduce((a, b) => a + b) / weights.length;
    final firstWeight = weights.first;
    final lastWeight = weights.last;
    final totalChange = lastWeight - firstWeight;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '統計サマリー',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('最小', '${minWeight.toStringAsFixed(1)}kg',
                  Icons.arrow_downward, Colors.blue, theme),
              _buildStatItem('最大', '${maxWeight.toStringAsFixed(1)}kg',
                  Icons.arrow_upward, Colors.orange, theme),
              _buildStatItem('平均', '${avgWeight.toStringAsFixed(1)}kg',
                  Icons.analytics, colorScheme.primary, theme),
              _buildStatItem(
                '変化',
                '${totalChange >= 0 ? '+' : ''}${totalChange.toStringAsFixed(1)}kg',
                totalChange >= 0 ? Icons.trending_up : Icons.trending_down,
                totalChange >= 0 ? Colors.green : Colors.red,
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color,
      ThemeData theme) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha((255 * 0.6).round()),
          ),
        ),
      ],
    );
  }
}
