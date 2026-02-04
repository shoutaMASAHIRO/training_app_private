import 'package:fitness_app/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:fitness_app/logs_screen.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_schedule.dart';

class HomeScreen extends StatefulWidget {
  final int? initialIndex;
  const HomeScreen({super.key, this.initialIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;
  }

  static final List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    WorkoutsScreen(),
    ProgressScreen(),
    LogsScreen(),
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
  final DatabaseService _apiService = DatabaseService();

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
      // Navigate to add schedule screen with selected date
      Navigator.pushNamed(
        context,
        '/add_schedule',
        arguments: {'selectedDate': selectedDay},
      ).then((_) => _refreshData());
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
    Navigator.pushNamed(
      context,
      '/add_schedule',
      arguments: {'selectedDate': _selectedDay ?? DateTime.now()},
    ).then((_) => _refreshData());
  }

  Future<void> _adjustNext10x10Workout(
      WorkoutSchedule completedSchedule, bool wasSuccess) async {
    try {
      final allSchedules = await _apiService.getSchedules();
      // Ensure schedules are sorted by date to find the correct next one
      allSchedules.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

      // 残りのすべての未完了10x10スケジュールを取得
      final remainingSchedules = allSchedules
          .where((s) =>
              s.menuTitle == '10x10' &&
              !s.isCompleted &&
              s.scheduledDate.isAfter(completedSchedule.scheduledDate))
          .toList();

      if (remainingSchedules.isEmpty) return;

      final details = completedSchedule.workoutDetails;
      double currentWeight = 0;
      if (details != null && details.contains('@')) {
        final weightString =
            details.split('@')[1].trim().split('kg')[0].trim();
        currentWeight = double.tryParse(weightString) ?? 0;
      }

      if (currentWeight <= 0) return;

      // 成功時: 次から +2.5, +5.0, +7.5, ...
      // 失敗時: 次は同じ重量、その次から +2.5, +5.0, ...
      final List<WorkoutSchedule> updatedSchedules = [];
      for (int i = 0; i < remainingSchedules.length; i++) {
        final schedule = remainingSchedules[i];
        double newWeight;
        if (wasSuccess) {
          // 成功: 基準重量から +2.5kg ずつ増加
          newWeight = currentWeight + ((i + 1) * 2.5);
        } else {
          // 失敗: 最初は同じ重量、その後 +2.5kg ずつ増加
          newWeight = currentWeight + (i * 2.5);
        }

        updatedSchedules.add(WorkoutSchedule(
          id: 0,
          scheduledDate: schedule.scheduledDate,
          isCompleted: false,
          menuTitle: schedule.menuTitle,
          menuDifficulty: schedule.menuDifficulty,
          workoutDetails: '10x10 @ ${newWeight.toStringAsFixed(1)}kg',
        ));
      }

      // 古いスケジュールを削除して新しいスケジュールを追加
      for (final schedule in remainingSchedules) {
        await _apiService.deleteSchedule(schedule.id);
      }
      await _apiService.addSchedules(updatedSchedules);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('スケジュールの調整に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToWorkout(WorkoutSchedule schedule) {
    Navigator.pushNamed(context, '/workout', arguments: schedule)
        .then((result) async {
      if ((result == 'fail' || result == 'success') &&
          schedule.menuTitle == '10x10') {
        await _adjustNext10x10Workout(schedule, result == 'success');
      }
      _refreshData();
    });
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

        // Sort upcoming schedules: primarily by date, secondarily by Smolov Jr. preference
        upcomingSchedules.sort((s1, s2) {
          final dateComparison = s1.scheduledDate.compareTo(s2.scheduledDate);
          if (dateComparison != 0) {
            return dateComparison;
          }

          // Same day, prioritize Smolov Jr.
          if (s1.menuTitle == 'Smolov Jr.' && s2.menuTitle != 'Smolov Jr.') {
            return -1; // s1 comes before s2
          }
          if (s2.menuTitle == 'Smolov Jr.' && s1.menuTitle != 'Smolov Jr.') {
            return 1; // s2 comes before s1
          }
          return s1.menuTitle.compareTo(s2.menuTitle); // Alphabetical for other cases
        });

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

                          final scheduleEvents = events.cast<WorkoutSchedule>();
                          final hasSmolovJr = scheduleEvents.any((s) => s.menuTitle == 'Smolov Jr.');
                          final has10x10 = scheduleEvents.any((s) => s.menuTitle == '10x10');
                          final hasOther = scheduleEvents.any((s) =>
                              s.menuTitle != 'Smolov Jr.' &&
                              s.menuTitle != '10x10' &&
                              s.menuTitle.isNotEmpty);

                          List<Widget> markers = [];
                          if (hasSmolovJr) {
                            markers.add(Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                            ));
                          }
                          if (has10x10) {
                            markers.add(Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                            ));
                          }
                          if (hasOther) {
                            markers.add(Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black87,
                              ),
                            ));
                          }

                          if (markers.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Positioned(
                            bottom: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: markers,
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
                            decoration = BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8.0),
                            );
                          } else if (isToday) {
                            decoration = BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8.0),
                            );
                          } else if (isHovered) {
                            decoration = BoxDecoration(
                              color: Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8.0),
                            );
                          } else {
                            decoration =
                                const BoxDecoration(shape: BoxShape.rectangle);
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
                const SizedBox(height: 16),
                // メニュー管理セクション
                _buildMenuManagementSection(schedules),
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

  Widget _buildMenuManagementSection(List<WorkoutSchedule> schedules) {
    // 登録済みのメニューを集計
    final smolovCount = schedules.where((s) => s.menuTitle == 'Smolov Jr.' && !s.isCompleted).length;
    final tenByTenCount = schedules.where((s) => s.menuTitle == '10x10' && !s.isCompleted).length;
    final otherSchedules = schedules.where((s) =>
      s.menuTitle != 'Smolov Jr.' &&
      s.menuTitle != '10x10' &&
      !s.isCompleted
    ).toList();

    // 何も登録されていない場合は表示しない
    if (smolovCount == 0 && tenByTenCount == 0 && otherSchedules.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '登録中のプログラム',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        if (smolovCount > 0)
          _buildMenuCard(
            name: 'Smolov Jr.',
            count: smolovCount,
            color: Colors.red,
            icon: Icons.trending_up,
            onDelete: () => _confirmDeleteMenu('Smolov Jr.', smolovCount),
          ),
        if (tenByTenCount > 0)
          _buildMenuCard(
            name: '10x10',
            count: tenByTenCount,
            color: Colors.blue,
            icon: Icons.grid_view,
            onDelete: () => _confirmDeleteMenu('10x10', tenByTenCount),
          ),
        ...otherSchedules
            .map((s) => s.menuTitle)
            .toSet()
            .map((menuTitle) {
              final count = otherSchedules.where((s) => s.menuTitle == menuTitle).length;
              return _buildMenuCard(
                name: menuTitle,
                count: count,
                color: Colors.grey.shade700,
                icon: Icons.fitness_center,
                onDelete: () => _confirmDeleteMenu(menuTitle, count),
              );
            }),
      ],
    );
  }

  Widget _buildMenuCard({
    required String name,
    required int count,
    required Color color,
    required IconData icon,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // アイコン
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              // メニュー名と件数
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '残り $count 回',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // 削除ボタン
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '削除',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMenu(String menuTitle, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('確認'),
          ],
        ),
        content: Text(
          '$menuTitle の未完了スケジュール $count 件を削除しますか？\n\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteSchedulesByMenuTitle(menuTitle);
        await _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$menuTitle を削除しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('削除に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
        // Navigate to add schedule screen with selected date
        Navigator.pushNamed(
          context,
          '/add_schedule',
          arguments: {'selectedDate': pickedDate},
        ).then((_) => _refreshData());
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
              Navigator.pushNamed(
                context,
                '/workout_detail',
                arguments: {
                  'workoutName': menuName,
                  'startDate': DateTime.now(),
                },
              );
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
  final DateTime? startDate;

  const WorkoutDetailScreen({super.key, required this.workoutName, this.startDate});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final TextEditingController _maxWeightController = TextEditingController();
  final TextEditingController _currentWeightController = TextEditingController();
  final DatabaseService _apiService = DatabaseService();
  List<Map<String, dynamic>>? _calculatedProgram;
  bool _isRegistering = false;
  int _selectedIndex = 1; // Default to 'Workouts'
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate ?? DateTime.now();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Dashboard
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 0});
        break;
      case 1: // Workouts
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 1});
        break;
      case 2: // Progress
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 2});
        break;
      case 3: // Logs
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 3});
        break;
    }
  }

  @override
  void dispose() {
    _maxWeightController.dispose();
    _currentWeightController.dispose();
    super.dispose();
  }

  // 10x10 プログラムを登録
  Future<void> _register10x10Program() async {
    final startWeight = double.tryParse(_currentWeightController.text);
    if (startWeight == null || startWeight <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有効な重量を入力してください')),
        );
      }
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      debugPrint('=== 10x10 登録開始 ===');

      // 既存の10x10スケジュールを削除
      debugPrint('既存スケジュール削除中...');
      await _apiService.deleteSchedulesByMenuTitle('10x10');
      debugPrint('既存スケジュール削除完了');

      final startDate = DateUtils.dateOnly(_startDate);
      final List<WorkoutSchedule> schedules = [];

      for (int i = 0; i < 10; i++) {
        final scheduledDate = startDate.add(Duration(days: i));
        final weight = startWeight + (i * 2.5);
        final workoutDetails = '10x10 @ ${weight.toStringAsFixed(1)}kg';

        schedules.add(WorkoutSchedule(
          id: 0, // サーバー側で生成される
          scheduledDate: scheduledDate,
          isCompleted: false,
          menuTitle: '10x10',
          menuDifficulty: 'Day ${i + 1}',
          workoutDetails: workoutDetails,
        ));
        debugPrint('スケジュール追加: ${scheduledDate.toIso8601String()} - $workoutDetails');
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

      // 選択した日付を起点として各ワークアウト日を計算
      final startDate = DateUtils.dateOnly(_startDate);
      final List<WorkoutSchedule> schedules = [];

      int dayOffset = 0;
      for (int week = 0; week < 3; week++) {
        final weekData = _calculatedProgram![week];
        final days = weekData['days'] as List<Map<String, dynamic>>;

        for (int dayIndex = 0; dayIndex < 4; dayIndex++) {
          final dayData = days[dayIndex];
          final scheduledDate = startDate.add(Duration(days: dayOffset));

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

          // Update offset for the next day based on user's request
          if (dayIndex == 0) { // After Day 1
            dayOffset += 1; // Day 2 is consecutive
          } else { // After Day 2, Day 3, and Day 4, add a 1-day break
            dayOffset += 2;
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

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = DateUtils.dateOnly(picked);
      });
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
    if (widget.workoutName == '10x10') {
      // 10x10-specific UI
      return Scaffold(
        appBar: AppBar(title: Text(widget.workoutName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Program description card
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
                      Container(
                        width: 4,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.blue, // 10x10 theme color
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '10x10 プログラム',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ジャーマンボリュームトレーニング',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 開始日表示
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
                      Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '開始日',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('yyyy年MM月dd日').format(_startDate),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _selectStartDate,
                        child: const Text('変更'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Current weight input section
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
                        '現在の重量を入力',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _currentWeightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '例: 80',
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
                                  borderSide: const BorderSide(color: Colors.blue), // 10x10 theme color
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isRegistering ? null : _register10x10Program,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue, // 10x10 theme color
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
                                : const Text('登録'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      );
    }

    // Smolov Jr. or other workouts
    if (widget.workoutName != 'Smolov Jr.') {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.workoutName),
        ),
        body: Center(
          child: Text('Details for ${widget.workoutName} will be added here.'),
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
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
            const SizedBox(height: 12),

            // 開始日表示
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
                    Icon(Icons.calendar_today, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '開始日',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy年MM月dd日').format(_startDate),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _selectStartDate,
                      child: const Text('変更'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

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
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
    final void Function(WorkoutSchedule) onStart;
    final VoidCallback onAddSchedule;
  
    const _TodaysWorkoutSection({
      required this.upcomingSchedules,
      required this.onStart,
      required this.onAddSchedule,
    });
  
    static Color getMenuColor(String menuTitle) {
      switch (menuTitle) {
        case 'Smolov Jr.':
          return Colors.red;
        case '10x10':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }
  
    @override
    Widget build(BuildContext context) {
      final today = DateUtils.dateOnly(DateTime.now());
      final List<WorkoutSchedule> todaysWorkouts = upcomingSchedules
          .where((s) => DateUtils.dateOnly(s.scheduledDate) == today)
          .toList();
  
      if (todaysWorkouts.isEmpty) {
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
  
      return Column(
        children: todaysWorkouts.map((schedule) => _TodaysWorkoutCard(
          schedule: schedule,
          onStart: () => onStart(schedule),
        )).toList(),
      );
    }}

// New widget for displaying a single today's workout
class _TodaysWorkoutCard extends StatelessWidget {
  final WorkoutSchedule schedule;
  final VoidCallback onStart;

  const _TodaysWorkoutCard({
    required this.schedule,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final menuColor = _TodaysWorkoutSection.getMenuColor(schedule.menuTitle);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.black87,
      margin: const EdgeInsets.only(bottom: 12), // Add margin between cards if multiple
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
                Text(DateFormat('MMM d').format(schedule.scheduledDate),
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
                schedule.menuTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // workout_detailsがあれば表示（重量・セット数）
            if (schedule.workoutDetails != null && schedule.workoutDetails!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.fitness_center, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    schedule.workoutDetails!,
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
          ],
        ),
      ),
    );
  }
}

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
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
      currentIndex: currentIndex,
      backgroundColor: Colors.white,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    );
  }
}