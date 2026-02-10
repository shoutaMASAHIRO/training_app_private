import 'package:flutter/material.dart';
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/home_screen.dart';

class TodayWorkoutsScreen extends StatefulWidget {
  final List<WorkoutSchedule> initialSchedules;

  const TodayWorkoutsScreen({super.key, required this.initialSchedules});

  @override
  State<TodayWorkoutsScreen> createState() => _TodayWorkoutsScreenState();
}

class _TodayWorkoutsScreenState extends State<TodayWorkoutsScreen> {
  final DatabaseService _dbService = DatabaseService();
  late List<WorkoutSchedule> _schedules;
  bool _isLoading = false;
  int _selectedIndex = 0; // Dashboard related

  @override
  void initState() {
    super.initState();
    _schedules = List.from(widget.initialSchedules);
    _refreshSchedules();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 0});
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 1});
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 2});
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 3});
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 4});
        break;
    }
  }

  Future<void> _handleWorkoutResult(WorkoutSchedule schedule, dynamic result) async {
    if ((result == 'success' || result == 'fail') && schedule.menuTitle == '10x10') {
      await _dbService.adjustNext10x10Workout(schedule, result == 'success');
    }
    await _refreshSchedules();
  }

  Future<void> _refreshSchedules() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final allSchedules = await _dbService.getSchedules();
      final today = DateUtils.dateOnly(DateTime.now());
      setState(() {
        _schedules = allSchedules
            .where((s) =>
                DateUtils.dateOnly(s.scheduledDate) == today && !s.isCompleted)
            .toList();
      });
    } catch (e) {
      debugPrint('Error refreshing schedules: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Workouts"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? const Center(
                  child: Text(
                    '今日の予定はありません',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: _schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = _schedules[index];
                    return _TodayWorkoutListItem(
                      schedule: schedule,
                      onResult: (result) => _handleWorkoutResult(schedule, result),
                    );
                  },
                ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _TodayWorkoutListItem extends StatelessWidget {
  final WorkoutSchedule schedule;
  final Function(dynamic) onResult;

  const _TodayWorkoutListItem({
    required this.schedule,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final menuColor = const Color(0xFF00ACC1);
    final isCustom = schedule.menuDifficulty == 'Custom' || !['Smolov Jr.', '10x10', '5/3/1'].contains(schedule.menuTitle);

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
          
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'image/icons/$exercise.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.contain,
                      cacheWidth: 224,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 24), // 16 -> 24
                    Expanded(
                      child: Text(
                        exercise,
                        style: const TextStyle(
                          fontSize: 22, // Match sessionTitle size
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00ACC1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.fitness_center, color: Color(0xFF424242), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        setsStr.replaceAll('+', '～限界'),
                        style: const TextStyle(
                          fontSize: 17, // Unified detail size
                          color: Color(0xFF424242),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
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
        border: Border.all(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: menuColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    schedule.menuTitle,
                    style: TextStyle(
                      color: menuColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (schedule.sessionTitle != null &&
                schedule.sessionTitle!.isNotEmpty &&
                !RegExp(r'^(Workout [A-Z]|Cycle Day|High Volume Session|Session \d+|Volume Day|Recovery Day|Intensity Day|.* Session)$').hasMatch(schedule.sessionTitle!)) ...[
              const SizedBox(height: 16),
              Text(
                schedule.sessionTitle!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00ACC1), // Changed session title to Cyan
                ),
              ),
            ],
            if (schedule.workoutDetails != null &&
                schedule.workoutDetails!.isNotEmpty) ...[
              const SizedBox(height: 12),
              isCustom
                  ? buildCustomDetails(schedule.workoutDetails!)
                  : Row(
                      children: [
                        const Icon(Icons.fitness_center,
                            color: Color(0xFF424242), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            schedule.workoutDetails!.replaceAll('+', '～限界'),
                            style: const TextStyle(
                              fontSize: 17,
                              color: Color(0xFF424242),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/workout', arguments: schedule)
                      .then((result) {
                    onResult(result);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'トレーニングを開始',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}