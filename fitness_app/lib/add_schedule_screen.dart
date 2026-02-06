import 'package:fitness_app/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/models/custom_program.dart';

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
  List<CustomProgram> _customPrograms = [];

  static const List<Map<String, dynamic>> _workoutMenus = [
    {
      'name': 'Smolov Jr.',
      'description': '3週間の高頻度プログラム',
      'color': Color(0xFF00ACC1),
      'icon': Icons.trending_up,
    },
    {
      'name': '10x10',
      'description': 'ジャーマンボリュームトレーニング',
      'color': Color(0xFF00ACC1),
      'icon': Icons.grid_view,
    },
    {
      'name': '5/3/1',
      'description': '週3回の頻度で行う筋力向上プログラム',
      'color': Color(0xFF00ACC1),
      'icon': Icons.looks_3,
    },
  ];

  static const List<Map<String, dynamic>> _famousPowerliftingMenus = [
    {
      'name': 'StrongLifts 5x5',
      'description': '初心者向け: 5回5セットの基礎プログラム',
      'color': Color(0xFF00ACC1),
      'icon': Icons.fitness_center,
    },
    {
      'name': 'Texas Method',
      'description': '中級者向け: 週3回の強度変化プログラム',
      'color': Color(0xFF00ACC1),
      'icon': Icons.calendar_view_week,
    },
    {
      'name': 'Candito 6-Week',
      'description': '中・上級者向け: 6週間のピーキング',
      'color': Color(0xFF00ACC1),
      'icon': Icons.timer,
    },
    {
      'name': 'Sheiko',
      'description': '上級者向け: 高ボリューム・高頻度',
      'color': Color(0xFF00ACC1),
      'icon': Icons.repeat,
    },
    {
      'name': 'Westside Conjugate',
      'description': '上級者向け: 最大努力と動的努力の組み合わせ',
      'color': Color(0xFF00ACC1),
      'icon': Icons.bolt,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _fetchCustomPrograms();
  }

  Future<void> _fetchCustomPrograms() async {
    try {
      final programs = await _dbService.getCustomPrograms();
      setState(() {
        _customPrograms = programs;
      });
    } catch (e) {
      debugPrint('Error fetching custom programs: $e');
    }
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
            backgroundColor: Color(0xFF00ACC1),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today, color: Color(0xFF00ACC1), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '開始日',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00ACC1),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('変更'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // プログラム選択ボタン
            Row(
              children: [
                Icon(Icons.fitness_center, color: const Color(0xFF00ACC1), size: 20),
                const SizedBox(width: 8),
                const Text(
                  '人気プログラム',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._workoutMenus.map((menu) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildProgramCard(
                name: menu['name'],
                description: menu['description'],
                color: menu['color'],
                icon: menu['icon'],
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/workout_detail',
                    arguments: {
                      'workoutName': menu['name'],
                      'startDate': _selectedDate,
                    },
                  );
                },
              ),
            )),

            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: const Color(0xFF00ACC1), size: 20),
                const SizedBox(width: 8),
                const Text(
                  '有名パワーリフティングプログラム',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._famousPowerliftingMenus.map((menu) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildProgramCard(
                name: menu['name'],
                description: menu['description'],
                color: menu['color'],
                icon: menu['icon'],
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/workout_detail',
                    arguments: {
                      'workoutName': menu['name'],
                      'startDate': _selectedDate,
                    },
                  );
                },
              ),
            )),

            if (_customPrograms.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '自作プログラム',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              ..._customPrograms.map((program) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildProgramCard(
                  name: program.name,
                  description: 'カスタムメニュー',
                  color: const Color(0xFF00ACC1),
                  icon: Icons.fitness_center,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/workout_detail',
                      arguments: {
                        'workoutName': program.name,
                        'startDate': _selectedDate,
                        'isCustom': true,
                        'details': program.details,
                      },
                    );
                  },
                ),
              )),
            ],

            const SizedBox(height: 32),

            // カスタムワークアウト
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'またはカスタムワークアウトを追加',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _workoutNameController,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
              decoration: InputDecoration(
                labelText: 'ワークアウト名',
                hintText: '例: ベンチプレス',
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _workoutDetailsController,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
              decoration: InputDecoration(
                labelText: '詳細（オプション）',
                hintText: '例: 5x5 @ 80kg',
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'カスタムスケジュールを保存',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildProgramCard({
    required String name,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
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
                child: Icon(Icons.arrow_forward_rounded, color: Colors.grey.shade400, size: 20),
              ),
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
