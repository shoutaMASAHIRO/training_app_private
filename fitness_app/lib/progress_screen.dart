import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_log.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final DatabaseService _apiService = DatabaseService();
  String? _selectedExercise;
  List<WorkoutLog> _workoutLogs = [];
  List<String> _availableExercises = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Map<DateTime, double> _dailyWeights = {};
  int? _touchedIndex;

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _hoveredDay;
  bool _isHeaderHovered = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchWorkoutLogs();
  }

  @override
  void dispose() {
    super.dispose();
  }

    Future<void> _fetchWorkoutLogs() async {

      setState(() {

        _isLoading = true;

        _errorMessage = '';

      });

      try {

        final logs = await _apiService.getLogs();

        

        // 実績登録画面から登録した「最重量の記録 (Max record)」のみを抽出

        // これにより、通常のワークアウト完了記録はProgressページには一切表示されなくなります

        final prLogs = logs.where((log) {

          final details = log.workoutDetails ?? '';

          return details.contains('Max record');

        }).toList();

  

        final uniqueExercises = prLogs.map((log) => log.sessionTitle ?? log.menuTitle).toSet().toList();

        uniqueExercises.sort();

  

        setState(() {

          _workoutLogs = prLogs;

          _availableExercises = uniqueExercises;

          // Keep selected exercise if it's still available

          if (_selectedExercise == null || !uniqueExercises.contains(_selectedExercise)) {

            _selectedExercise = uniqueExercises.isNotEmpty ? uniqueExercises.first : null;

          }

          _isLoading = false;

        });

      } catch (e) {

  
            setState(() {
              _errorMessage = 'Failed to load workout logs: $e';
              _isLoading = false;
            });
          }
        }
      
        void _onExerciseSelected(String exercise) {
          if (_selectedExercise != exercise) {
            setState(() {
              _selectedExercise = exercise;
              _touchedIndex = null;
            });
          }
        }
        Color _getExerciseColor(String? exercise, ColorScheme colorScheme) {
    return colorScheme.primary;
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _workoutLogs
        .where((log) => isSameDay(log.completedDate, day))
        .toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (isSameDay(_selectedDay, selectedDay)) {
      // Already selected, navigate to add manual log screen
      Navigator.pushNamed(
        context,
        '/add_manual_log',
        arguments: {'selectedDate': selectedDay},
      ).then((result) {
        if (result == true) {
          _fetchWorkoutLogs();
        }
      });
    } else {
      // New date selected, just update state to show logs
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  List<FlSpot> _generateChartData() {
    if (_selectedExercise == null || _workoutLogs.isEmpty) {
      return [];
    }

    final filteredLogs = _workoutLogs
        .where((log) => (log.sessionTitle ?? log.menuTitle) == _selectedExercise)
        .sorted((a, b) => a.completedDate.compareTo(b.completedDate))
        .toList();

    _dailyWeights.clear();
    for (var log in filteredLogs) {
      if (log.workoutDetails != null && log.workoutDetails!.contains('@')) {
        // Try to find weight in format "@ XX.Xkg"
        final regex = RegExp(r'@\s*(\d+(\.\d+)?)kg');
        final match = regex.firstMatch(log.workoutDetails!);
        if (match != null) {
          final weightString = match.group(1);
          final weight = double.tryParse(weightString!);
          if (weight != null) {
            final date = DateUtils.dateOnly(log.completedDate);
            // Keep the maximum weight for that day if there are multiple logs
            if (!_dailyWeights.containsKey(date) || weight > _dailyWeights[date]!) {
              _dailyWeights[date] = weight;
            }
          }
        }
      }
    }

    final List<FlSpot> spots = [];
    final sortedDates = _dailyWeights.keys.toList()..sort();
    
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), _dailyWeights[sortedDates[i]]!));
    }

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

    final spots = _generateChartData();
    final sortedDates = _getSortedDates();

    return RefreshIndicator(
      onRefresh: _fetchWorkoutLogs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 24.0), // Added vertical padding
        child: Column(
          children: [
            // Header with title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), // Increased padding
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '進捗登録',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Calendar Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // Increased horizontal margin
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: _onDaySelected,
                  eventLoader: _getEventsForDay,
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                        ),
                      );
                    },
                    headerTitleBuilder: (context, date) {
                      return Center(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isHeaderHovered = true),
                          onExit: (_) => setState(() => _isHeaderHovered = false),
                          child: GestureDetector(
                            onTap: () {
                              showDatePicker(
                                context: context,
                                initialDate: _focusedDay,
                                firstDate: DateTime.utc(2020, 1, 1),
                                lastDate: DateTime.utc(2030, 12, 31),
                              ).then((pickedDate) {
                                if (pickedDate != null) {
                                  setState(() {
                                    _focusedDay = pickedDate;
                                    _selectedDay = pickedDate;
                                  });
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                DateFormat('yyyy年M月').format(date),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _isHeaderHovered
                                      ? colorScheme.primary.withAlpha(150)
                                      : colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    prioritizedBuilder: (context, day, focusedDay) {
                      final isHovered = isSameDay(_hoveredDay, day);
                      final isSelected = isSameDay(_selectedDay, day);
                      final isToday = isSameDay(day, DateTime.now());

                      BoxDecoration decoration;
                      if (isSelected) {
                        decoration = BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8.0),
                        );
                      } else if (isToday) {
                        decoration = BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.0),
                        );
                      } else if (isHovered) {
                        decoration = BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8.0),
                        );
                      } else {
                        decoration = const BoxDecoration(shape: BoxShape.rectangle);
                      }

                      return MouseRegion(
                        onEnter: (_) => setState(() => _hoveredDay = day),
                        onExit: (_) => setState(() => _hoveredDay = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.all(4.0),
                          decoration: decoration,
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            if (_selectedDay != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('M月d日の記録').format(_selectedDay!),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/add_manual_log',
                              arguments: {'selectedDate': _selectedDay},
                            ).then((result) {
                              if (result == true) {
                                _fetchWorkoutLogs();
                              }
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('記録を追加'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._getEventsForDay(_selectedDay!)
                        .map((event) => _buildDayLogCard(event as WorkoutLog, theme))
                        .toList(),
                    if (_getEventsForDay(_selectedDay!).isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'この日の記録はありません',
                          style: TextStyle(color: colorScheme.outline, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const Divider(height: 64, indent: 24, endIndent: 24, thickness: 0.5), // More space around divider

            // Header with title for chart
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.show_chart, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '種目別重量推移',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            if (_availableExercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 32.0),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center,
                        size: 48, color: colorScheme.outline.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      '重量推移データがありません',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: colorScheme.outline),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '「記録を追加」から実績を登録すると\nここに進捗グラフが表示されます',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              )
            else ...[
              // Exercise selection dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<String>(
                  value: _selectedExercise,
                  decoration: InputDecoration(
                    labelText: '種目を選択',
                    labelStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none, // Remove border
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100, // Subtle background
                  ),
                  items: _availableExercises.map((exercise) {
                    return DropdownMenuItem<String>(
                      value: exercise,
                      child: Text(
                        exercise,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) _onExerciseSelected(value);
                  },
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 8),

              // Selected point info card
              if (_touchedIndex != null && _touchedIndex! < sortedDates.length)
                _buildSelectedPointCard(sortedDates, spots, colorScheme, theme),

              // Chart
              Container(
                height: 300,
                padding: const EdgeInsets.fromLTRB(8, 16, 32, 16), // Increased right padding
                child: spots.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.show_chart,
                                size: 48, color: colorScheme.outline.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'このメニューの重量データがありません',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        minScale: 0.5,
                        maxScale: 3.0,
                        child: _buildChart(spots, sortedDates, colorScheme),
                      ),
              ),

              // Statistics summary
              if (spots.isNotEmpty) _buildStatisticsSummary(spots, colorScheme, theme),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDayLogCard(WorkoutLog log, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          log.menuTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(log.workoutDetails ?? ''),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
          onPressed: () => _confirmDeleteLog(log),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLog(WorkoutLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('記録の削除'),
        content: Text('${log.menuTitle} (${log.workoutDetails}) の記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('キャンセル', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && log.id != null) {
      await _deleteLog(log.id!);
    }
  }

  Future<void> _deleteLog(int id) async {
    try {
      await _apiService.deleteLog(id);
      await _fetchWorkoutLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('記録を削除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSimpleStat(IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text('$count'),
        ],
      ),
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        // Removed Border.all
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                DateFormat('yyyy/MM/dd').format(date),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
    if (spots.isEmpty) return const SizedBox.shrink();

    final firstWeight = spots.first.y;
    final minWeight = spots.map((s) => s.y).minOrNull ?? firstWeight;
    final maxWeight = spots.map((s) => s.y).maxOrNull ?? firstWeight;

    // Use the first weight as a baseline reference
    // We round down to the nearest 10kg below the start point or min weight
    double minY = (min(minWeight, firstWeight) - 10);
    minY = (minY / 10).floor() * 10.0;
    if (minY < 0) minY = 0;

    // Ensure at least a 20kg visible range for better perspective
    double maxY = max(maxWeight + 10, minY + 20);
    maxY = (maxY / 10).ceil() * 10.0;

    final exerciseColor = _getExerciseColor(_selectedExercise, colorScheme);

    // Animate the spots
    final animatedSpots = spots.map((spot) {
      return FlSpot(spot.x, spot.y);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: 1, // Draw a line for every data point
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 0.5,
              dashArray: [5, 5],
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.1),
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: spots.length > 10 ? (spots.length / 5).ceil().toDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedDates.length) {
                  return SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData(
                      enabled: true,
                      axisPosition: meta.axisPosition,
                      parentAxisSize: meta.parentAxisSize,
                      distanceFromEdge: 0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('M/d').format(sortedDates[index]),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
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
                if (value == minY || value == maxY) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    '${value.toInt()}kg',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        clipData: const FlClipData.none(), // Allow labels/dots to draw outside the chart area
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
            left: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
            right: const BorderSide(color: Colors.transparent),
            top: const BorderSide(color: Colors.transparent),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: animatedSpots,
            isCurved: false, // Linear line chart
            barWidth: 3,
            color: exerciseColor,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(show: false), // Removed shaded area
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isTouched = index == _touchedIndex;
                return FlDotCirclePainter(
                  radius: isTouched ? 6 : 4,
                  color: isTouched ? colorScheme.tertiary : exerciseColor,
                  strokeWidth: isTouched ? 3 : 2,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
          ),
        ],
        minX: 0,
        maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1.0,
        minY: minY,
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
            getTooltipColor: (touchedSpot) => colorScheme.surfaceContainerHighest,
            tooltipBorder: BorderSide(color: colorScheme.outlineVariant),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final index = touchedSpot.spotIndex;
                if (index >= 0 && index < sortedDates.length) {
                  final date = sortedDates[index];
                  return LineTooltipItem(
                    '${DateFormat('MM/dd').format(date)}\n',
                    TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                    ),
                    children: [
                      TextSpan(
                        text: '${touchedSpot.y.toStringAsFixed(1)}kg',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
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
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  strokeWidth: 2,
                  dashArray: [5, 5],
                ),
                FlDotData(show: false), // Dots are handled in lineBarsData
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
