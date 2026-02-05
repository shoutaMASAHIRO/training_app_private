import 'package:fitness_app/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:fitness_app/logs_screen.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/models/custom_program.dart';

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<Widget> widgetOptions = <Widget>[
      const DashboardScreen(),
      const WorkoutsScreen(),
      const ProgressScreen(),
      const LogsScreen(),
    ];

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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200), // Faster transition
        switchInCurve: Curves.easeOutQuad, // Snappier ease
        switchOutCurve: Curves.easeInQuad,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0), // Smaller slide distance
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: widgetOptions.elementAt(_selectedIndex),
      ),
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
    _selectedDay = _focusedDay;
    _schedulesData = _fetchData();
  }

  Future<List<WorkoutSchedule>> _fetchData() async {
    // Short delay to allow tab transition animation to finish smoothly
    await Future.delayed(const Duration(milliseconds: 150));
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
    if (isSameDay(_selectedDay, selectedDay)) {
      // Already selected, navigate to add schedule screen
      Navigator.pushNamed(
        context,
        '/add_schedule',
        arguments: {'selectedDate': selectedDay},
      ).then((_) => _refreshData());
    } else {
      // New date selected, just update state
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
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
        final activeSchedules = schedules.where((s) => !s.isCompleted).toList();
        final upcomingSchedules = activeSchedules;

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
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0), // Increased screen padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300), // Faster
                  curve: Curves.easeOutQuad,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 15 * (1 - value)), // Smaller distance
                        child: child,
                      ),
                    );
                  },
                  child: _TodaysWorkoutSection(
                    upcomingSchedules: upcomingSchedules,
                    onStart: _navigateToWorkout,
                    onAddSchedule: _navigateToAddSchedule,
                  ),
                ),
                const SizedBox(height: 32), // Increased gap
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 350), // Faster
                  curve: Curves.easeOutQuad,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 15 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0), // More room around calendar
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
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        leftChevronIcon:
                            Icon(Icons.chevron_left, color: Colors.grey.shade400),
                        rightChevronIcon:
                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();

                          final scheduleEvents = events.cast<WorkoutSchedule>();
                          final hasSmolovJr = scheduleEvents.any((s) => s.menuTitle == 'Smolov Jr.');
                          final has10x10 = scheduleEvents.any((s) => s.menuTitle == '10x10');
                          final has531 = scheduleEvents.any((s) => s.menuTitle == '5/3/1');
                          final hasOther = scheduleEvents.any((s) =>
                              s.menuTitle != 'Smolov Jr.' &&
                              s.menuTitle != '10x10' &&
                              s.menuTitle != '5/3/1' &&
                              s.menuTitle.isNotEmpty);

                          List<Widget> markers = [];
                          if (hasSmolovJr) {
                            markers.add(Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFFB74D), // Light Orange
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
                                color: Color(0xFF81C784), // Light Green
                              ),
                            ));
                          }
                          if (has531) {
                            markers.add(Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFBA68C8), // Light Purple
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
                                color: Colors.grey, // Grey for others
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
                                          ? const Color(0xFF81C784) // Light Green hover
                                          : const Color(0xFF424242), // Dark Grey
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
                              color: const Color(0xFF81C784), // Light Green
                              borderRadius: BorderRadius.circular(8.0),
                            );
                          } else if (isToday) {
                            decoration = BoxDecoration(
                              color: const Color(0xFF81C784).withValues(alpha: 0.2), // Faint Green
                              borderRadius: BorderRadius.circular(8.0),
                            );
                          } else if (isHovered) {
                            decoration = BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
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
                                        : const Color(0xFF424242),
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
              ),
                const SizedBox(height: 32),
                // メニュー管理セクション
                _buildMenuManagementSection(schedules),
                const SizedBox(height: 32),
                // 全てのスケジュールを削除するボタン (登録中のプログラムがある場合のみ表示)
                if (activeSchedules.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirmDeleteAllSchedules,
                      icon: const Icon(Icons.delete_forever, color: Colors.white),
                      label: const Text('全てのスケジュールを削除'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (activeSchedules.isNotEmpty) const SizedBox(height: 24),
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
    // 未完了のスケジュールのみを対象とする
    final activeSchedules = schedules.where((s) => !s.isCompleted).toList();

    // 何も登録されていない場合は表示しない
    if (activeSchedules.isEmpty) {
      return const SizedBox.shrink();
    }

    // (menuTitle, sessionTitle) の組み合わせでグループ化
    final Map<String, List<WorkoutSchedule>> groupedSchedules = {};
    for (var schedule in activeSchedules) {
      final key = '${schedule.menuTitle}-${schedule.sessionTitle ?? 'NULL'}';
      if (!groupedSchedules.containsKey(key)) {
        groupedSchedules[key] = [];
      }
      groupedSchedules[key]!.add(schedule);
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
        ...groupedSchedules.entries.map((entry) {
          final firstScheduleInGroup = entry.value.first;
          final menuTitle = firstScheduleInGroup.menuTitle;
          final sessionTitle = firstScheduleInGroup.sessionTitle;
          final count = entry.value.length; // グループ内のスケジュール数

          Color color;
          IconData icon;
          switch (menuTitle) {
            case 'Smolov Jr.':
              color = const Color(0xFFFFB74D); // Light Orange
              icon = Icons.trending_up;
              break;
            case '10x10':
              color = const Color(0xFF81C784); // Light Green
              icon = Icons.grid_view;
              break;
            case '5/3/1':
              color = const Color(0xFFBA68C8); // Light Purple
              icon = Icons.looks_3;
              break;
            default:
              color = Colors.grey;
              icon = Icons.fitness_center;
              break;
          }
          return _buildMenuCard(
            schedule: firstScheduleInGroup, // グループの代表となるスケジュールを渡す
            icon: icon,
            color: color,
            onDelete: () => _confirmDeleteMenu(menuTitle, sessionTitle, count),
          );
        }),
      ],
    );
  }

  Widget _buildMenuCard({
    required WorkoutSchedule schedule,
    required IconData icon, // Icon based on menuTitle
    required Color color, // Color based on menuTitle
    required VoidCallback onDelete,
  }) {
    String displayName = schedule.sessionTitle ?? schedule.menuTitle;
    if (schedule.sessionTitle != null && schedule.sessionTitle!.isNotEmpty) {
      if (schedule.menuTitle != schedule.sessionTitle) { // Avoid "Smolov Jr.: Smolov Jr."
        displayName = '${schedule.menuTitle}: ${schedule.sessionTitle}';
      }
    } else if (schedule.menuDifficulty.isNotEmpty && schedule.menuDifficulty != 'Custom') {
      displayName = '${schedule.menuTitle}: ${schedule.menuDifficulty}';
    }

    final isCustom = schedule.menuDifficulty == 'Custom' || !['Smolov Jr.', '10x10', '5/3/1'].contains(schedule.menuTitle);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  // メニュー名
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isCustom && schedule.workoutDetails != null && schedule.workoutDetails!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              schedule.workoutDetails!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
              if (isCustom && schedule.workoutDetails != null && schedule.workoutDetails!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: schedule.workoutDetails!.split('\n').map((line) {
                      if (line.isEmpty) return const SizedBox.shrink();
                      final parts = line.split(': ');
                      final exercise = parts[0];
                      final setsStr = parts.length > 1 ? parts[1] : '';
                      final sets = setsStr.split(', ');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF424242),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...sets.map((setInfo) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    setInfo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMenu(String menuTitle, String? sessionTitle, int count) async {
    final displayName = sessionTitle != null && sessionTitle.isNotEmpty
        ? '$menuTitle: $sessionTitle'
        : menuTitle;

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
          '$displayName の未完了スケジュール $count 件を削除しますか？\n\nこの操作は取り消せません。',
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
        await _apiService.deleteSchedulesByMenuTitleAndSessionTitle(menuTitle, sessionTitle);
        await _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$displayName のスケジュールを削除しました'),
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

  Future<void> _confirmDeleteAllSchedules() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('全削除の確認'),
          ],
        ),
        content: const Text(
          '本当に全ての登録済みスケジュールを削除しますか？\n\nこの操作は取り消せません。',
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
            child: const Text('全て削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteAllSchedules();
        await _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('全てのスケジュールを削除しました'),
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
}

// --- Workouts Screen (New) ---
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<CustomProgram> _customPrograms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomPrograms();
  }

  Future<void> _fetchCustomPrograms() async {
    // Short delay to allow tab transition animation to finish
    await Future.delayed(const Duration(milliseconds: 150));
    final programs = await _dbService.getCustomPrograms();
    if (mounted) {
      setState(() {
        _customPrograms = programs;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDeleteCustomProgram(CustomProgram program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('プログラムの削除'),
        content: Text('カスタムプログラム「${program.name}」を削除しますか？'),
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

    if (confirmed == true && program.id != null) {
      await _deleteCustomProgram(program.id!);
    }
  }

  Future<void> _deleteCustomProgram(int id) async {
    try {
      await _dbService.deleteCustomProgram(id);
      await _fetchCustomPrograms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プログラムを削除しました')),
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

  // メニューデータ
  static const List<Map<String, dynamic>> _workoutMenus = [
    {
      'name': 'Smolov Jr.',
      'description': '3週間の高頻度プログラム',
      'color': const Color(0xFFFFB74D), // Light Orange
      'icon': Icons.trending_up,
    },
    {
      'name': '10x10',
      'description': 'ジャーマンボリュームトレーニング',
      'color': const Color(0xFF81C784), // Light Green
      'icon': Icons.grid_view,
    },
    {
      'name': '5/3/1',
      'description': '週3回の頻度で行う筋力向上プログラム',
      'color': const Color(0xFFBA68C8), // Light Purple
      'icon': Icons.looks_3,
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0), // Increased padding
      children: [
        // カテゴリーヘッダー
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20, top: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFBA68C8), // Light Purple
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '筋力強化',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
        ..._workoutMenus.asMap().entries.map((entry) {
          final index = entry.key;
          final menu = entry.value;
          final menuName = menu['name'] as String;
          final description = menu['description'] as String;
          // カラーパレットに合わせて色を調整
          Color color;
          switch (menuName) {
            case 'Smolov Jr.':
              color = const Color(0xFFFFB74D); // Light Orange
              break;
            case '10x10':
              color = const Color(0xFF81C784); // Light Green
              break;
            case '5/3/1':
              color = const Color(0xFFBA68C8); // Light Purple
              break;
            default:
              color = Colors.grey;
          }
          final icon = menu['icon'] as IconData;

          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 200 + (index * 50)),
            curve: Curves.easeOutQuad,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15), // Subtle colored shadow
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                menuName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900, // Extra bold
                                  color: Colors.black87, // Sharper black
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600, // Medium weight
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),

        const SizedBox(height: 32),

        // カスタムカテゴリーヘッダー
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF81C784), // Light Green
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'カスタム',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
        
        // 保存されたカスタムプログラムのリスト
        ..._customPrograms.asMap().entries.map((entry) {
          final index = entry.key;
          final program = entry.value;
          final offsetIndex = _workoutMenus.length + index; // Offset for staggered animation

          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 200 + (offsetIndex * 50)), // Faster stagger
            curve: Curves.easeOutQuad,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  // カスタムプログラムの詳細画面へ遷移
                  Navigator.pushNamed(
                    context,
                    '/workout_detail',
                    arguments: {
                      'workoutName': program.name,
                      'startDate': DateTime.now(),
                      'isCustom': true,
                      'details': program.details, // 詳細情報を渡す
                    },
                  ).then((_) => _fetchCustomPrograms());
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF81C784).withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF81C784).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: Color(0xFF81C784),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                program.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              if (program.details != null && program.details!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  program.details!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            color: Colors.red.shade300,
                            onPressed: () => _confirmDeleteCustomProgram(program),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),

        // カスタムメニュー作成カード
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/create_custom_menu',
              ).then((result) {
                if (result == true) {
                  _fetchCustomPrograms(); // 戻ってきたときにリストを更新
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEEEEEE), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81C784).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF81C784),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '新しいプログラムを作成',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF81C784),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Workout Detail Screen ---
class WorkoutDetailScreen extends StatefulWidget {
  final String workoutName;
  final DateTime? startDate;
  final bool isCustom;
  final String? details;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutName,
    this.startDate,
    this.isCustom = false,
    this.details,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final TextEditingController _maxWeightController = TextEditingController();
  final TextEditingController _currentWeightController = TextEditingController();
  final TextEditingController _exerciseKindController = TextEditingController(); // New controller
  final TextEditingController _customDetailsController = TextEditingController(); // New for custom
  final DatabaseService _apiService = DatabaseService();
  List<Map<String, dynamic>>? _calculatedProgram;
  bool _isRegistering = false;
  int _selectedIndex = 1; // Default to 'Workouts'
  late DateTime _startDate;
  final List<int> _selectedDays = [1, 3, 5]; // Default to Mon, Wed, Fri (1-7)

  // 候補となる種目リスト
  static const List<String> _exerciseOptions = [
    'Benchpress',
    'Squat',
    'Weighted Pullup',
    'Bulgarian Split Squat',
  ];

  // 編集用の種目リスト
  List<Map<String, dynamic>> _editableExercises = [];

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate ?? DateTime.now();
    
    // カスタムプログラムの場合、詳細をパースして編集用リストを初期化
    if (widget.isCustom && widget.details != null) {
      _parseDetailsToEditable(widget.details!);
    }
  }

  void _parseDetailsToEditable(String details) {
    _editableExercises = [];
    final lines = details.split('\n');
    for (var line in lines) {
      if (line.isEmpty) continue;
      final parts = line.split(': ');
      if (parts.length < 2) continue;
      
      final exerciseName = parts[0];
      final setsStr = parts[1];
      final sets = setsStr.split(', ');
      
      List<Map<String, TextEditingController>> setsData = [];
      for (var setInfo in sets) {
        final setParts = setInfo.split('kg x ');
        final weight = setParts[0];
        final reps = setParts.length > 1 ? setParts[1] : '0';
        
        setsData.add({
          'weight': TextEditingController(text: weight),
          'reps': TextEditingController(text: reps),
        });
      }
      
      _editableExercises.add({
        'name': exerciseName,
        'sets_count': setsData.length,
        'sets_data': setsData,
      });
    }
  }

  void _addExercise() {
    setState(() {
      _editableExercises.add({
        'name': _exerciseOptions.first,
        'sets_count': 3,
        'sets_data': List.generate(3, (index) => {
          'weight': TextEditingController(text: '0.0'),
          'reps': TextEditingController(text: '10')
        }),
      });
    });
  }

  void _removeExercise(int index) {
    setState(() {
      final ex = _editableExercises[index];
      for (var set in (ex['sets_data'] as List<Map<String, TextEditingController>>)) {
        set['weight']!.dispose();
        set['reps']!.dispose();
      }
      _editableExercises.removeAt(index);
    });
  }

  void _updateSetsCount(int exerciseIndex, int newCount) {
    if (newCount < 1) return;
    setState(() {
      final currentData = _editableExercises[exerciseIndex]['sets_data'] as List<Map<String, TextEditingController>>;
      if (newCount > currentData.length) {
        currentData.addAll(List.generate(newCount - currentData.length, 
          (index) => {
            'weight': TextEditingController(text: '0.0'),
            'reps': TextEditingController(text: '10')
          }));
      } else if (newCount < currentData.length) {
        for (int i = currentData.length - 1; i >= newCount; i--) {
          currentData[i]['weight']!.dispose();
          currentData[i]['reps']!.dispose();
        }
        currentData.removeRange(newCount, currentData.length);
      }
      _editableExercises[exerciseIndex]['sets_count'] = newCount;
    });
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
    _exerciseKindController.dispose();
    _customDetailsController.dispose();
    for (var ex in _editableExercises) {
      for (var set in (ex['sets_data'] as List<Map<String, TextEditingController>>)) {
        set['weight']!.dispose();
        set['reps']!.dispose();
      }
    }
    super.dispose();
  }

  // 単発のカスタムプログラムをスケジュールに登録
  Future<void> _registerCustomInstance() async {
    if (_editableExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目を少なくとも1つ追加してください')),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      // 編集された内容からworkoutDetails文字列を構築
      StringBuffer detailsBuffer = StringBuffer();
      for (var ex in _editableExercises) {
        detailsBuffer.write('${ex['name']}: ');
        final sets = ex['sets_data'] as List<Map<String, TextEditingController>>;
        List<String> setStrings = [];
        for (int i = 0; i < sets.length; i++) {
          final w = sets[i]['weight']!.text;
          final r = sets[i]['reps']!.text;
          setStrings.add('${w}kg x ${r}');
        }
        detailsBuffer.write(setStrings.join(', '));
        detailsBuffer.write('\n');
      }

      final schedule = WorkoutSchedule(
        id: 0,
        scheduledDate: _startDate,
        isCompleted: false,
        menuTitle: widget.workoutName,
        menuDifficulty: 'Custom',
        workoutDetails: detailsBuffer.toString().trim(),
        sessionTitle: null,
      );

      await _apiService.addSchedule(schedule);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('スケジュールに登録しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
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

  // 10x10 プログラムを登録
  Future<void> _register10x10Program() async {
    debugPrint('[LOG] _register10x10Program called.');
    debugPrint('[LOG] Current Weight: ${_currentWeightController.text}, Exercise Kind: ${_exerciseKindController.text}');
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
      // 既存の10x10スケジュールを削除しないように変更

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
          sessionTitle: _exerciseKindController.text.isNotEmpty
              ? _exerciseKindController.text
              : null,
        ));
        debugPrint('スケジュール追加: ${scheduledDate.toIso8601String()} - $workoutDetails');
      }

      // 一括登録
      debugPrint('APIに${schedules.length}件のスケジュールを登録中... Schedules: ${schedules.map((s) => s.toMap()).toList()}');
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
    debugPrint('[LOG] _registerProgram called.');
    debugPrint('[LOG] Max Weight: ${_maxWeightController.text}, Exercise Kind: ${_exerciseKindController.text}');
    if (_calculatedProgram == null) return;

    setState(() {
      _isRegistering = true;
    });

    try {
      debugPrint('=== Smolov Jr. 登録開始 ===');
      // 既存のSmolov Jr.スケジュールを削除しないように変更

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
                      sessionTitle: _exerciseKindController.text.isNotEmpty
                          ? _exerciseKindController.text
                          : null,          ));

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
      debugPrint('APIに${schedules.length}件のスケジュールを登録中... Schedules: ${schedules.map((s) => s.toMap()).toList()}');
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

  // 5/3/1 プログラムを登録
  Future<void> _register531Program() async {
    debugPrint('[LOG] _register531Program called.');
    if (_calculatedProgram == null) return;

    setState(() {
      _isRegistering = true;
    });

    try {
      debugPrint('=== 5/3/1 登録開始 ===');
      final startDate = DateUtils.dateOnly(_startDate);
      final List<WorkoutSchedule> schedules = [];

      // Sort selected days to ensure they are in order
      final sortedDays = List<int>.from(_selectedDays)..sort();
      if (sortedDays.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('曜日を少なくとも1つ選択してください')),
          );
        }
        return;
      }

      // 4週間のサイクルを登録
      for (int week = 0; week < 4; week++) {
        final weekData = _calculatedProgram![week];
        final dayData = (weekData['days'] as List).first;
        
        for (int i = 0; i < sortedDays.length; i++) {
          final targetWeekday = sortedDays[i];
          
          // Calculate the date for this specific weekday in the given week
          // Week 0 is the starting week. We find the next occurrence of targetWeekday
          // starting from startDate + (week * 7)
          DateTime weekBase = startDate.add(Duration(days: week * 7));
          
          // Adjust to the specific weekday
          // If startDate is Monday(1) and target is Wednesday(3), diff is 2.
          // We need to be careful if targetWeekday is "before" startDate's weekday.
          int dayDiff = targetWeekday - weekBase.weekday;
          if (dayDiff < 0) dayDiff += 7;
          
          final scheduledDate = weekBase.add(Duration(days: dayDiff));

          final workoutDetails =
              '${dayData['sets']}x${dayData['reps']} @ ${(dayData['weight'] as double).toStringAsFixed(1)}kg';

          schedules.add(WorkoutSchedule(
            id: 0,
            scheduledDate: scheduledDate,
            isCompleted: false,
            menuTitle: '5/3/1',
            menuDifficulty: 'Week ${week + 1} Day ${i + 1}',
            workoutDetails: workoutDetails,
            sessionTitle: _exerciseKindController.text.isNotEmpty
                ? _exerciseKindController.text
                : null,
          ));
          debugPrint('スケジュール追加: ${scheduledDate.toIso8601String()} - $workoutDetails');
        }
      }

      await _apiService.addSchedules(schedules);
      debugPrint('=== 登録完了 ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('5/3/1 プログラムをカレンダーに登録しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
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

  // 5/3/1 プログラム計算
  void _calculate531() {
    final maxWeight = double.tryParse(_maxWeightController.text);
    if (maxWeight == null || maxWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な最大重量を入力してください')),
      );
      return;
    }

    // Training Max (90% of 1RM)
    final trainingMax = maxWeight * 0.9;
    
    final List<Map<String, dynamic>> program = [];

    // Week 1: 3x5 (65%, 75%, 85%) -> We show the top set
    // Week 2: 3x3 (70%, 80%, 90%)
    // Week 3: 5/3/1 (75%, 85%, 95%)
    // Week 4: Deload (40%, 50%, 60%)
    
    final weeklyConfigs = [
      {'reps': '5+', 'percent': 0.85, 'sets': '3'},
      {'reps': '3+', 'percent': 0.90, 'sets': '3'},
      {'reps': '1+', 'percent': 0.95, 'sets': '3'},
      {'reps': '5', 'percent': 0.60, 'sets': '3'},
    ];

    for (int week = 0; week < 4; week++) {
      final config = weeklyConfigs[week];
      final weight = trainingMax * (config['percent'] as double);
      final roundedWeight = (weight / 2.5).round() * 2.5;

      program.add({
        'week': week + 1,
        'days': [
          {
            'sets': config['sets'],
            'reps': config['reps'],
            'weight': roundedWeight,
            'percent': ((config['percent'] as double) * 100).toInt(),
          }
        ],
      });
    }

    setState(() {
      _calculatedProgram = program;
    });
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
    if (widget.isCustom) {
      // カスタムプログラム専用のUI
      return Scaffold(
        appBar: AppBar(title: Text(widget.workoutName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // プログラム説明カード
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                          color: const Color(0xFF424242),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.workoutName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '自作プログラムをスケジュールに登録します',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Hero(
                        tag: 'workout_icon_${widget.workoutName}',
                        child: const Icon(Icons.fitness_center, color: Colors.black12, size: 40),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 実行日表示
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
                      Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '実行予定日',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_startDate),
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
              const SizedBox(height: 20),

              // トレーニング内容の編集セクション
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('トレーニング内容', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  TextButton.icon(
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('種目を追加'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              if (_editableExercises.isNotEmpty)
                ...List.generate(_editableExercises.length, (index) => _buildEditableExerciseCard(index, const Color(0xFF81C784)))
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('種目が設定されていません'),
                  ),
                ),

              const SizedBox(height: 32),
              
              // 登録ボタン
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isRegistering ? null : _registerCustomInstance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF424242),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isRegistering
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('スケジュールに登録', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      );
    }

    if (widget.workoutName == '5/3/1') {
      // 5/3/1-specific UI
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
                          color: const Color(0xFFBA68C8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '5/3/1 プログラム',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '週3回トレーニング・4週間のサイクル',
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
              // 種目名入力セクション
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
                        '種目名を入力',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      _buildExerciseNameField(const Color(0xFFBA68C8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 曜日選択セクション
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
                        '実行する曜日を選択 (週3回推奨)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildWeekdayButton(1, '月'),
                          _buildWeekdayButton(2, '火'),
                          _buildWeekdayButton(3, '水'),
                          _buildWeekdayButton(4, '木'),
                          _buildWeekdayButton(5, '金'),
                          _buildWeekdayButton(6, '土'),
                          _buildWeekdayButton(7, '日'),
                        ],
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
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
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
                                  borderSide: const BorderSide(color: const Color(0xFFBA68C8)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _calculate531,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF424242),
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
              if (_calculatedProgram != null && widget.workoutName == '5/3/1') ...[
                Text(
                  '4週間サイクル (Training Max: ${(_calculatedProgram![0]['days'][0]['weight'] / 0.85 * 1.0).toStringAsFixed(1)}kg)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),
                ..._calculatedProgram!.map((weekData) => _build531WeekCard(weekData)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRegistering ? null : _register531Program,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF424242),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
              // 種目名入力セクション
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
                        '種目名を入力',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      _buildExerciseNameField(Colors.blue),
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

            // 種目名入力セクション
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
                      '種目名を入力',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    _buildExerciseNameField(Colors.red),
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
                            backgroundColor: const Color(0xFF424242),
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
                    backgroundColor: const Color(0xFF424242),
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

  Widget _buildWeekdayButton(int weekday, String label) {
    final isSelected = _selectedDays.contains(weekday);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(weekday);
          } else {
            _selectedDays.add(weekday);
          }
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFBA68C8) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFBA68C8) : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseNameField(Color themeColor) {
    return DropdownButtonFormField<String>(
      value: _exerciseKindController.text.isNotEmpty && _exerciseOptions.contains(_exerciseKindController.text)
          ? _exerciseKindController.text
          : null,
      decoration: InputDecoration(
        hintText: '種目を選択してください',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
        ),
      ),
      items: _exerciseOptions.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _exerciseKindController.text = newValue ?? '';
        });
      },
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF81C784)),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(20),
    );
  }

  Widget _buildEditableExerciseCard(int index, Color themeColor) {
    final ex = _editableExercises[index];
    final sets = ex['sets_data'] as List<Map<String, TextEditingController>>;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _exerciseOptions.contains(ex['name']) ? ex['name'] : _exerciseOptions.first,
                    decoration: InputDecoration(
                      labelText: '種目',
                      labelStyle: const TextStyle(color: Color(0xFF81C784), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
                      ),
                    ),
                    items: _exerciseOptions.map((e) => DropdownMenuItem(
                      value: e, 
                      child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242))),
                    )).toList(),
                    onChanged: (val) => setState(() => ex['name'] = val),
                    icon: const Icon(Icons.unfold_more_rounded, color: Color(0xFF81C784), size: 20),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _removeExercise(index),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('セット数', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF424242))),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _updateSetsCount(index, ex['sets_count'] - 1),
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        color: Color(0xFFBA68C8), // Light Purple
                      ),
                      Text(
                        '${ex['sets_count']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF424242)),
                      ),
                      IconButton(
                        onPressed: () => _updateSetsCount(index, ex['sets_count'] + 1),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        color: Color(0xFF81C784), // Light Green
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text('SET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                  Expanded(flex: 3, child: Text('WEIGHT (kg)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                  SizedBox(width: 16),
                  Expanded(flex: 3, child: Text('REPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                ],
              ),
            ),
            ...List.generate(sets.length, (setIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        '#${setIndex + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFBA68C8)),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: sets[setIndex]['weight'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '0.0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          fillColor: Colors.grey.shade50,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: sets[setIndex]['reps'],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '10',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          fillColor: Colors.grey.shade50,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _build531WeekCard(Map<String, dynamic> weekData) {
    final week = weekData['week'] as int;
    final day = (weekData['days'] as List).first;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
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
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFBA68C8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week $week',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    week == 4 ? 'Deload' : 'Main Set',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFBA68C8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${day['sets']}x${day['reps']} @ ${day['weight']}kg',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFBA68C8),
                  fontSize: 15,
                ),
              ),
            ),
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
                        color: const Color(0xFF424242),
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
                      color: const Color(0xFF424242),
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
        return const Color(0xFFFFB74D); // Light Orange
      case '10x10':
        return const Color(0xFF81C784); // Light Green
      case '5/3/1':
        return const Color(0xFFBA68C8); // Light Purple
      default:
        return const Color(0xFF81C784); // Default to Light Green
    }
  }

  static Color getExerciseColor(String? exercise) {
    if (exercise == null) return const Color(0xFF424242);
    switch (exercise) {
      case 'Benchpress':
        return const Color(0xFF81C784); // Light Green
      case 'Squat':
        return const Color(0xFFFFB74D); // Light Orange
      case 'Weighted Pullup':
        return const Color(0xFFBA68C8); // Light Purple
      case 'Bulgarian Split Squat':
        return const Color(0xFF81C784); // Light Green
      default:
        return const Color(0xFF424242);
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
        
                    elevation: 0,
        
                    shape: RoundedRectangleBorder(
        
                      borderRadius: BorderRadius.circular(24),
        
                      side: const BorderSide(color: Color(0xFFEEEEEE), width: 2),
        
                    ),
        
                    color: const Color(0xFFF9FAFB),
        
                    child: Padding(
        
                      padding: const EdgeInsets.all(24.0),
        
                      child: Column(
        
                        crossAxisAlignment: CrossAxisAlignment.stretch,
        
                        children: [
        
                          const Text(
        
                            '今日の予定はありません',
        
                            style: TextStyle(
        
                              fontSize: 18,
        
                              fontWeight: FontWeight.bold,
        
                              color: Color(0xFF424242),
        
                            ),
        
                          ),
        
                          const SizedBox(height: 16),
        
                          ElevatedButton(
        
                            onPressed: onAddSchedule,
        
                            style: ElevatedButton.styleFrom(
        
                              backgroundColor: const Color(0xFF81C784),
        
                              foregroundColor: Colors.white,
        
                            ),
        
                            child: const Text('＋ スケジュールを追加'),
        
                          ),
        
                        ],
        
                      ),
        
                    ),
        
                  );
        
                }
        
            
        
                return Column(
        
                  children: todaysWorkouts
        
                      .map((schedule) => _TodaysWorkoutCard(
        
                            schedule: schedule,
        
                            onStart: () => onStart(schedule),
        
                          ))
        
                      .toList(),
        
                );
        
              }
        
            }

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

      final exerciseColor = _TodaysWorkoutSection.getExerciseColor(schedule.sessionTitle);

  

      // カスタム詳細を表示用に整形 (Light theme version)

      Widget buildCustomDetails(String details) {

        if (details.isEmpty) return const SizedBox.shrink();

  

        return Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: details.split('\n').map((line) {

            if (line.isEmpty) return const SizedBox.shrink();

            final parts = line.split(': ');

            final exercise = parts[0];

            final setsStr = parts.length > 1 ? parts[1] : '';

            final sets = setsStr.split(', ');

  

            return Container(

              margin: const EdgeInsets.only(top: 12),

              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                color: Colors.grey.shade50,

                borderRadius: BorderRadius.circular(16),

                border: Border.all(color: Colors.grey.shade100),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    exercise,

                    style: const TextStyle(

                      fontSize: 15,

                      fontWeight: FontWeight.bold,

                      color: Color(0xFF424242),

                    ),

                  ),

                  const SizedBox(height: 12),

                  ...sets.map((setInfo) => Padding(

                        padding: const EdgeInsets.only(bottom: 8),

                        child: Row(

                          children: [

                            Container(

                              width: 6,

                              height: 6,

                              decoration: BoxDecoration(

                                shape: BoxShape.circle,

                                color: exerciseColor.withValues(alpha: 0.6),

                              ),

                            ),

                            const SizedBox(width: 12),

                            Text(

                              setInfo,

                              style: TextStyle(

                                fontSize: 14,

                                color: Colors.grey.shade700,

                                fontWeight: FontWeight.w500,

                              ),

                            ),

                          ],

                        ),

                      )).toList(),

                ],

              ),

            );

          }).toList(),

        );

      }

  

          return Container(

  

            margin: const EdgeInsets.only(bottom: 24),

  

            decoration: BoxDecoration(

  

              color: Colors.white,

  

              borderRadius: BorderRadius.circular(24),

  

              border: Border.all(color: const Color(0xFF81C784), width: 2.0),

  

              boxShadow: [

  

                BoxShadow(

  

                  color: const Color(0xFF81C784).withValues(alpha: 0.2), // Light Green shadow

  

                  blurRadius: 16,

  

                  offset: const Offset(0, 8),

  

                ),

  

              ],

  

            ),

  

            child: Padding(

  

              padding: const EdgeInsets.all(24.0),

  

      

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                children: [

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

                    decoration: BoxDecoration(

                      color: const Color(0xFF81C784).withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: const Text(

                      "TODAY'S WORKOUT",

                      style: TextStyle(

                        color: Color(0xFF81C784),

                        fontSize: 11,

                        fontWeight: FontWeight.w900,

                        letterSpacing: 1.0,

                      ),

                    ),

                  ),

                  const Spacer(),

                  Text(

                    DateFormat('MMM d').format(schedule.scheduledDate),

                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.bold),

                  ),

                ],

              ),

              const SizedBox(height: 20),

              Row(

                children: [

                  // メニュー名バッジ

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

                    decoration: BoxDecoration(

                      color: menuColor.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(12),

                    ),

                    child: Text(

                      schedule.menuTitle,

                      style: TextStyle(

                        color: menuColor,

                        fontSize: 14,

                        fontWeight: FontWeight.w900,

                      ),

                    ),

                  ),

                  if (schedule.sessionTitle != null && schedule.sessionTitle!.isNotEmpty) ...[

                    const SizedBox(width: 12),

                    Expanded(

                      child: Text(

                        schedule.sessionTitle!,

                        style: const TextStyle(

                          fontSize: 20,

                          fontWeight: FontWeight.w800,

                          color: Color(0xFF424242),

                        ),

                        overflow: TextOverflow.ellipsis,

                      ),

                    ),

                  ],

                ],

              ),

              const SizedBox(height: 12),

              if (schedule.workoutDetails != null && schedule.workoutDetails!.isNotEmpty) ...[

                (schedule.menuDifficulty == 'Custom' || !['Smolov Jr.', '10x10', '5/3/1'].contains(schedule.menuTitle))

                    ? buildCustomDetails(schedule.workoutDetails!)

                    : Padding(

                        padding: const EdgeInsets.only(top: 16.0),

                        child: Row(

                          children: [

                            Icon(Icons.fitness_center, color: Colors.grey.shade400, size: 20),

                            const SizedBox(width: 10),

                            Expanded(

                              child: Text(

                                schedule.workoutDetails!,

                                style: TextStyle(

                                  fontSize: 18,

                                  color: Colors.grey.shade700,

                                  fontWeight: FontWeight.w600,

                                ),

                              ),

                            ),

                          ],

                        ),

                      ),

              ],

              const SizedBox(height: 24),

              SizedBox(

                width: double.infinity,

                child: ElevatedButton(

                  onPressed: onStart,

                  style: ElevatedButton.styleFrom(

                    padding: const EdgeInsets.symmetric(vertical: 18),

                    backgroundColor: const Color(0xFF81C784),

                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(16),

                    ),

                  ),

                  child: const Text(

                    'トレーニングを開始',

                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),

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
        case '5/3/1':
          return const Color(0xFFBA68C8);
        default:
          return Colors.grey;
      }
    }

    final menuColor = getMenuColor(schedule.menuTitle);
    final exerciseColor = _TodaysWorkoutSection.getExerciseColor(schedule.sessionTitle);
    
    // 今日の日付かどうかを判定
    final isToday = DateUtils.dateOnly(schedule.scheduledDate) == DateUtils.dateOnly(DateTime.now());

    // カスタム詳細を表示用に整形
    Widget buildCustomDetails(String details) {
      if (details.isEmpty) return const SizedBox.shrink();
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details.split('\n').map((line) {
          if (line.isEmpty) return const SizedBox.shrink();
          final parts = line.split(': ');
          final exercise = parts[0];
          final setsStr = parts.length > 1 ? parts[1] : '';
          final sets = setsStr.split(', ');
          
          return Container(
            margin: const EdgeInsets.only(top: 8),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isToday ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                ...sets.map((setInfo) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        setInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Card(
      elevation: isToday ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isToday ? const Color(0xFF424242) : Colors.grey.shade200,
          width: isToday ? 1.2 : 1,
        ),
      ),
      color: isToday ? const Color(0xFFFAFAFA) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.MMMEd().format(schedule.scheduledDate),
                  style: TextStyle(
                    color: isToday ? const Color(0xFF424242) : Colors.grey.shade600,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF424242),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: menuColor,
                    borderRadius: BorderRadius.circular(6),
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
                if (schedule.sessionTitle != null && schedule.sessionTitle!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedule.sessionTitle!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: exerciseColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (schedule.workoutDetails != null && schedule.workoutDetails!.isNotEmpty) ...[
              const SizedBox(height: 4),
              // カスタムまたは自作メニューの場合はリスト展開、それ以外は一行表示
              (schedule.menuDifficulty == 'Custom' || !['Smolov Jr.', '10x10', '5/3/1'].contains(schedule.menuTitle))
                  ? buildCustomDetails(schedule.workoutDetails!)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Row(
                        children: [
                          Icon(Icons.fitness_center, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            schedule.workoutDetails!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
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