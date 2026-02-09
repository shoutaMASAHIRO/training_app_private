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

  // 候補となる種目リスト（カテゴリ別）
  static const Map<String, List<String>> _categorizedExercises = {
    '脚（前）': [
      'バックスクワット',
      'フロントスクワット',
      'ボックススクワット',
      'スミススクワット',
      'ゴブレッドスクワット',
      'ブルガリアンスクワット',
      'ハックスクワット',
      'レッグプレス',
      'レッグエクステンション',
    ],
    '脚（後）': [
      'コンベンショナルデッドリフト',
      'スモウデッドリフト',
      'ルーマニアンデッドリフト',
      'スティフレッグデッドリフト',
      'グッドモーニング',
      'ヒップスラスト',
      'レッグカール',
    ],
    'ふくらはぎ': [
      'カーフレイズ',
      'シーテッドカーフレイズ',
      'ドンキーカーフレイズ',
    ],
    '胸': [
      'バーベルベンチプレス',
      'ナローバーベルベンチプレス',
      'インクラインベンチプレス',
      'ダンベルプレス',
      'インクラインダンベルプレス',
      'ディップス',
      'ペックフライ',
      'インクラインダンベルフライ',
      'ケーブルフライ',
      'ダンベルプルオーバー',
    ],
    '背中': [
      'ラットプルダウン',
      'プルアップ',
      'インバーテッドロー',
      'Tバーロー',
      'ワンハンドロー',
    ],
    '肩': [
      'バーベルショルダープレス',
      'ダンベルショルダープレス',
      'サイドレイズ',
      'フロントレイズ',
    ],
    '二頭筋': [
      'バーベルカール',
      'ダンベルカール',
      'プリーチャーカール',
      'ケーブルカール',
    ],
    '三頭筋': [
      'JMプレス',
      'バーベルエクステンション',
      'ケーブルエクステンション',
      'ケーブルプレスダウン',
      'キックバック',
    ],
    '前腕': [
      'バーベルリストカール',
      'ダンベルリストカール',
      'ケーブルリストカール',
      '握力',
    ],
  };

  Future<void> _showExerciseSelectionModal(BuildContext context, Function(String) onSelect) async {
    FocusScope.of(context).unfocus();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          '種目を選択',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.grey[800]
                          ),
                        ),
                      ),
                                        Expanded(
                                          child: ListView(
                                            controller: scrollController,
                                            padding: const EdgeInsets.only(bottom: 30),
                                                                      children: _categorizedExercises.entries.map((entry) {
                                                                        final category = entry.key;
                                                                        final exercises = entry.value;
                                                                        
                                                                        // このカテゴリ内でデータがある種目数をカウント
                                                                        final availableCount = exercises.where((ex) => _availableExercises.contains(ex)).length;
                                            
                                                                        return Theme(
                                                                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                                          child: ExpansionTile(
                                                                            maintainState: false, // 軽量化
                                                                            title: Row(
                                                                              children: [
                                                                                Expanded(
                                                                                  child: Text(
                                                                                    category,
                                                                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF424242)),
                                                                                  ),
                                                                                ),
                                                                                // データがある種目数 (赤)
                                                                                if (availableCount > 0) ...[
                                                                                  Container(
                                                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                                    decoration: BoxDecoration(
                                                                                      color: Colors.red.shade50,
                                                                                      borderRadius: BorderRadius.circular(10),
                                                                                    ),
                                                                                    child: Text(
                                                                                      '$availableCount',
                                                                                      style: const TextStyle(
                                                                                        color: Colors.red,
                                                                                        fontSize: 11,
                                                                                        fontWeight: FontWeight.w900,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  const SizedBox(width: 6),
                                                                                ],
                                                                                // 合計種目数 (シアン)
                                                                                Container(
                                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                                  decoration: BoxDecoration(
                                                                                    color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                                                                                    borderRadius: BorderRadius.circular(10),
                                                                                  ),
                                                                                  child: Text(
                                                                                    '${exercises.length}',
                                                                                    style: const TextStyle(
                                                                                      color: Color(0xFF00ACC1),
                                                                                      fontSize: 11,
                                                                                      fontWeight: FontWeight.w900,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            collapsedIconColor: const Color(0xFF00ACC1),
                                                                            iconColor: const Color(0xFF00ACC1),
                                                                            children: exercises.map((exercise) {
                                                                              final hasData = _availableExercises.contains(exercise);
                                                                              return Container(
                                                                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                                                                decoration: BoxDecoration(
                                                                                  color: hasData ? Colors.red.withValues(alpha: 0.05) : Colors.transparent,
                                                                                  borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                child: ListTile(
                                                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                                                                  leading: Container(
                                                                                    padding: const EdgeInsets.all(8),
                                                                                    decoration: BoxDecoration(
                                                                                      color: hasData ? Colors.red.withValues(alpha: 0.1) : Colors.grey[50],
                                                                                      borderRadius: BorderRadius.circular(8),
                                                                                    ),
                                                                                    child: Image.asset(
                                                                                      'image/icons/$exercise.png',
                                                                                      width: 96,
                                                                                      height: 96,
                                                                                      fit: BoxFit.contain,
                                                                                      cacheWidth: 150, // 192 -> 150
                                                                                      errorBuilder: (context, error, stackTrace) => Icon(
                                                                                        Icons.fitness_center, 
                                                                                        size: 48,
                                                                                        color: hasData ? Colors.red.shade300 : Colors.grey.shade400
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                        title: Text(
                                                          exercise,
                                                          style: TextStyle(
                                                            fontWeight: hasData ? FontWeight.w900 : FontWeight.bold, 
                                                            fontSize: 15, 
                                                            color: hasData ? Colors.red.shade900 : const Color(0xFF424242)
                                                          ),
                                                        ),
                                                        trailing: hasData ? Icon(Icons.star_rounded, color: Colors.red.shade300, size: 18) : null,
                                                        onTap: () {
                                                          onSelect(exercise);
                                                          Navigator.pop(context);
                                                        },
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchWorkoutLogs();
  }

  Future<void> _fetchWorkoutLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      final logs = await _apiService.getLogs();

      final prLogs = logs.where((log) {
        final details = log.workoutDetails ?? '';
        return details.contains('Max record');
      }).toList();

      final uniqueExercises = prLogs.map((log) => log.sessionTitle ?? log.menuTitle).toSet().toList();
      uniqueExercises.sort();

      setState(() {
        _workoutLogs = prLogs;
        _availableExercises = uniqueExercises;
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

  List<dynamic> _getEventsForDay(DateTime day) {
    return _workoutLogs.where((log) => isSameDay(log.completedDate, day)).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (isSameDay(_selectedDay, selectedDay)) {
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
        final regex = RegExp(r'@\s*(\d+(\.\d+)?)kg');
        final match = regex.firstMatch(log.workoutDetails!);
        if (match != null) {
          final weightString = match.group(1);
          final weight = double.tryParse(weightString!);
          if (weight != null) {
            final date = DateUtils.dateOnly(log.completedDate);
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
            Text(_errorMessage, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
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
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Calendar Header Section
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
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
                  titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                  weekendStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  weekendTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  outsideTextStyle: const TextStyle(color: Colors.white30, fontWeight: FontWeight.bold),
                  todayDecoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                                                                        todayTextStyle: const TextStyle(
                                                                          color: Colors.deepOrangeAccent,
                                                                          fontWeight: FontWeight.w900,
                                                                        ),
                                                                        selectedDecoration: BoxDecoration(
                                                                          color: Colors.white.withValues(alpha: 0.2),
                                                                          borderRadius: BorderRadius.circular(10),
                                                                        ),
                                                                        selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                                                        markerDecoration: const BoxDecoration(
                                                                          color: Colors.white,
                                                                          shape: BoxShape.circle,
                                                                        ),
                                                                      ),
                                                                      calendarBuilders: CalendarBuilders(
                                                                        selectedBuilder: (context, day, focusedDay) {
                                                                          final isToday = isSameDay(day, DateTime.now());
                                                                          return Container(
                                                                            margin: const EdgeInsets.all(4),
                                                                            decoration: BoxDecoration(
                                                                              color: Colors.white.withValues(alpha: 0.2),
                                                                              borderRadius: BorderRadius.circular(10),
                                                                            ),
                                                                            child: Center(
                                                                              child: Text(
                                                                                '${day.day}',
                                                                                style: TextStyle(
                                                                                  color: isToday ? Colors.deepOrangeAccent : Colors.white,
                                                                                  fontWeight: FontWeight.w900,
                                                                                  fontSize: 14,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                        markerBuilder: (context, day, events) {
                                                                          if (events.isEmpty) return const SizedBox.shrink();
                                                                          
                                                                          // 最大4つまでの星を表示
                                                                          const maxStars = 4;
                                                                          final starCount = min(events.length, maxStars);
                                                                          final hasMore = events.length > maxStars;

                                                                          return Positioned(
                                                                            bottom: 4,
                                                                            child: Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                ...List.generate(
                                                                                  starCount,
                                                                                  (index) => const Padding(
                                                                                    padding: EdgeInsets.symmetric(horizontal: 0.5),
                                                                                    child: Icon(
                                                                                      Icons.stars_rounded,
                                                                                      color: Colors.white,
                                                                                      size: 13,
                                                                                      shadows: [
                                                                                        Shadow(
                                                                                          blurRadius: 4.0,
                                                                                          color: Colors.black26,
                                                                                          offset: Offset(0, 1),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                if (hasMore)
                                                                                  const Text(
                                                                                    '+',
                                                                                    style: TextStyle(
                                                                                      color: Colors.white,
                                                                                      fontSize: 10,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      shadows: [
                                                                                        Shadow(
                                                                                          blurRadius: 4.0,
                                                                                          color: Colors.black26,
                                                                                          offset: Offset(0, 1),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                              ],
                                                                            ),
                                                                          );
                                                                        },
                                                                        headerTitleBuilder: (context, date) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          DateFormat('MMMM yyyy').format(date).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Row(
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
                  const SizedBox(height: 12),
                  
                  if (_selectedDay != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                          const SizedBox(height: 12),
                          ..._getEventsForDay(_selectedDay!).map((event) => _buildDayLogCard(event as WorkoutLog, theme)).toList(),
                          if (_getEventsForDay(_selectedDay!).isEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF00ACC1).withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.history_rounded, color: Colors.grey.shade300, size: 40),
                                    const SizedBox(height: 12),
                                    Text(
                                      'この日の記録はありません',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32), // Dividerを削除し、セクション間の余白を確保
                  
                  Row(
                    children: [
                      Icon(Icons.show_chart, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        '種目別重量推移',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF424242),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12), // Dividerの代わりにある程度の余白を確保
                  
                  if (_availableExercises.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 32.0),
                      child: Column(
                        children: [
                          Icon(Icons.fitness_center, size: 48, color: colorScheme.outline.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            '重量推移データがありません',
                            style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.outline),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '「記録を追加」から実績を登録すると\nここに進捗グラフが表示されます',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            _showExerciseSelectionModal(context, (selected) {
                              _onExerciseSelected(selected);
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              hintText: '種目を選択してください',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 2),
                              ),
                            ),
                            child: _selectedExercise != null 
                              ? Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.1), width: 2),
                                          ),
                                          child: Image.asset(
                                            'image/icons/$_selectedExercise.png',
                                            width: 144,
                                            height: 144,
                                            fit: BoxFit.contain,
                                            cacheWidth: 288,
                                            errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 72, color: Colors.grey.shade400),
                                          ),
                                        ),
                                        // タッチできることを示すオーバーレイアイコン
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF00ACC1),
                                            shape: BoxShape.circle,
                                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                          ),
                                          child: const Icon(Icons.sync_rounded, color: Colors.white, size: 24),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _selectedExercise!,
                                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF212121), fontSize: 18),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.touch_app_rounded, color: Color(0xFF00ACC1), size: 18),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'タップして種目を変更',
                                      style: TextStyle(color: Color(0xFF00ACC1), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                )
                              : const Text('種目を選択してください'),
                          ),
                        ),
                      ),
                    ), // ここでPaddingを閉じ、コンマを追加
                    const SizedBox(height: 8),
                    if (_touchedIndex != null && _touchedIndex! < sortedDates.length)
                      _buildSelectedPointCard(sortedDates, spots, colorScheme, theme),
                    // Chart
                    Container(
                      height: 300,
                      padding: const EdgeInsets.fromLTRB(8, 16, 32, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF00ACC1).withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
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
                    if (spots.isNotEmpty) _buildStatisticsSummary(spots, colorScheme, theme),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDayLogCard(WorkoutLog log, ThemeData theme) {
    // パースして重量部分を強調表示
    String weightDisplay = '---';
    String repsDisplay = '';
    
    final details = log.workoutDetails ?? '';
    if (details.contains('@')) {
      final afterAt = details.split('@')[1].trim();
      if (afterAt.contains(' x ')) {
        final parts = afterAt.split(' x ');
        weightDisplay = parts[0]; 
        repsDisplay = parts[1];   
      } else {
        weightDisplay = afterAt;  
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                color: const Color(0xFF00ACC1),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, size: 16, color: Color(0xFF00ACC1)),
                          const SizedBox(width: 6),
                          const Text(
                            'PERSONAL RECORD',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00ACC1),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        log.menuTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade100, width: 1),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      weightDisplay.replaceAll('kg', ''),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: Color(0xFF424242),
                      ),
                    ),
                    const Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    if (repsDisplay.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        repsDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00ACC1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Material(
                color: Colors.red.shade50,
                child: InkWell(
                  onTap: () => _confirmDeleteLog(log),
                  child: Container(
                    width: 56,
                    alignment: Alignment.center,
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                  ),
                ),
              ),
            ],
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録を削除しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildSelectedPointCard(List<DateTime> sortedDates, List<FlSpot> spots, ColorScheme colorScheme, ThemeData theme) {
    final date = sortedDates[_touchedIndex!];
    final weight = spots[_touchedIndex!].y;
    String changeText = '';
    Color changeColor = colorScheme.onSurface;
    IconData changeIcon = Icons.remove;
    if (_touchedIndex! > 0) {
      final prevWeight = spots[_touchedIndex! - 1].y;
      final change = weight - prevWeight;
      if (change > 0) {
        changeText = '+${change.toStringAsFixed(1)}kg';
        changeColor = const Color(0xFF00ACC1);
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
        color: colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(DateFormat('yyyy/MM/dd').format(date), style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('${weight.toStringAsFixed(1)}kg', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            ],
          ),
          if (changeText.isNotEmpty)
            Row(
              children: [
                Icon(changeIcon, color: changeColor, size: 20),
                const SizedBox(width: 4),
                Text(changeText, style: theme.textTheme.titleMedium?.copyWith(color: changeColor, fontWeight: FontWeight.bold)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChart(List<FlSpot> spots, List<DateTime> sortedDates, ColorScheme colorScheme) {
    if (spots.isEmpty) return const SizedBox.shrink();
    final firstWeight = spots.first.y;
    final minWeight = spots.map((s) => s.y).minOrNull ?? firstWeight;
    final maxWeight = spots.map((s) => s.y).maxOrNull ?? firstWeight;
    double minY = (min(minWeight, firstWeight) - 10);
    minY = (minY / 10).floor() * 10.0;
    if (minY < 0) minY = 0;
    double maxY = max(maxWeight + 10, minY + 20);
    maxY = (maxY / 10).ceil() * 10.0;
    final animatedSpots = spots.map((spot) => FlSpot(spot.x, spot.y)).toList();
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.1),
              strokeWidth: 0.5,
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
                    child: Text(
                      DateFormat('M/d').format(sortedDates[index]),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
              reservedSize: 40,
              interval: 5,
              getTitlesWidget: (value, meta) {
                if (meta.appliedInterval != null && (value == minY || value == maxY)) return const SizedBox.shrink();
                return Text(
                  '${value.toInt()}kg',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        clipData: const FlClipData.none(),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: animatedSpots,
            isCurved: false,
            barWidth: 3,
            color: const Color(0xFF00ACC1),
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00ACC1).withValues(alpha: 0.2),
                  const Color(0xFF00ACC1).withValues(alpha: 0.0),
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
                  radius: isTouched ? 6 : 4,
                  color: isTouched ? const Color(0xFFFFB74D) : const Color(0xFF00ACC1),
                  strokeWidth: 3,
                  strokeColor: Colors.white,
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
            getTooltipColor: (touchedSpot) => const Color(0xFF00ACC1),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  '${touchedSpot.y.toStringAsFixed(1)}kg',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(color: Colors.black12, strokeWidth: 1),
                FlDotData(show: false),
              );
            }).toList();
          },
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildStatisticsSummary(List<FlSpot> spots, ColorScheme colorScheme, ThemeData theme) {
    final weights = spots.map((s) => s.y).toList();
    final minWeight = weights.min;
    final maxWeight = weights.max;
    final avgWeight = weights.reduce((a, b) => a + b) / weights.length;
    final firstWeight = weights.first;
    final lastWeight = weights.last;
    final totalChange = lastWeight - firstWeight;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 24, bottom: 16),
          child: Text(
            '統計サマリー',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF424242),
              letterSpacing: 0.5,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatTile('最小', '${minWeight.toStringAsFixed(1)}', 'kg', Icons.arrow_downward, const Color(0xFF00ACC1), theme),
            _buildStatTile('最大', '${maxWeight.toStringAsFixed(1)}', 'kg', Icons.arrow_upward, const Color(0xFF00ACC1), theme),
            _buildStatTile('平均', '${avgWeight.toStringAsFixed(1)}', 'kg', Icons.analytics_outlined, const Color(0xFF00ACC1), theme),
            _buildStatTile(
              '変化',
              '${totalChange >= 0 ? '+' : ''}${totalChange.toStringAsFixed(1)}',
              'kg',
              totalChange >= 0 ? Icons.trending_up : Icons.trending_down,
              const Color(0xFF00ACC1),
              theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, String unit, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13, // 拡大
                  fontWeight: FontWeight.w900, // より太く
                  color: Colors.grey.shade700, // 少し濃く
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8), // パディング拡大
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20), // 16から20に拡大
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24, // 22から24に拡大
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF212121),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 13, // 12から13に拡大
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500, // 少し濃く
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
