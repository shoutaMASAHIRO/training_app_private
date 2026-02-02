import 'package:flutter/material.dart';
import 'package:fitness_app/profile_screen.dart';
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
    const WorkoutsScreen(), // Replaced the placeholder with WorkoutsScreen
    const Center(
      child: Text(
        'Progress Screen',
        style: TextStyle(fontSize: 24, color: Colors.black87),
      ),
    ),
    const ProfileTab(),
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
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
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
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No data found.'));
        }

        final List<WorkoutSchedule> schedules = snapshot.data!;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> workoutMenus = const ['Smolov Jr.', '10x10']; // Example menus

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: workoutMenus.length,
      itemBuilder: (context, index) {
        final menuName = workoutMenus[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 5), // Consistent spacing
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/workout_detail', arguments: menuName);
            },
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade400), // Darker border
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        menuName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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

// --- Workout Detail Screen (Placeholder) ---
class WorkoutDetailScreen extends StatelessWidget {
  final String workoutName;

  const WorkoutDetailScreen({super.key, required this.workoutName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(workoutName),
      ),
      body: Center(
        child: Text('Details for $workoutName will be added here.'),
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
                const Text('Next Up',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const Spacer(),
                Text(DateFormat('MMM d').format(todaysSchedule.scheduledDate),
                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Text(todaysSchedule.menuTitle,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Chip(
              label: Text(todaysSchedule.menuDifficulty),
              backgroundColor: Colors.white.withOpacity(0.2),
              labelStyle: const TextStyle(color: Colors.white),
            ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.MMMEd().format(schedule.scheduledDate),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule.menuTitle,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
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