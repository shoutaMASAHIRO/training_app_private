import 'package:flutter/material.dart';
import 'package:fitness_app/logs_screen.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fitness_app/services/api_service.dart';
import 'package:fitness_app/models/workout_schedule.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const DashboardScreen(),
    const WorkoutsScreen(),
    const Center(
      child: Text(
        'Progress Screen',
        style: TextStyle(fontSize: 24, color: Colors.black87),
      ),
    ),
    const LogsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome Back!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Logs',
          ),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: Colors.white,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}

// --- Dashboard Screen ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();

  Future<List<WorkoutSchedule>>? _schedulesData;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _hoveredDay; // For day cell hover effect
  bool _isHeaderHovered = false; // For header hover effect

  @override
  void initState() {
    super.initState();
    _schedulesData = _fetchData();
    _selectedDay = _focusedDay;
  }

  Future<List<WorkoutSchedule>> _fetchData() async {
    try {
      final schedules = await _apiService.getSchedules();
      return schedules;
    } catch (e) {
      throw Exception('Failed to fetch dashboard data: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _schedulesData = _fetchData();
    });
  }

  List<dynamic> _getEventsForDay(
      DateTime day, List<WorkoutSchedule> schedules) {
    return schedules
        .where((s) => isSameDay(s.scheduledDate, day))
        .toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      // Navigate to add schedule screen
      Navigator.pushNamed(context, '/add_schedule').then((_) => _refreshData());
    }
  }


  // --- Actions ---
  Future<void> _completeSchedule(int id) async {
    try {
      await _apiService.completeSchedule(id);
      await _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout marked as complete! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSchedule(int id) async {
    try {
      await _apiService.deleteSchedule(id);
      await _refreshData();
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule deleted.')),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Navigation ---
  void _navigateToAddSchedule() {
    Navigator.pushNamed(context, '/add_schedule').then((_) => _refreshData());
  }

  void _navigateToWorkout() {
    Navigator.pushNamed(context, '/workout').then((_) => _refreshData());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkoutSchedule>>(
      future: _schedulesData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading data: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        // スケジュールが空でもダッシュボードは表示する
        final List<WorkoutSchedule> schedules = snapshot.data ?? [];
        final upcomingSchedules =
            schedules.where((s) => !s.isCompleted).toList();

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TodaysWorkoutSection(
                  upcomingSchedules: upcomingSchedules,
                  onStart: _navigateToWorkout,
                  onAddSchedule: _navigateToAddSchedule,
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: _onDaySelected,
                      eventLoader: (day) => _getEventsForDay(day, schedules),
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
                        titleTextStyle: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        leftChevronIcon:
                            Icon(Icons.chevron_left, color: Colors.black87),
                        rightChevronIcon:
                            Icon(Icons.chevron_right, color: Colors.black87),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();

                          // イベント（スケジュール）をWorkoutScheduleとしてキャスト
                          final scheduleEvents = events.cast<WorkoutSchedule>();
                          final hasSmolovJr = scheduleEvents.any((s) => s.menuTitle == 'Smolov Jr.');

                          return Positioned(
                            bottom: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasSmolovJr ? Colors.red : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        headerTitleBuilder: (context, date) {
                          return Center(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setState(() => _isHeaderHovered = true),
                              onExit: (_) =>
                                  setState(() => _isHeaderHovered = false),
                              child: GestureDetector(
                                onTap: () => _onHeaderTapped(context, date),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    DateFormat('yyyy年M月').format(date),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _isHeaderHovered
                                          ? Colors.grey.shade600
                                          : Colors.black87,
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
                            decoration = const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            );
                          } else if (isToday) {
                            decoration = BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              shape: BoxShape.circle,
                            );
                          } else if (isHovered) {
                            decoration = BoxDecoration(
                              color: Colors.grey.withOpacity(0.3),
                              shape: BoxShape.circle,
                            );
                          } else {
                            decoration = const BoxDecoration(shape: BoxShape.circle);
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
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      calendarStyle: const CalendarStyle(
                        // Default marker style is fine
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _UpcomingWorkouts(
                  schedules: upcomingSchedules,
                  onComplete: _completeSchedule,
                  onEdit: (id) {}, // Placeholder
                  onDelete: _deleteSchedule,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onHeaderTapped(BuildContext context, DateTime focusedDay) {
    showDatePicker(
      context: context,
      initialDate: focusedDay,
      firstDate: DateTime.utc(2020, 1, 1),
      lastDate: DateTime.utc(2030, 12, 31),
    ).then((pickedDate) {
      if (pickedDate != null) {
        setState(() {
          _focusedDay = pickedDate;
          _selectedDay = pickedDate; // Also update the selected day
        });
        // Navigate to add schedule screen after picking a date from the header
        Navigator.pushNamed(context, '/add_schedule').then((_) => _refreshData());
      }
    });
  }
}

// --- Workouts Screen (New) ---
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  // メニューデータ
  static const List<Map<String, dynamic>> _workoutMenus = [
    {
      'name': 'Smolov Jr.',
      'description': '3週間の高頻度プログラム',
      'color': Colors.red,
      'icon': Icons.trending_up,
    },
    {
      'name': '10x10',
      'description': 'ジャーマンボリュームトレーニング',
      'color': Colors.blue,
      'icon': Icons.grid_view,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _workoutMenus.length,
      itemBuilder: (context, index) {
        final menu = _workoutMenus[index];
        final menuName = menu['name'] as String;
        final description = menu['description'] as String;
        final color = menu['color'] as Color;
        final icon = menu['icon'] as IconData;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/workout_detail', arguments: menuName);
            },
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // 左側のアクセントバー
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // アイコン
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // テキスト
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            menuName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 矢印
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Workout Detail Screen ---
class WorkoutDetailScreen extends StatefulWidget {
  final String workoutName;

  const WorkoutDetailScreen({super.key, required this.workoutName});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final TextEditingController _maxWeightController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>>? _calculatedProgram;
  bool _isRegistering = false;

  @override
  void dispose() {
    _maxWeightController.dispose();
    super.dispose();
  }

  // カレンダーにプログラムを登録
  Future<void> _registerProgram() async {
    if (_calculatedProgram == null) return;

    setState(() {
      _isRegistering = true;
    });

    try {
      debugPrint('=== Smolov Jr. 登録開始 ===');

      // 既存のSmolov Jr.スケジュールを削除
      debugPrint('既存スケジュール削除中...');
      await _apiService.deleteSchedulesByMenuTitle('Smolov Jr.');
      debugPrint('既存スケジュール削除完了');

      // 今日を起点として各ワークアウト日を計算
      final today = DateUtils.dateOnly(DateTime.now());
      final List<WorkoutSchedule> schedules = [];

      int dayOffset = 0;
      for (int week = 0; week < 3; week++) {
        final weekData = _calculatedProgram![week];
        final days = weekData['days'] as List<Map<String, dynamic>>;

        for (int dayIndex = 0; dayIndex < 4; dayIndex++) {
          final dayData = days[dayIndex];
          final scheduledDate = today.add(Duration(days: dayOffset));

          final workoutDetails =
              '${dayData['sets']}x${dayData['reps']} @ ${(dayData['weight'] as double).toStringAsFixed(1)}kg';

          schedules.add(WorkoutSchedule(
            id: 0, // サーバー側で生成される
            scheduledDate: scheduledDate,
            isCompleted: false,
            menuTitle: 'Smolov Jr.',
            menuDifficulty: 'Week ${week + 1} Day ${dayIndex + 1}',
            workoutDetails: workoutDetails,
          ));

          debugPrint('スケジュール追加: ${scheduledDate.toIso8601String()} - $workoutDetails');

          // 次のワークアウトは1日後（週4回なので連続日）
          dayOffset++;

          // 週4日後に1日休み（オプション）
          if (dayIndex == 3 && week < 2) {
            dayOffset++; // 週末に1日休み
          }
        }
      }

      // 一括登録
      debugPrint('APIに${schedules.length}件のスケジュールを登録中...');
      await _apiService.addSchedules(schedules);
      debugPrint('=== 登録完了 ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プログラムをカレンダーに登録しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== 登録エラー ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登録に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  void _calculateSmolovJr() {
    final maxWeight = double.tryParse(_maxWeightController.text);
    if (maxWeight == null || maxWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な最大重量を入力してください')),
      );
      return;
    }

    // Smolov Jr. プログラム計算
    // Week 1: 70%, 75%, 80%, 85%
    // Week 2: +2.5kg
    // Week 3: +5kg
    final List<Map<String, dynamic>> program = [];

    final weeklyIncrease = [0.0, 2.5, 5.0]; // 週ごとの増加量
    final dayConfigs = [
      {'sets': 6, 'reps': 6, 'percent': 0.70},
      {'sets': 7, 'reps': 5, 'percent': 0.75},
      {'sets': 8, 'reps': 4, 'percent': 0.80},
      {'sets': 10, 'reps': 3, 'percent': 0.85},
    ];

    for (int week = 0; week < 3; week++) {
      List<Map<String, dynamic>> weekDays = [];
      for (int day = 0; day < 4; day++) {
        final config = dayConfigs[day];
        final baseWeight = maxWeight * (config['percent'] as double);
        final weight = baseWeight + weeklyIncrease[week];
        // 2.5kg刻みに丸める
        final roundedWeight = (weight / 2.5).round() * 2.5;

        weekDays.add({
          'day': day + 1,
          'sets': config['sets'],
          'reps': config['reps'],
          'percent': ((config['percent'] as double) * 100).toInt(),
          'weight': roundedWeight,
        });
      }
      program.add({
        'week': week + 1,
        'increase': weeklyIncrease[week],
        'days': weekDays,
      });
    }

    setState(() {
      _calculatedProgram = program;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Smolov Jr.以外のメニューはプレースホルダー表示
    if (widget.workoutName != 'Smolov Jr.') {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.workoutName),
        ),
        body: Center(
          child: Text('Details for ${widget.workoutName} will be added here.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // プログラム説明カード
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // 左側のアクセントバー
                    Container(
                      width: 4,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Smolov Jr. プログラム',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '3週間の高頻度プログラム・週4回トレーニング',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 最大重量入力セクション
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1RM (最大重量) を入力',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _maxWeightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '例: 100',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              suffixText: 'kg',
                              suffixStyle: TextStyle(color: Colors.grey.shade600),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _calculateSmolovJr,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('計算'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 計算結果表示
            if (_calculatedProgram != null) ...[
              Row(
                children: [
                  Text(
                    '3週間プログラム',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '1RM: ${_maxWeightController.text}kg',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._calculatedProgram!.map((weekData) => _buildWeekCard(weekData)),
              const SizedBox(height: 16),
              // 登録ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRegistering ? null : _registerProgram,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRegistering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month, size: 20),
                            SizedBox(width: 8),
                            Text('カレンダーに登録'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '今日を起点として3週間分のスケジュールを登録します',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekCard(Map<String, dynamic> weekData) {
    final week = weekData['week'] as int;
    final increase = weekData['increase'] as double;
    final days = weekData['days'] as List<Map<String, dynamic>>;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Week $week',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (increase > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${increase.toStringAsFixed(1)}kg',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // 日ごとの詳細
            ...days.map((day) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      'Day ${day['day']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${day['sets']}x${day['reps']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${day['percent']}%',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(day['weight'] as double).toStringAsFixed(1)}kg',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// --- Dashboard Widgets ---

class _TodaysWorkoutSection extends StatelessWidget {
  final List<WorkoutSchedule> upcomingSchedules;
  final VoidCallback onStart;
  final VoidCallback onAddSchedule;

  const _TodaysWorkoutSection({
    required this.upcomingSchedules,
    required this.onStart,
    required this.onAddSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final WorkoutSchedule? todaysSchedule = upcomingSchedules.firstWhereOrNull(
      (s) => DateUtils.dateOnly(s.scheduledDate) == today,
    );

    if (todaysSchedule == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('No upcoming workouts.',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onAddSchedule,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                child: const Text('＋ Add a Schedule'),
              ),
            ],
          ),
        ),
      );
    }
    
    // メニュー名に対応した色を取得
    Color getMenuColor(String menuTitle) {
      switch (menuTitle) {
        case 'Smolov Jr.':
          return Colors.red;
        case '10x10':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    final menuColor = getMenuColor(todaysSchedule.menuTitle);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Today's Workout",
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const Spacer(),
                Text(DateFormat('MMM d').format(todaysSchedule.scheduledDate),
                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            // メニュー名バッジ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: menuColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                todaysSchedule.menuTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // workout_detailsがあれば表示（重量・セット数）
            if (todaysSchedule.workoutDetails != null && todaysSchedule.workoutDetails!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.fitness_center, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    todaysSchedule.workoutDetails!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Workout'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.lightGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingWorkouts extends StatelessWidget {
  final List<WorkoutSchedule> schedules;
  final Function(int) onComplete;
  final Function(int) onEdit;
  final Function(int) onDelete;

  const _UpcomingWorkouts({
    required this.schedules,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (schedules.isEmpty)
          const Text('No more workouts scheduled. Time to plan!'),
        ...schedules.map((schedule) => _ScheduleCard(
              schedule: schedule,
              onComplete: onComplete,
              onEdit: onEdit,
              onDelete: onDelete,
            )),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final WorkoutSchedule schedule;
  final Function(int) onComplete;
  final Function(int) onEdit;
  final Function(int) onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // メニュー名に対応した色を取得
    Color getMenuColor(String menuTitle) {
      switch (menuTitle) {
        case 'Smolov Jr.':
          return Colors.red;
        case '10x10':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    final menuColor = getMenuColor(schedule.menuTitle);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.MMMEd().format(schedule.scheduledDate),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // メニュー名のバッジ（メニューに応じた色）
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: menuColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          schedule.menuTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // workout_detailsがあれば表示（重量・セット数など）
                  if (schedule.workoutDetails != null && schedule.workoutDetails!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            schedule.workoutDetails!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'complete') {
                  onComplete(schedule.id);
                } else if (value == 'edit') {
                  onEdit(schedule.id);
                } else if (value == 'delete') {
                  onDelete(schedule.id);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'complete',
                  child: Text('Mark as Complete'),
                ),
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}