import 'package:fitness_app/progress_screen.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:collection/collection.dart';
import 'package:fitness_app/logs_screen.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/models/custom_program.dart';
import 'package:fitness_app/models/workout_log.dart';

class HomeScreen extends StatefulWidget {
  final int? initialIndex;
  const HomeScreen({super.key, this.initialIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _imagesPrecached = false; // 重複キャッシュ防止フラグ

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 全ての種目アイコンをプリキャッシュして遷移をスムーズにする
    if (!_imagesPrecached) {
      _precacheImages();
      _imagesPrecached = true;
    }
  }

  void _precacheImages() {
    final exercises = [
      'バックスクワット', 'フロントスクワット', 'ボックススクワット', 'スミススクワット', 'ゴブレッドスクワット',
      'ブルガリアンスクワット', 'ハックスクワット', 'レッグプレス', 'レッグエクステンション',
      'コンベンショナルデッドリフト', 'スモウデッドリフト', 'ルーマニアンデッドリフト', 'スティフレッグデッドリフト',
      'グッドモーニング', 'ヒップスラスト', 'レッグカール', 'カーフレイズ', 'シーテッドカーフレイズ',
      'ドンキーカーフレイズ', 'バーベルベンチプレス', 'ナローバーベルベンチプレス', 'インクラインベンチプレス',
      'ダンベルプレス', 'インクラインダンベルプレス', 'ディップス', 'ペックフライ',
      'インクラインダンベルフライ', 'ケーブルフライ', 'ダンベルプルオーバー', 'ラットプルダウン',
      'プルアップ', 'インバーテッドロー', 'Tバーロー', 'ワンハンドロー', 'バーベルショルダープレス',
      'ダンベルショルダープレス', 'サイドレイズ', 'フロントレイズ', 'バーベルカール', 'ダンベルカール',
      'プリーチャーカール', 'ケーブルカール', 'JMプレス', 'バーベルエクステンション',
      'ケーブルエクステンション', 'ケーブルプレスダウン', 'キックバック', 'バーベルリストカール',
      'ダンベルリストカール', 'ケーブルリストカール'
    ];

    for (var name in exercises) {
      precacheImage(AssetImage('image/icons/$name.png'), context);
    }
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
      const MenuTabScreen(), // リネーム
      const ProgramsScreen(),
      const ProgressScreen(),
      const LogsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome Back!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF00ACC1)),
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
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Programs',
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
  bool _isProgramsExpanded = false; // Add expansion state, default to hidden

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
        .where((s) => isSameDay(s.scheduledDate, day) && !s.isCompleted)
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
            backgroundColor: const Color(0xFF00ACC1),
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

