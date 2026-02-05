import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_log.dart';
import 'package:fitness_app/home_screen.dart';

class AddManualLogScreen extends StatefulWidget {
  final DateTime? selectedDate;

  const AddManualLogScreen({super.key, this.selectedDate});

  @override
  State<AddManualLogScreen> createState() => _AddManualLogScreenState();
}

class _AddManualLogScreenState extends State<AddManualLogScreen> {
  final TextEditingController _exerciseNameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _maxRepsWeightController = TextEditingController();
  final TextEditingController _maxRepsCountController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  late DateTime _selectedDate;
  bool _isSaving = false;
  int _selectedIndex = 2; // Progress tab

  // 候補となる種目リスト
  static const List<String> _exerciseOptions = [
    'Benchpress',
    'Squat',
    'Weighted Pullup',
    'Bulgarian Split Squat',
  ];

  Color _getExerciseColor(String? exercise) {
    switch (exercise) {
      case 'Benchpress':
        return Colors.blue.shade600;
      case 'Squat':
        return Colors.orange.shade700;
      case 'Weighted Pullup':
        return Colors.green.shade600;
      case 'Bulgarian Split Squat':
        return Colors.teal.shade600;
      default:
        return Colors.purple.shade600;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    _weightController.dispose();
    _maxRepsWeightController.dispose();
    _maxRepsCountController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': index});
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveLog() async {
    final exerciseName = _exerciseNameController.text.trim();
    final maxWeightText = _weightController.text.trim();
    final maxRepsWeightText = _maxRepsWeightController.text.trim();
    final maxRepsCountText = _maxRepsCountController.text.trim();

    if (exerciseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目名を入力してください')),
      );
      return;
    }

    final double? maxWeight = double.tryParse(maxWeightText);
    final double? maxRepsWeight = double.tryParse(maxRepsWeightText);
    final int? maxRepsCount = int.tryParse(maxRepsCountText);

    bool hasMaxWeight = maxWeight != null && maxWeight > 0;
    bool hasMaxReps = maxRepsWeight != null && maxRepsWeight > 0 && maxRepsCount != null && maxRepsCount > 0;

    if (!hasMaxWeight && !hasMaxReps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('重量または最大repを入力してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1RMの記録
      if (hasMaxWeight) {
        final log = WorkoutLog(
          completedDate: _selectedDate,
          menuTitle: exerciseName,
          workoutDetails: 'Max record @ ${maxWeight.toStringAsFixed(1)}kg',
          sessionTitle: exerciseName,
          successCount: 1,
          failCount: 0,
        );
        await _dbService.addLog(log);
      }

      // 最大repの記録
      if (hasMaxReps) {
        final log = WorkoutLog(
          completedDate: _selectedDate,
          menuTitle: exerciseName,
          workoutDetails: 'Max record @ ${maxRepsWeight.toStringAsFixed(1)}kg x $maxRepsCount reps',
          sessionTitle: exerciseName,
          successCount: 1,
          failCount: 0,
        );
        await _dbService.addLog(log);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('記録を保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
    final themeColor = _getExerciseColor(_exerciseNameController.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('実績の登録'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー説明カード
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
                      height: 48,
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '実績の記録',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '過去の記録や自己ベストを直接入力します。',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.emoji_events_outlined, color: themeColor.withValues(alpha: 0.5), size: 32),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                    Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '日付',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _selectDate,
                      child: const Text('変更'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 種目選択カード
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
                    Row(
                      children: [
                        Icon(Icons.fitness_center, color: themeColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '種目名',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _exerciseNameController.text.isNotEmpty && _exerciseOptions.contains(_exerciseNameController.text)
                          ? _exerciseNameController.text
                          : null,
                      decoration: InputDecoration(
                        hintText: '種目を選択してください',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: themeColor, width: 2),
                        ),
                      ),
                      items: _exerciseOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _exerciseNameController.text = newValue ?? '';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 重量・REP入力カード
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
                    Row(
                      children: [
                        Icon(Icons.monitor_weight_outlined, color: themeColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '達成重量 or 最大rep',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 最大重量セクション
                    Text(
                      '最大重量 (1RM)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0.0',
                        suffixText: 'kg',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: themeColor, width: 2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(),
                    ),
                    // 最大repセクション
                    Text(
                      '最大rep記録',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _maxRepsWeightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '重量',
                              suffixText: 'kg',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: themeColor, width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('x'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxRepsCountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '回数',
                              suffixText: 'reps',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: themeColor, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 保存ボタン
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 10),
                          Text(
                            '実績を保存',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}
