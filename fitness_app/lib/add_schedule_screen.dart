import 'package:fitness_app/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_schedule.dart';

class AddScheduleScreen extends StatefulWidget {
  final DateTime? selectedDate;

  const AddScheduleScreen({super.key, this.selectedDate});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final TextEditingController _workoutNameController = TextEditingController();
  final TextEditingController _workoutDetailsController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  late DateTime _selectedDate;
  int _selectedIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    _workoutDetailsController.dispose();
    super.dispose();
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
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateUtils.dateOnly(picked);
      });
    }
  }

  void _showWorkoutSelectionDialog() async {
    final String? selectedWorkout = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Workout Menu'),
          content: WorkoutSelectionDialog(
            onSelectWorkout: (workoutName) {
              Navigator.of(context).pop(workoutName);
            },
          ),
        );
      },
    );

    if (selectedWorkout != null) {
      if (selectedWorkout == 'Smolov Jr.' || selectedWorkout == '10x10') {
        // プログラム系は詳細画面に遷移（選択した日付を渡す）
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/workout_detail',
            arguments: {
              'workoutName': selectedWorkout,
              'startDate': _selectedDate,
            },
          );
        }
      } else {
        // 単発ワークアウトの場合はここで設定
        _workoutNameController.text = selectedWorkout;
      }
    }
  }

  Future<void> _saveSchedule() async {
    if (_workoutNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ワークアウトメニューを選択してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final schedule = WorkoutSchedule(
        id: 0,
        scheduledDate: _selectedDate,
        isCompleted: false,
        menuTitle: _workoutNameController.text,
        menuDifficulty: '',
        workoutDetails: _workoutDetailsController.text.isNotEmpty
            ? _workoutDetailsController.text
            : null,
      );

      await _dbService.addSchedule(schedule);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('スケジュールを保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('スケジュール追加'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 日付選択カード
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      child: const Text('変更'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // プログラム選択ボタン
            Text(
              'プログラムを選択',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            // Smolov Jr. カード
            _buildProgramCard(
              name: 'Smolov Jr.',
              description: '3週間の高頻度プログラム',
              color: Colors.red,
              icon: Icons.trending_up,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/workout_detail',
                  arguments: {
                    'workoutName': 'Smolov Jr.',
                    'startDate': _selectedDate,
                  },
                );
              },
            ),
            const SizedBox(height: 8),

            // 10x10 カード
            _buildProgramCard(
              name: '10x10',
              description: 'ジャーマンボリュームトレーニング',
              color: Colors.blue,
              icon: Icons.grid_view,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/workout_detail',
                  arguments: {
                    'workoutName': '10x10',
                    'startDate': _selectedDate,
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // カスタムワークアウト
            Text(
              'またはカスタムワークアウトを追加',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _workoutNameController,
              decoration: InputDecoration(
                labelText: 'ワークアウト名',
                hintText: '例: ベンチプレス',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _workoutDetailsController,
              decoration: InputDecoration(
                labelText: '詳細（オプション）',
                hintText: '例: 5x5 @ 80kg',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveSchedule,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('カスタムスケジュールを保存'),
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

  Widget _buildProgramCard({
    required String name,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget to select workout from a dialog (kept for compatibility)
class WorkoutSelectionDialog extends StatelessWidget {
  final ValueChanged<String> onSelectWorkout;

  const WorkoutSelectionDialog({super.key, required this.onSelectWorkout});

  final List<String> _workoutMenus = const ['Smolov Jr.', '10x10'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _workoutMenus.length,
        itemBuilder: (context, index) {
          final menuName = _workoutMenus[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: GestureDetector(
              onTap: () => onSelectWorkout(menuName),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade400),
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
      ),
    );
  }
}