  Future<void> _confirmDeleteSchedule(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'スケジュールの削除',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'このスケジュールを削除しますか？',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('キャンセル', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('削除', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performDeleteSchedule(id);
    }
  }

  Future<void> _performDeleteSchedule(int id) async {
    try {
      await _apiService.deleteSchedule(id);
      await _refreshData();
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('スケジュールを削除しました'),
            backgroundColor: Color(0xFF00ACC1),
          ),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: ${e.toString()}'),
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

  void _navigateToWorkout(WorkoutSchedule schedule) {
    Navigator.pushNamed(context, '/workout', arguments: schedule)
        .then((result) async {
      if ((result == 'fail' || result == 'success') &&
          schedule.menuTitle == '10x10') {
        await _apiService.adjustNext10x10Workout(schedule, result == 'success');
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
        
        // --- 近日中の予定を3日分に制限するロジック ---
        // 1. 日付順にソート
        activeSchedules.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        
        // 2. 重複しない日付を抽出
        final List<DateTime> uniqueDates = [];
        for (var s in activeSchedules) {
          final dateOnly = DateUtils.dateOnly(s.scheduledDate);
          if (!uniqueDates.any((d) => isSameDay(d, dateOnly))) {
            uniqueDates.add(dateOnly);
          }
        }
        
        // 3. 直近3日分の日付を特定
        final targetDates = uniqueDates.take(3).toList();
        
        // 4. その3日間に含まれるスケジュールのみを抽出
        final upcomingSchedules = activeSchedules.where((s) {
          final dateOnly = DateUtils.dateOnly(s.scheduledDate);
          return targetDates.any((d) => isSameDay(d, dateOnly));
        }).toList();

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
            padding: EdgeInsets.zero, // Full width for header
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calendar Header Section
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)], // Cyan Gradient
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
                    locale: 'ja_JP',
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
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      leftChevronIcon:
                          const Icon(Icons.chevron_left, color: Colors.white),
                      rightChevronIcon:
                          const Icon(Icons.chevron_right, color: Colors.white),
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
                        color: Colors.white12, // さらに控えめに
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
                                              },                      headerTitleBuilder: (context, date) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('yyyy').format(date),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMMM', 'ja').format(date),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Main Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TodaysWorkoutSection(
                        upcomingSchedules: upcomingSchedules,
                        onStart: _navigateToWorkout,
                        onAddSchedule: _navigateToAddSchedule,
                        onRefresh: _refreshData,
                      ),
                      const SizedBox(height: 32),
                      
                      _buildMenuManagementSection(schedules),
                      const SizedBox(height: 32),
                      
                      _UpcomingWorkouts(
                        schedules: upcomingSchedules,
                        onComplete: _completeSchedule,
                        onEdit: (id) {},
                        onDelete: _confirmDeleteSchedule,
                      ),
                      const SizedBox(height: 40), // Bottom padding
                    ],
                  ),
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
        // 見出し部分のアップグレード
        GestureDetector(
          onTap: () {
            setState(() {
              _isProgramsExpanded = !_isProgramsExpanded;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_rounded, color: Color(0xFF00ACC1), size: 20),
                const SizedBox(width: 12),
                const Text(
                  '登録中のプログラム',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF424242),
                    letterSpacing: 0.5,
                  ),
                ),

                // セクション展開時のみ表示される「すべて削除」ボタン
                if (_isProgramsExpanded) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _confirmDeleteAllSchedules,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // サイズを拡大
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: const Text(
                        'すべて削除', // 文字列を変更
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12, // フォントサイズを拡大
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],

                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ACC1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${groupedSchedules.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _isProgramsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: const Color(0xFF00ACC1),
                ),
              ],
            ),
          ),
        ),
        
        if (_isProgramsExpanded) ...[
          const SizedBox(height: 16),
          ...groupedSchedules.entries.map((entry) {
            final firstScheduleInGroup = entry.value.first;
            final menuTitle = firstScheduleInGroup.menuTitle;
            final sessionTitle = firstScheduleInGroup.sessionTitle;
            final count = entry.value.length; // グループ内のスケジュール数

            Color color = const Color(0xFF00ACC1);
            IconData icon;
            switch (menuTitle) {
              case 'Smolov Jr.':
                icon = Icons.trending_up;
                break;
              case '10x10':
                icon = Icons.grid_view;
                break;
              case '5/3/1':
                icon = Icons.looks_3;
                break;
              default:
                icon = Icons.fitness_center;
                break;
            }
            return _buildMenuCard(
              schedule: firstScheduleInGroup,
              icon: icon,
              color: color,
              onDelete: () => _confirmDeleteMenu(menuTitle, sessionTitle, count),
            );
          }),
          const SizedBox(height: 16),
        ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
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
                                    fontSize: 17, // Increased
                                    fontWeight: FontWeight.w900, // Bolder
                                    color: Color(0xFF212121), // Darker
                                  ),
                                ),
                                if (!isCustom && schedule.workoutDetails != null && schedule.workoutDetails!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.monitor_weight_outlined, size: 14, color: Color(0xFF00ACC1)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            schedule.workoutDetails!
                                                .replaceAll('@', '')
                                                .replaceAll('+', '～限界'),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF424242),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
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
                              // カスタム詳細内の「kg」部分などの表示も統一する
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
                                    Row(
                                      children: [
                                        Image.asset(
                                          'image/icons/$exercise.png',
                                          width: 24,
                                          height: 24,
                                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            exercise,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF212121),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...sets.map((setInfo) {
                                      // @ があれば置換
                                      final displayInfo = setInfo.replaceAll('@', '').trim();
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.monitor_weight_outlined, size: 12, color: Colors.black26),
                                            const SizedBox(width: 8),
                                            Text(
                                              displayInfo,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF424242),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
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
              // 削除ボタン (統一デザイン)
              Material(
                color: Colors.red.shade50,
                child: InkWell(
                  onTap: onDelete,
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

  Future<void> _confirmDeleteMenu(String menuTitle, String? sessionTitle, int count) async {
    final displayName = sessionTitle != null && sessionTitle.isNotEmpty
        ? '$menuTitle: $sessionTitle'
        : menuTitle;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'スケジュールの削除',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          '「$displayName」のスケジュール\n$count件を削除しますか？',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('キャンセル', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('削除', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
              backgroundColor: const Color(0xFF00ACC1),
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

  Future<void> _confirmDeleteAllSchedules() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              '全ての予定を削除',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          '登録されている全てのスケジュールを\n削除してもよろしいですか？',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('キャンセル', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('全て削除', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
              backgroundColor: Color(0xFF00ACC1),
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

// --- Menu Tab Screen ---
class MenuTabScreen extends StatefulWidget {
  const MenuTabScreen({super.key});

  @override
  State<MenuTabScreen> createState() => _MenuTabScreenState();
}

class _MenuTabScreenState extends State<MenuTabScreen> {
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

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _categorizedExercises.length,
      itemBuilder: (context, index) {
        final category = _categorizedExercises.keys.elementAt(index);
        final exercises = _categorizedExercises[category]!;
        
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            maintainState: false, // 閉じている時はウィジェットを破棄して軽量化
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsets.only(bottom: 16),
            initiallyExpanded: index == 0, // 最初のカテゴリだけ最初から開いておく
            title: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ACC1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF424242),
                    ),
                  ),
                ),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            collapsedIconColor: const Color(0xFF00ACC1),
            iconColor: const Color(0xFF00ACC1),
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7, // 1.1 -> 0.7 to provide more vertical space
                ),
                itemCount: exercises.length,
                itemBuilder: (context, exIndex) {
                  final exercise = exercises[exIndex];
                  return _buildExerciseCard(exercise);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExerciseCard(String name) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/exercise_detail',
              arguments: {'exerciseName': name},
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'image/icons/$name.png',
                      fit: BoxFit.cover,
                      cacheWidth: 256,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('IMAGE LOAD ERROR: Failed to load image/icons/$name.png - Error: $error');
                        return const Icon(
                          Icons.fitness_center,
                          size: 32,
                          color: Colors.black12,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Exercise Detail Screen ---
class ExerciseDetailScreen extends StatefulWidget {
  final String exerciseName;
  const ExerciseDetailScreen({super.key, required this.exerciseName});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  double? _prWeight;
  List<WorkoutLog> _history = [];
  Map<DateTime, double> _dailyWeights = {};
  int _selectedIndex = 1; // Default to 'Menu' as it's the entry point
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _fetchExerciseData();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() { _selectedIndex = index; });
    
    switch (index) {
      case 0: Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 0}); break;
      case 1: Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 1}); break;
      case 2: Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 2}); break;
      case 3: Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 3}); break;
      case 4: Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 4}); break;
    }
  }

  List<FlSpot> _generateChartData() {
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

  Widget _buildChart(List<FlSpot> spots, List<DateTime> sortedDates, ColorScheme colorScheme) {
    if (spots.isEmpty) return const SizedBox.shrink();
    
    final weights = spots.map((s) => s.y).toList();
    final minWeight = weights.min;
    final maxWeight = weights.max;
    
    double minY = (minWeight - 10).clamp(0, double.infinity);
    minY = (minY / 10).floor() * 10.0;
    double maxY = (maxWeight + 10);
    maxY = (maxY / 10).ceil() * 10.0;
    if (maxY <= minY) maxY = minY + 20;

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
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            barWidth: 4,
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
                  strokeWidth: 2,
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
              if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                setState(() { _touchedIndex = response.lineBarSpots!.first.spotIndex; });
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF00ACC1),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  '${touchedSpot.y.toStringAsFixed(1)}kg',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSummary(List<FlSpot> spots, ColorScheme colorScheme, ThemeData theme) {
    final weights = spots.map((s) => s.y).toList();
    final minW = weights.min;
    final maxW = weights.max;
    final avgW = weights.reduce((a, b) => a + b) / weights.length;
    final firstW = weights.first;
    final lastW = weights.last;
    final change = lastW - firstW;
    
    return Column(
      children: [
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: [
            _buildStatTile('最小', minW.toStringAsFixed(1), 'kg', Icons.arrow_downward, theme),
            _buildStatTile('最大', maxW.toStringAsFixed(1), 'kg', Icons.arrow_upward, theme),
            _buildStatTile('平均', avgW.toStringAsFixed(1), 'kg', Icons.analytics_outlined, theme),
            _buildStatTile('変化', '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}', 'kg', change >= 0 ? Icons.trending_up : Icons.trending_down, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, String unit, IconData icon, ThemeData theme) {
    const color = Color(0xFF00ACC1);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade700)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF212121), fontFamily: 'monospace')),
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCalendarDialog(BuildContext context) async {
    DateTime focusedDay = DateTime.now();
    DateTime? selectedDay = DateTime.now();

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TableCalendar(
                  locale: 'ja_JP',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: focusedDay,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: (sDay, fDay) {
                    setState(() {
                      selectedDay = sDay;
                      focusedDay = fDay;
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
                    headerTitleBuilder: (context, date) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('yyyy').format(date),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMMM', 'ja').format(date),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('キャンセル', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, selectedDay),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF00ACC1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('選択', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    if (picked != null && mounted) {
      Navigator.pushNamed(
        context,
        '/add_manual_log',
        arguments: {
          'selectedDate': picked,
          'exerciseName': widget.exerciseName,
        },
      ).then((_) => _fetchExerciseData());
    }
  }

  Future<void> _fetchExerciseData() async {
    try {
      final logs = await _dbService.getLogs();
      // この種目の記録（Max recordを含むもの）を抽出
      final exerciseLogs = logs.where((log) {
        return (log.sessionTitle == widget.exerciseName || log.menuTitle == widget.exerciseName) &&
               (log.workoutDetails?.contains('Max record') ?? false);
      }).toList();

      exerciseLogs.sort((a, b) => a.completedDate.compareTo(b.completedDate));

      double? maxWeight;
      for (var log in exerciseLogs) {
        if (log.workoutDetails != null && log.workoutDetails!.contains('@')) {
          final regex = RegExp(r'@\s*(\d+(\.\d+)?)kg');
          final match = regex.firstMatch(log.workoutDetails!);
          if (match != null) {
            final weight = double.tryParse(match.group(1)!);
            if (weight != null) {
              if (maxWeight == null || weight > maxWeight) {
                maxWeight = weight;
              }
              final date = DateUtils.dateOnly(log.completedDate);
              if (!_dailyWeights.containsKey(date) || weight > _dailyWeights[date]!) {
                _dailyWeights[date] = weight;
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _prWeight = maxWeight;
          _history = exerciseLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching exercise data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // アイコン & PRカード
                  _buildHeaderCard(),
                  const SizedBox(height: 24),
                  
                  // グラフセクション
                  _buildSectionTitle('進捗グラフ', Icons.show_chart),
                  const SizedBox(height: 12),
                  _buildChartContainer(),
                  const SizedBox(height: 32),

                  // 履歴セクション
                  _buildSectionTitle('過去の記録', Icons.history),
                  const SizedBox(height: 12),
                  _buildHistoryList(),
                ],
              ),
            ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 画像を中央に大きく表示
          Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'image/icons/${widget.exerciseName}.png',
                fit: BoxFit.cover,
                cacheWidth: 384,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center, size: 96, color: Colors.black12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // PR情報を表示
          const Text(
            'PERSONAL RECORD',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF00ACC1), letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _prWeight != null ? _prWeight!.toStringAsFixed(1) : '---',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF212121), fontFamily: 'monospace'),
              ),
              const SizedBox(width: 4),
              const Text(
                'kg',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60, // 56から60に変更
            child: ElevatedButton.icon(
              onPressed: () => _showCalendarDialog(context),
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
              label: const Text(
                '実績を登録する',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF424242), // ダークグレーに変更して画像とのコントラストを調整
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // パディングを追加
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00ACC1), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF424242)),
        ),
      ],
    );
  }

  Widget _buildChartContainer() {
    if (_dailyWeights.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text('データがありません', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
      );
    }

    final spots = _generateChartData();
    final sortedDates = _getSortedDates();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          height: 260,
          padding: const EdgeInsets.fromLTRB(8, 16, 24, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.15), width: 1.5),
            boxShadow: [BoxShadow(color: const Color(0xFF00ACC1).withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: _buildChart(spots, sortedDates, colorScheme),
        ),
        const SizedBox(height: 16),
        // 追加: スケジュール登録ボタン
        SizedBox(
          width: double.infinity,
          height: 60, // 52から60に増やして垂直方向にゆとりを持たせる
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/add_schedule',
                arguments: {'exerciseName': widget.exerciseName},
              );
            },
            icon: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
            label: const Text(
              'この種目のスケジュールを追加',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ACC1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // パディングを追加
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        _buildStatisticsSummary(spots, colorScheme, Theme.of(context)),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('まだ記録がありません', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: _history.reversed.map((WorkoutLog log) {
        String weight = '---';
        if (log.workoutDetails != null && log.workoutDetails!.contains('@')) {
          weight = log.workoutDetails!.split('@')[1].trim();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('yyyy/MM/dd (E)', 'ja').format(log.completedDate),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
              ),
              Text(
                weight,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF212121), fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// --- Programs Screen ---
class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'プログラムの削除',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          '「${program.name}」を削除しますか？',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('キャンセル', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('削除', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
      'color': const Color(0xFF00ACC1), // Cyan
      'icon': Icons.trending_up,
    },
    {
      'name': '10x10',
      'description': 'ジャーマンボリュームトレーニング',
      'color': const Color(0xFF00ACC1), // Cyan
      'icon': Icons.grid_view,
    },
    {
      'name': '5/3/1',
      'description': '週3回の頻度で行う筋力向上プログラム',
      'color': const Color(0xFF00ACC1), // Cyan
      'icon': Icons.looks_3,
    },
  ];

  // 有名プログラムデータ
  static const List<Map<String, dynamic>> _famousPowerliftingMenus = [
    {
      'name': 'StrongLifts 5x5',
      'description': '初心者向け: 5回5セットの基礎プログラム',
      'color': const Color(0xFF00ACC1),
      'icon': Icons.fitness_center,
    },
    {
      'name': 'Texas Method',
      'description': '中級者向け: 週3回の強度変化プログラム',
      'color': const Color(0xFF00ACC1),
      'icon': Icons.calendar_view_week,
    },
    {
      'name': 'Candito 6-Week',
      'description': '中・上級者向け: 6週間のピーキング',
      'color': const Color(0xFF00ACC1),
      'icon': Icons.timer,
    },
    {
      'name': 'Sheiko',
      'description': '上級者向け: 高ボリューム・高頻度',
      'color': const Color(0xFF00ACC1),
      'icon': Icons.repeat,
    },
    {
      'name': 'Westside Conjugate',
      'description': '上級者向け: 最大重量と動的重量の組み合わせ',
      'color': const Color(0xFF00ACC1),
      'icon': Icons.bolt,
    },
  ];

  Widget _buildMenuCard(
    String title,
    String description,
    Color color,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
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
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF424242),
                          fontWeight: FontWeight.bold,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0), // Increased padding
      children: [
        // カテゴリーヘッダー (専用プログラム)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '専用プログラム',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        // 専用プログラムリスト
        ..._workoutMenus.map((menu) {
          return _buildMenuCard(
            menu['name'],
            menu['description'],
            menu['color'],
            menu['icon'],
            onTap: () {
              Navigator.pushNamed(
                context,
                '/workout_detail',
                arguments: {
                  'workoutName': menu['name'],
                  'startDate': DateTime.now(),
                },
              );
            },
          );
        }).toList(),

        const SizedBox(height: 32),

        // カテゴリーヘッダー (有名プログラム)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '有名プログラム',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        // 有名プログラムリスト
        ..._famousPowerliftingMenus.map((menu) {
          return _buildMenuCard(
            menu['name'],
            menu['description'],
            menu['color'],
            menu['icon'],
            onTap: () {
              Navigator.pushNamed(
                context,
                '/workout_detail',
                arguments: {
                  'workoutName': menu['name'],
                  'startDate': DateTime.now(),
                },
              );
            },
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
                  color: const Color(0xFF00ACC1), // Cyan
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
                    border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00ACC1).withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.fitness_center,
                                      color: Color(0xFF00ACC1),
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
                                ],
                              ),
                            ),
                          ),
                          // 削除ボタン (統一デザイン)
                          Material(
                            color: Colors.red.shade50,
                            child: InkWell(
                              onTap: () => _confirmDeleteCustomProgram(program),
                              child: Container(
                                width: 64,
                                alignment: Alignment.center,
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                        color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF00ACC1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '新しいプログラムを作成',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00ACC1),
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

  // 全ての種目をフラットなリストとしても保持
  static final List<String> _allExercises = _categorizedExercises.values.expand((e) => e).toList();

  // 編集用の種目リスト
  List<Map<String, dynamic>> _editableExercises = [];

  // 有名プログラム用の複数種目入力管理 (動的リスト)
  List<Map<String, dynamic>> _programExercises = [];

  List<DropdownMenuItem<String>> _buildDropdownItems(Color themeColor) {
    List<DropdownMenuItem<String>> items = [];
    _categorizedExercises.forEach((category, exercises) {
      items.add(DropdownMenuItem(
        value: category,
        enabled: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '--- $category ---',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: themeColor.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ),
      ));
      for (var exercise in exercises) {
        items.add(DropdownMenuItem(
          value: exercise,
          child: Row(
            children: [
              Image.asset(
                'image/icons/$exercise.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 20, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242), fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ));
      }
    });
    return items;
  }

  List<Widget> _buildSelectedItems() {
    List<Widget> selectedWidgets = [];
    _categorizedExercises.forEach((category, exercises) {
      selectedWidgets.add(Text(category));
      for (var exercise in exercises) {
        selectedWidgets.add(
          Row(
            children: [
              Image.asset(
                'image/icons/$exercise.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 18, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exercise,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242), fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        );
      }
    });
    return selectedWidgets;
  }

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate ?? DateTime.now();
    
    // カスタムプログラムの場合、詳細をパースして編集用リストを初期化
    if (widget.isCustom && widget.details != null) {
      _parseDetailsToEditable(widget.details!);
    }
  }

  void _addProgramExercise() {
    final weight = double.tryParse(_currentWeightController.text);
    final name = _exerciseKindController.text;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('種目を選択してください')));
      return;
    }
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('有効な重量を入力してください')));
      return;
    }

    setState(() {
      _programExercises.add({
        'name': name,
        'weight': weight,
      });
      // 入力クリア
      _currentWeightController.clear();
      // _exerciseKindController.clear(); // Keep exercise for convenience? Or clear? Let's keep it.
    });
  }

  void _removeProgramExercise(int index) {
    setState(() {
      _programExercises.removeAt(index);
    });
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
        'name': _allExercises.first,
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
                onTap: () {}, // コンテンツ内タップで閉じないようにする
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
                                                      return Theme(
                                                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                        child: ExpansionTile(
                                                          maintainState: false, // 軽量化
                                                          title: Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  entry.key,
                                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF424242)),
                                                                ),
                                                              ),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                                child: Text(
                                                                  '${entry.value.length}',
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
                                                          children: entry.value.map((exercise) {
                                                            return ListTile(
                                                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                                              leading: Container(
                                                                padding: const EdgeInsets.all(8),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.grey[50],
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: Image.asset(
                                                                  'image/icons/$exercise.png',
                                                                  width: 96,
                                                                  height: 96,
                                                                  fit: BoxFit.contain,
                                                                  cacheWidth: 150, // 192 -> 150 (さらに軽量化)
                                                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade400),
                                                                ),
                                                              ),
                                    title: Text(
                                      exercise,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF424242)),
                                    ),
                                    onTap: () {
                                      onSelect(exercise);
                                      Navigator.pop(context);
                                    },
                                  );
                                }).toList(),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
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
      case 1: // Menu
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 1});
        break;
      case 2: // Programs
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 2});
        break;
      case 3: // Progress
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 3});
        break;
      case 4: // Logs
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 4});
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
            backgroundColor: const Color(0xFF00ACC1),
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
            backgroundColor: const Color(0xFF00ACC1),
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

  // StrongLifts 5x5 プログラムを登録
  Future<void> _registerStrongLiftsProgram() async {
    if (_programExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('種目を少なくとも1つ追加してください')));
      return;
    }
    setState(() => _isRegistering = true);

    try {
      final List<WorkoutSchedule> schedules = [];
      // スタート重量は1RMの75%とする
      final weightsMap = { for (var ex in _programExercises) ex['name'] as String : (ex['weight'] as double) * 0.75 };

      final squats = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('squat')).toList();
      final benches = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('bench')).toList();
      final rows = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('row')).toList();
      final ohps = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('press') && !e['name'].toString().toLowerCase().contains('bench')).toList();
      final deadlifts = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('deadlift')).toList();
      final others = _programExercises.where((e) => 
        !e['name'].toString().toLowerCase().contains('squat') && !e['name'].toString().toLowerCase().contains('bench') &&
        !e['name'].toString().toLowerCase().contains('row') && !e['name'].toString().toLowerCase().contains('press') &&
        !e['name'].toString().toLowerCase().contains('deadlift')
      ).toList();

      final sortedDays = List<int>.from(_selectedDays)..sort();
      if (sortedDays.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('曜日を少なくとも1つ選択してください')));
        }
        return;
      }

      // Generate all valid workout dates chronologically
      List<DateTime> workoutDates = [];
      DateTime currentDate = _startDate;
      int sessionsNeeded = 12 * sortedDays.length; // 12 weeks * days per week
      
      while (workoutDates.length < sessionsNeeded) {
        if (sortedDays.contains(currentDate.weekday)) {
          workoutDates.add(currentDate);
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      for (int i = 0; i < workoutDates.length; i++) {
        final scheduledDate = workoutDates[i];
        final week = i ~/ sortedDays.length;
        final dayIndex = i % sortedDays.length; // 0-based index in the week's sessions
        
        final workoutIndex = i; // Sequential workout index
        final isWorkoutA = workoutIndex % 2 == 0;
        StringBuffer details = StringBuffer();

        for (var ex in squats) details.write('${ex['name']}: 5x5 @ ${(weightsMap[ex['name']]! + workoutIndex * 2.5).toStringAsFixed(1)}kg\n');
        if (isWorkoutA) {
          final aCount = (workoutIndex + 1) ~/ 2;
          for (var ex in benches) details.write('${ex['name']}: 5x5 @ ${(weightsMap[ex['name']]! + aCount * 2.5).toStringAsFixed(1)}kg\n');
          for (var ex in rows) details.write('${ex['name']}: 5x5 @ ${(weightsMap[ex['name']]! + aCount * 2.5).toStringAsFixed(1)}kg\n');
        } else {
          final bCount = workoutIndex ~/ 2;
          for (var ex in ohps) details.write('${ex['name']}: 5x5 @ ${(weightsMap[ex['name']]! + bCount * 2.5).toStringAsFixed(1)}kg\n');
          for (var ex in deadlifts) details.write('${ex['name']}: 1x5 @ ${(weightsMap[ex['name']]! + bCount * 5.0).toStringAsFixed(1)}kg\n');
        }
        for (var ex in others) details.write('${ex['name']}: 3x10 @ ${((ex['weight'] as double) * 0.5).toStringAsFixed(1)}kg\n');

        if (details.isNotEmpty) {
          schedules.add(WorkoutSchedule(id: 0, scheduledDate: scheduledDate, isCompleted: false, menuTitle: 'StrongLifts 5x5', menuDifficulty: 'Week ${week + 1} Day ${dayIndex + 1}', workoutDetails: details.toString().trim(), sessionTitle: isWorkoutA ? 'Workout A' : 'Workout B'));
        }
      }
      await _apiService.addSchedules(schedules);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('StrongLifts 5x5を登録しました'), backgroundColor: Color(0xFF00ACC1)));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  // Texas Method プログラムを登録
  Future<void> _registerTexasMethodProgram() async {
    if (_programExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('種目を少なくとも1つ追加してください')));
      return;
    }
    setState(() => _isRegistering = true);

    try {
      final List<WorkoutSchedule> schedules = [];
      final fiveRMMap = { for (var ex in _programExercises) ex['name'] as String : (ex['weight'] as double) * 0.85 };

      final squats = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('squat')).toList();
      final benches = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('bench')).toList();
      final deadlifts = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('deadlift')).toList();
      final presses = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('press') && !e['name'].toString().toLowerCase().contains('bench')).toList();
      final others = _programExercises.where((e) => !e['name'].toString().toLowerCase().contains('squat') && !e['name'].toString().toLowerCase().contains('bench') && !e['name'].toString().toLowerCase().contains('deadlift') && !e['name'].toString().toLowerCase().contains('press')).toList();

      final sortedDays = List<int>.from(_selectedDays)..sort();
      if (sortedDays.length < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('テキサスメソッドには少なくとも3つの曜日を選択してください')));
        }
        return;
      }

      // Generate valid workout dates chronologically
      // Texas Method requires fixed 3 days per week pattern. 
      // If user selects 4 days, we only use the first 3 of them each week?
      // Or do we just take the first 3 valid days found in a week?
      // Logic: Iterate weeks. In each week, find the first 3 occurrences of sortedDays.
      
      for (int week = 0; week < 8; week++) {
        DateTime weekStartSearch = _startDate.add(Duration(days: week * 7));
        List<DateTime> weekDates = [];
        DateTime currentDate = weekStartSearch;
        
        // Find 3 valid days for this week
        // Note: This naive +1 day loop ensures we find days in order starting from weekStartSearch.
        // If weekStartSearch is Wed, and selected Mon, Wed, Fri:
        // Wed(match), Thu, Fri(match), Sat, Sun, Mon(match next week.. wait)
        // If we strictly follow "Week starts on _startDate", then:
        // Day 1: Wed (Volume)
        // Day 2: Fri (Recovery)
        // Day 3: Mon (Intensity - but this is next calendar week).
        // This is actually what we want if we treat "Week" as "7-day cycle starting from StartDate".
        
        int daysFound = 0;
        while (daysFound < 3) {
          if (sortedDays.contains(currentDate.weekday)) {
            weekDates.add(currentDate);
            daysFound++;
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }

        // Day 1: Volume
        DateTime d1date = weekDates[0];
        StringBuffer vol = StringBuffer();
        for (var ex in squats) vol.write('${ex['name']}: 5x5 @ ${((fiveRMMap[ex['name']]! + week * 2.5) * 0.9).toStringAsFixed(1)}kg\n');
        for (var ex in benches) vol.write('${ex['name']}: 5x5 @ ${((fiveRMMap[ex['name']]! + week * 2.5) * 0.9).toStringAsFixed(1)}kg\n');
        for (var ex in presses) vol.write('${ex['name']}: 5x5 @ ${((fiveRMMap[ex['name']]! + week * 2.5) * 0.9).toStringAsFixed(1)}kg\n');
        if (vol.isNotEmpty) schedules.add(WorkoutSchedule(id: 0, scheduledDate: d1date, isCompleted: false, menuTitle: 'Texas Method', menuDifficulty: 'Week ${week + 1} Volume', workoutDetails: vol.toString().trim(), sessionTitle: 'Volume Day'));

        // Day 2: Recovery
        DateTime d2date = weekDates[1];
        StringBuffer rec = StringBuffer();
        for (var ex in squats) rec.write('${ex['name']}: 2x5 @ ${((fiveRMMap[ex['name']]! + week * 2.5) * 0.72).toStringAsFixed(1)}kg\n');
        for (var ex in benches) rec.write('${ex['name']}: 3x5 @ ${((fiveRMMap[ex['name']]! + week * 2.5) * 0.72).toStringAsFixed(1)}kg\n');
        if (rec.isNotEmpty) schedules.add(WorkoutSchedule(id: 0, scheduledDate: d2date, isCompleted: false, menuTitle: 'Texas Method', menuDifficulty: 'Week ${week + 1} Recovery', workoutDetails: rec.toString().trim(), sessionTitle: 'Recovery Day'));

        // Day 3: Intensity
        DateTime d3date = weekDates[2];
        StringBuffer intens = StringBuffer();
        for (var ex in squats) intens.write('${ex['name']}: 1x5 @ ${(fiveRMMap[ex['name']]! + week * 2.5).toStringAsFixed(1)}kg\n');
        for (var ex in benches) intens.write('${ex['name']}: 1x5 @ ${(fiveRMMap[ex['name']]! + week * 2.5).toStringAsFixed(1)}kg\n');
        for (var ex in presses) intens.write('${ex['name']}: 1x5 @ ${(fiveRMMap[ex['name']]! + week * 2.5).toStringAsFixed(1)}kg\n');
        for (var ex in deadlifts) intens.write('${ex['name']}: 1x5 @ ${(fiveRMMap[ex['name']]! + week * 5.0).toStringAsFixed(1)}kg\n');
        if (intens.isNotEmpty) schedules.add(WorkoutSchedule(id: 0, scheduledDate: d3date, isCompleted: false, menuTitle: 'Texas Method', menuDifficulty: 'Week ${week + 1} Intensity', workoutDetails: intens.toString().trim(), sessionTitle: 'Intensity Day'));
      }
      await _apiService.addSchedules(schedules);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texas Methodを登録しました'), backgroundColor: Color(0xFF00ACC1)));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  // 固有プログラム登録 (Candito, Sheiko, Westside)
  Future<void> _registerTemplateProgram(String programName) async {
    if (_programExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('種目を少なくとも1つ追加してください')));
      return;
    }
    setState(() => _isRegistering = true);

    try {
      final List<WorkoutSchedule> schedules = [];
      final weightsMap = { for (var ex in _programExercises) ex['name'] as String : ex['weight'] as double };
      
      final squats = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('squat')).toList();
      final benches = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('bench')).toList();
      final deadlifts = _programExercises.where((e) => e['name'].toString().toLowerCase().contains('deadlift')).toList();
      final others = _programExercises.where((e) => !e['name'].toString().toLowerCase().contains('squat') && !e['name'].toString().toLowerCase().contains('bench') && !e['name'].toString().toLowerCase().contains('deadlift')).toList();

      final sortedDays = List<int>.from(_selectedDays)..sort();
      if (sortedDays.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('曜日を少なくとも1つ選択してください')));
        }
        return;
      }

      // Generate a pool of valid workout dates starting from _startDate
      // This pool will be consumed by the programs session by session.
      List<DateTime> validDatesPool = [];
      DateTime currentDate = _startDate;
      int maxSessionsNeeded = 6 * 5; // Max case (Candito 6 weeks * max 5 days) + buffer
      // 60 days buffer is usually enough
      
      while (validDatesPool.length < maxSessionsNeeded) {
        if (sortedDays.contains(currentDate.weekday)) {
          validDatesPool.add(currentDate);
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      if (programName == 'Westside Conjugate') {
        final sessionTitles = ['Max Effort Lower', 'Max Effort Upper', 'Dynamic Effort Lower', 'Dynamic Effort Upper'];
        if (sortedDays.length < 4) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ウエストサイドには少なくとも4つの曜日を選択してください')));
          return;
        }
        for (int week = 0; week < 4; week++) {
          for (int i = 0; i < 4; i++) {
            // Use 4 sessions per week from the pool
            // Week 0: index 0, 1, 2, 3
            // Week 1: index 4, 5, 6, 7
            int poolIndex = (week * 4) + i;
            if (poolIndex >= validDatesPool.length) break;
            DateTime scheduledDate = validDatesPool[poolIndex];

            StringBuffer details = StringBuffer();
            if (i == 0) {
              for (var ex in squats) details.write('${ex['name']} Variation: 1-3 reps @ MAX\n');
              for (var ex in deadlifts) details.write('${ex['name']} Variation: 1-3 reps @ MAX\n');
            } else if (i == 1) {
              for (var ex in benches) details.write('${ex['name']} Variation: 1-3 reps @ MAX\n');
            } else if (i == 2) {
              for (var ex in squats) details.write('${ex['name']}: 10x2 @ ${(weightsMap[ex['name']]! * 0.55).toStringAsFixed(1)}kg\n');
              for (var ex in deadlifts) details.write('${ex['name']}: 10x1 @ ${(weightsMap[ex['name']]! * 0.65).toStringAsFixed(1)}kg\n');
            } else if (i == 3) {
              for (var ex in benches) details.write('${ex['name']}: 9x3 @ ${(weightsMap[ex['name']]! * 0.55).toStringAsFixed(1)}kg\n');
            }
            for (var ex in others) details.write('${ex['name']}: 3x10-15 @ ${(weightsMap[ex['name']]! * 0.5).toStringAsFixed(1)}kg\n');
            if (details.isNotEmpty) schedules.add(WorkoutSchedule(id: 0, scheduledDate: scheduledDate, isCompleted: false, menuTitle: programName, menuDifficulty: 'Week ${week + 1}', workoutDetails: details.toString().trim(), sessionTitle: sessionTitles[i]));
          }
        }
      } else if (programName == 'Candito 6-Week') {
        final weekFreqs = [5, 5, 4, 4, 3, 1]; 
        int datePoolIndex = 0;
        for (int week = 0; week < 6; week++) {
          int freq = weekFreqs[week];
          for (int day = 0; day < freq; day++) {
             if (datePoolIndex >= validDatesPool.length) break;
            DateTime scheduledDate = validDatesPool[datePoolIndex++];
            
            StringBuffer details = StringBuffer();
            double intensity = (week < 2) ? 0.8 : ((week < 4) ? 0.9 : 0.95);
            String reps = (week < 2) ? '4x6' : ((week < 4) ? '3x3' : '1x1-4');
            for (var ex in squats) details.write('${ex['name']}: $reps @ ${(weightsMap[ex['name']]! * intensity).toStringAsFixed(1)}kg\n');
            for (var ex in benches) details.write('${ex['name']}: $reps @ ${(weightsMap[ex['name']]! * intensity).toStringAsFixed(1)}kg\n');
            for (var ex in deadlifts) if (day % 2 == 1) details.write('${ex['name']}: 2x6 @ ${(weightsMap[ex['name']]! * intensity).toStringAsFixed(1)}kg\n');
            for (var ex in others) details.write('${ex['name']}: 3x10 @ ${(weightsMap[ex['name']]! * 0.6).toStringAsFixed(1)}kg\n');
            if (details.isNotEmpty) schedules.add(WorkoutSchedule(id: 0, scheduledDate: scheduledDate, isCompleted: false, menuTitle: programName, menuDifficulty: 'Week ${week + 1} Day ${day + 1}', workoutDetails: details.toString().trim(), sessionTitle: 'Cycle Day'));
          }
        }
      } else if (programName == 'Sheiko') {
        if (sortedDays.length < 3) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sheikoには少なくとも3つの曜日を選択してください')));
           return;
        }
        for (int week = 0; week < 4; week++) {
          for (int i = 0; i < 3; i++) {
            // Use 3 sessions per week from the pool
            int poolIndex = (week * 3) + i;
             if (poolIndex >= validDatesPool.length) break;
            DateTime scheduledDate = validDatesPool[poolIndex];

            StringBuffer details = StringBuffer();
            for (var ex in squats) details.write('${ex['name']}: 5x3 @ ${(weightsMap[ex['name']]! * 0.8).toStringAsFixed(1)}kg\n');
            for (var ex in benches) details.write('${ex['name']}: 5x3 @ ${(weightsMap[ex['name']]! * 0.8).toStringAsFixed(1)}kg\n');
            for (var ex in deadlifts) if (i == 1) details.write('${ex['name']}: 4x2 @ ${(weightsMap[ex['name']]! * 0.85).toStringAsFixed(1)}kg\n');
            for (var ex in others) details.write('${ex['name']}: 4x8 @ ${(weightsMap[ex['name']]! * 0.6).toStringAsFixed(1)}kg\n');
            if (details.isNotEmpty) schedules.add(WorkoutSchedule(id: 0, scheduledDate: scheduledDate, isCompleted: false, menuTitle: programName, menuDifficulty: 'Week ${week + 1} Session ${i + 1}', workoutDetails: details.toString().trim(), sessionTitle: 'High Volume Session'));
          }
        }
      }
      await _apiService.addSchedules(schedules);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$programNameを登録しました'), backgroundColor: const Color(0xFF00ACC1)));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
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
              '${dayData['reps']}x${dayData['sets']} @ ${(dayData['weight'] as double).toStringAsFixed(1)}kg';

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
            backgroundColor: const Color(0xFF00ACC1),
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

      // Generate pool of valid workout dates chronologically
      List<DateTime> validDatesPool = [];
      DateTime currentDate = startDate;
      // 4 weeks * 7 days/week (max) to be safe, though 5/3/1 is just 4 weeks.
      // 4 weeks * sortedDays.length is exact needed.
      int maxSessionsNeeded = 4 * sortedDays.length;
      
      while (validDatesPool.length < maxSessionsNeeded) {
        if (sortedDays.contains(currentDate.weekday)) {
          validDatesPool.add(currentDate);
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // 4週間のサイクルを登録
      int poolIndex = 0;
      for (int week = 0; week < 4; week++) {
        final weekData = _calculatedProgram![week];
        final dayData = (weekData['days'] as List).first;
        
        for (int i = 0; i < sortedDays.length; i++) {
          if (poolIndex >= validDatesPool.length) break;
          final scheduledDate = validDatesPool[poolIndex++];
          
          final workoutDetails =
              '${dayData['reps']}x${dayData['sets']} @ ${(dayData['weight'] as double).toStringAsFixed(1)}kg';

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
            backgroundColor: const Color(0xFF00ACC1),
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
    DateTime focusedDay = _startDate;
    DateTime? selectedDay = _startDate;

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TableCalendar(
                  locale: 'ja_JP',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: focusedDay,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: (sDay, fDay) {
                    setState(() {
                      selectedDay = sDay;
                      focusedDay = fDay;
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
                    headerTitleBuilder: (context, date) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('yyyy').format(date),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMMM', 'ja').format(date),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('キャンセル', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, selectedDay),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF00ACC1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('選択', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = DateUtils.dateOnly(picked);
      });
    }
  }

  // --- UI Helpers ---

  Widget _buildProgramDescriptionCard(String title, String description) {
    return Card(
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
                color: const Color(0xFF00ACC1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDateCard() {
    return Card(
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
    );
  }

  Widget _buildWeightInputCard(String label, TextEditingController controller) {
    return Card(
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
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
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
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF00ACC1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                fillColor: Colors.grey[100],
                filled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton(VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isRegistering ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF424242),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isRegistering
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : const Text('スケジュールに登録', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
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
                                    ...List.generate(_editableExercises.length, (index) => _buildEditableExerciseCard(index, const Color(0xFF00ACC1)))              else
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
                      : const Text('独自プログラムとして登録', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

    if (widget.workoutName == 'StrongLifts 5x5') {
      return Scaffold(
        appBar: AppBar(title: Text(widget.workoutName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgramDescriptionCard(widget.workoutName, '初心者向け: 5回5セットの基礎プログラム'),
              const SizedBox(height: 12),
              _buildStartDateCard(),
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
              
              // 種目・重量入力エリア (入力用)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('新しい種目を追加', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF212121))),
                      const SizedBox(height: 16),
                      _buildExerciseNameField(const Color(0xFF00ACC1)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _currentWeightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                        decoration: InputDecoration(
                          labelText: '1RM重量 (最大挙上重量) を入力',
                          labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.normal, fontSize: 14),
                          hintText: '100.0',
                          suffixText: 'kg',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          fillColor: Colors.grey[100],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addProgramExercise,
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                          label: const Text('リストに追加', style: TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00ACC1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 追加された種目リスト (ここがどんどん増えていく)
              if (_programExercises.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text('以下の記録からプログラムを作成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF424242))),
                ),
                ..._programExercises.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ex = entry.value;
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 6, color: const Color(0xFF00ACC1)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'image/icons/${ex['name']}.png',
                                          fit: BoxFit.cover,
                                          cacheWidth: 200,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 50, color: Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      ex['name'],
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF212121)),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.fitness_center, color: Color(0xFF424242), size: 18),
                                        const SizedBox(width: 10),
                                        Text(
                                          '1RM: ${ex['weight']}kg',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00ACC1)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.red.shade50,
                              child: InkWell(
                                onTap: () => _removeProgramExercise(index),
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
                }).toList(),
                const SizedBox(height: 24),
              ],

              _buildRegisterButton(_registerStrongLiftsProgram),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      );
    }

    if (widget.workoutName == 'Texas Method') {
      return Scaffold(
        appBar: AppBar(title: Text(widget.workoutName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgramDescriptionCard(widget.workoutName, '中級者向け: 週3回の強度変化プログラム'),
              const SizedBox(height: 12),
              _buildStartDateCard(),
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
              
              // 種目・重量入力エリア (入力用)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('新しい種目を追加', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF212121))),
                      const SizedBox(height: 16),
                      _buildExerciseNameField(const Color(0xFF00ACC1)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _currentWeightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                        decoration: InputDecoration(
                          labelText: '1RM重量 (最大挙上重量) を入力',
                          labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.normal, fontSize: 14),
                          hintText: '100.0',
                          suffixText: 'kg',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          fillColor: Colors.grey[100],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addProgramExercise,
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                          label: const Text('種目を追加', style: TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00ACC1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 追加された種目リスト
              if (_programExercises.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text('以下の記録からプログラムを作成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF424242))),
                ),
                ..._programExercises.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ex = entry.value;
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 6, color: const Color(0xFF00ACC1)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'image/icons/${ex['name']}.png',
                                          fit: BoxFit.cover,
                                          cacheWidth: 200,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 50, color: Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      ex['name'],
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF212121)),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.fitness_center, color: Color(0xFF424242), size: 18),
                                        const SizedBox(width: 10),
                                        Text(
                                          '1RM: ${ex['weight']}kg',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00ACC1)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.red.shade50,
                              child: InkWell(
                                onTap: () => _removeProgramExercise(index),
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
                }).toList(),
                const SizedBox(height: 24),
              ],

              _buildRegisterButton(_registerTexasMethodProgram),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      );
    }

    // Generic template for other famous programs
    if (['Candito 6-Week', 'Sheiko', 'Westside Conjugate'].contains(widget.workoutName)) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.workoutName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgramDescriptionCard(widget.workoutName, '上級者向けプログラムテンプレート'),
              const SizedBox(height: 12),
              _buildStartDateCard(),
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
                        '実行する曜日を選択',
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
              
              // 種目・重量入力エリア (入力用)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('新しい種目を追加', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF212121))),
                      const SizedBox(height: 16),
                      _buildExerciseNameField(const Color(0xFF00ACC1)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _currentWeightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                        decoration: InputDecoration(
                          labelText: '1RM重量 (最大挙上重量) を入力',
                          labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.normal, fontSize: 14),
                          hintText: '100.0',
                          suffixText: 'kg',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          fillColor: Colors.grey[100],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addProgramExercise,
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                          label: const Text('種目を追加', style: TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00ACC1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 追加された種目リスト
              if (_programExercises.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text('以下の記録からプログラムを作成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF424242))),
                ),
                ..._programExercises.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ex = entry.value;
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 6, color: const Color(0xFF00ACC1)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'image/icons/${ex['name']}.png',
                                          fit: BoxFit.cover,
                                          cacheWidth: 200,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 50, color: Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      ex['name'],
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF212121)),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.fitness_center, color: Color(0xFF424242), size: 18),
                                        const SizedBox(width: 10),
                                        Text(
                                          '1RM: ${ex['weight']}kg',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00ACC1)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.red.shade50,
                              child: InkWell(
                                onTap: () => _removeProgramExercise(index),
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
                }).toList(),
                const SizedBox(height: 24),
              ],

              _buildRegisterButton(() => _registerTemplateProgram(widget.workoutName)),
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
                          color: const Color(0xFF00ACC1),
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
                      _buildExerciseNameField(const Color(0xFF00ACC1)),
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
                                                                borderSide: BorderSide.none,
                                                              ),
                                                              focusedBorder: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(10),
                                                                borderSide: const BorderSide(color: const Color(0xFF00ACC1)),
                                                              ),
                                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                              fillColor: Colors.grey[100],
                                                              filled: true,
                                                            ),                            ),
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
                          color: const Color(0xFF00ACC1), // 10x10 theme color
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
                      _buildExerciseNameField(const Color(0xFF00ACC1)),
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
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: const Color(0xFF00ACC1)), // 10x10 theme color
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                fillColor: Colors.grey[100],
                                filled: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isRegistering ? null : _register10x10Program,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00ACC1), // 10x10 theme color
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
                        color: const Color(0xFF00ACC1),
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
                    _buildExerciseNameField(const Color(0xFF00ACC1)),
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
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: const Color(0xFF00ACC1)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              fillColor: Colors.grey[100],
                              filled: true,
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
                      color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '1RM: ${_maxWeightController.text}kg',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00ACC1),
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
          color: isSelected ? const Color(0xFF00ACC1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00ACC1) : Colors.grey.shade300,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          _showExerciseSelectionModal(context, (selected) {
            setState(() {
              _exerciseKindController.text = selected;
            });
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: InputDecorator(
          decoration: InputDecoration(
            hintText: '種目を選択してください',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: themeColor.withValues(alpha: 0.2), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: themeColor.withValues(alpha: 0.2), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: themeColor, width: 2),
            ),
          ),
          child: _exerciseKindController.text.isNotEmpty
            ? Column(
                children: [
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 176,
                        height: 176,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'image/icons/${_exerciseKindController.text}.png',
                            fit: BoxFit.cover,
                            cacheWidth: 352,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 72, color: Colors.grey.shade400),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: themeColor,
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
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
                            _exerciseKindController.text,
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF212121), fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.touch_app_rounded, color: themeColor, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'タップして種目を変更',
                    style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
              )
            : Text(
                '種目を選択してください',
                style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 16),
              ),
        ),
      ),
    );
  }

  Widget _buildEditableExerciseCard(int index, Color themeColor) {
    final ex = _editableExercises[index];
    final sets = ex['sets_data'] as List<Map<String, TextEditingController>>;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            _showExerciseSelectionModal(context, (selected) {
                              setState(() {
                                ex['name'] = selected;
                              });
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: '種目',
                              labelStyle: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: themeColor.withValues(alpha: 0.2), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: themeColor.withValues(alpha: 0.2), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: themeColor, width: 2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 176,
                                      height: 176,
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'image/icons/${ex['name']}.png',
                                          fit: BoxFit.cover,
                                          cacheWidth: 352,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 72, color: Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: themeColor,
                                        shape: BoxShape.circle,
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
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
                                          ex['name'],
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF212121), fontSize: 18),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.touch_app_rounded, color: themeColor, size: 18),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'タップして種目を変更',
                                  style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text('セット数', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121))), // Increased
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
                                  color: Colors.grey.shade600,
                                ),
                                Text(
                                  '${ex['sets_count']}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF212121)), // Increased
                                ),
                                IconButton(
                                  onPressed: () => _updateSetsCount(index, ex['sets_count'] + 1),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  color: themeColor,
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
                            Expanded(flex: 1, child: Text('SET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242), letterSpacing: 1))), // Darker/Larger
                            Expanded(flex: 3, child: Text('WEIGHT (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242), letterSpacing: 1))), // Darker/Larger
                            SizedBox(width: 16),
                            Expanded(flex: 3, child: Text('REPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242), letterSpacing: 1))), // Darker/Larger
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
                                  style: TextStyle(fontWeight: FontWeight.w900, color: themeColor),
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
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121)), // Increased
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
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121)), // Increased
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              // 削除ボタン (統一デザイン)
              Material(
                color: Colors.red.shade50,
                child: InkWell(
                  onTap: () => _removeExercise(index),
                  child: Container(
                    width: 64,
                    alignment: Alignment.center,
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build531WeekCard(Map<String, dynamic> weekData) {
    final week = weekData['week'] as int;
    final day = (weekData['days'] as List).first;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF00ACC1).withValues(alpha: 0.15), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ACC1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Week $week',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF212121)),
                ),
                const Spacer(),
                Text(
                  week == 4 ? 'Deload' : 'Main Set',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'image/icons/${_exerciseKindController.text}.png',
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 40, color: Colors.grey.shade400),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _exerciseKindController.text,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF424242)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${day['reps'].toString().replaceAll('+', '～限界')}x${day['sets']} @ ${day['weight']}kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00ACC1),
                            fontSize: 16,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: const Color(0xFF00ACC1).withValues(alpha: 0.15), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
                        color: const Color(0xFF00ACC1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Week $week',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ],
                ),
                if (increase > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${increase.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                        color: Color(0xFF00ACC1),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 種目アイコン表示
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'image/icons/${_exerciseKindController.text}.png',
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 40, color: Colors.grey.shade400),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _exerciseKindController.text,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF424242)),
              ),
            ),
            const Divider(height: 32),

            // 日ごとの詳細
            ...days.map((day) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      'Day ${day['day']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${day['reps']}x${day['sets']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00ACC1),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${day['percent']}%',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(day['weight'] as double).toStringAsFixed(1)}kg',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF212121),
                      fontSize: 17,
                      fontFamily: 'monospace',
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
  final VoidCallback onRefresh;

  const _TodaysWorkoutSection({
    required this.upcomingSchedules,
    required this.onStart,
    required this.onAddSchedule,
    required this.onRefresh,
  });

  static Color getMenuColor(String menuTitle) {
    return const Color(0xFF00ACC1); // Cyan
  }

  static Color getExerciseColor(String? exercise) {
    return const Color(0xFF00ACC1); // Cyan
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final List<WorkoutSchedule> todaysWorkouts = upcomingSchedules
        .where((s) => DateUtils.dateOnly(s.scheduledDate) == today)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              todaysWorkouts.isEmpty ? '今日の予定はありません' : '今日のトレーニング',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 16),
            if (todaysWorkouts.isEmpty)
              ElevatedButton(
                onPressed: onAddSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                  foregroundColor: Colors.white,
                ),
                child: const Text('＋ スケジュールを追加'),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/today_workouts', arguments: todaysWorkouts)
                      .then((_) => onRefresh());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      'トレーニングを開始 (${todaysWorkouts.length}件)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Dashboard Screens ---


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
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Upcoming',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
              ),
              TextSpan(
                text: ' （直近3日）',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
              ),
            ],
          ),
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
    Color getMenuColor(String menuTitle) {
      return const Color(0xFF00ACC1); // All programs unified to Cyan
    }

    final menuColor = getMenuColor(schedule.menuTitle);
    final exerciseColor = _TodaysWorkoutSection.getExerciseColor(schedule.sessionTitle);
    
    // 今日の日付かどうかを判定
    final isToday = DateUtils.dateOnly(schedule.scheduledDate) == DateUtils.dateOnly(DateTime.now());

    // カスタム詳細を表示用に整形
    Widget buildCustomDetails(String details) {
      if (details.isEmpty) return const SizedBox.shrink();
      
      final lines = details.split('\n').where((line) => line.isNotEmpty).toList();
      
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: lines.asMap().entries.map((entry) {
            final line = entry.value;
            final isLast = entry.key == lines.length - 1;
            
            String exercise = line;
            String setsStr = '';
            if (line.contains(': ')) {
              final parts = line.split(': ');
              exercise = parts[0];
              setsStr = parts.length > 1 ? parts[1] : '';
            }

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Image.asset(
                        'image/icons/$exercise.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                        cacheWidth: 192,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center, color: Color(0xFF00ACC1), size: 32),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF212121),
                            ),
                          ),
                          if (setsStr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              setsStr,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF424242),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isLast) 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
                  ),
              ],
            );
          }).toList(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左側のアクセントバー (今日ならオレンジ、それ以外はシアン)
              Container(
                width: 6,
                color: isToday ? Colors.deepOrangeAccent : const Color(0xFF00ACC1),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('M/d (E)', 'ja').format(schedule.scheduledDate),
                            style: TextStyle(
                              color: isToday ? Colors.deepOrangeAccent : const Color(0xFF212121),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          if (isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.deepOrangeAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.deepOrangeAccent,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: menuColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: menuColor.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              schedule.menuTitle,
                              style: TextStyle(
                                color: menuColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        schedule.sessionTitle ?? schedule.menuTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF212121),
                        ),
                      ),
                      if (schedule.workoutDetails != null && schedule.workoutDetails!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // 有名プログラムも標準デザインを使用するようにホワイトリストに追加
                        (schedule.menuDifficulty == 'Custom' || !['Smolov Jr.', '10x10', '5/3/1', 'StrongLifts 5x5', 'Texas Method', 'Candito 6-Week', 'Sheiko', 'Westside Conjugate'].contains(schedule.menuTitle))
                            ? buildCustomDetails(schedule.workoutDetails!)
                            : Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.monitor_weight_outlined, size: 18, color: const Color(0xFF00ACC1)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        schedule.workoutDetails!
                                            .replaceAll('@', '') // アットマークを削除
                                            .replaceAll('+', '～限界'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF424242),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ],
                  ),
                ),
              ),
              // 削除ボタン
              Material(
                color: Colors.red.shade50,
                child: InkWell(
                  onTap: () => onDelete(schedule.id),
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
          label: 'Menu',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_rounded),
          label: 'Programs',
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