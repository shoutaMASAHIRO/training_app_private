import 'dart:async';
import 'package:fitness_app/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_log.dart';

class WorkoutScreen extends StatefulWidget {
  final WorkoutSchedule schedule;
  const WorkoutScreen({super.key, required this.schedule});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final DatabaseService _apiService = DatabaseService();
  late final WorkoutSchedule _todaysSchedule;
  int _selectedIndex = 0; // Default to 'Dashboard'

  // 成功・失敗カウント
  int _successCount = 0;
  int _failCount = 0;

  // ストップウォッチ
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsedTime = '00:00.00';

  @override
  void initState() {
    super.initState();
    _todaysSchedule = widget.schedule;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
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

  void _startStopwatch() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _elapsedTime = _formatTime(_stopwatch.elapsed);
      });
    });
  }

  void _stopStopwatch() {
    _stopwatch.stop();
    _timer?.cancel();
    setState(() {
      _elapsedTime = _formatTime(_stopwatch.elapsed);
    });
  }

  void _resetStopwatch() {
    _stopwatch.reset();
    _stopwatch.stop();
    _timer?.cancel();
    setState(() {
      _elapsedTime = '00:00.00';
    });
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final centiseconds = twoDigits((duration.inMilliseconds.remainder(1000)) ~/ 10);
    return '$minutes:$seconds.$centiseconds';
  }

  void _onSuccess() {
    setState(() {
      _successCount++;
    });
  }

  void _onFail() {
    setState(() {
      _failCount++;
    });
  }

  void _resetCounts() {
    setState(() {
      _successCount = 0;
      _failCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSmolovJr = _todaysSchedule.menuTitle == 'Smolov Jr.';

    return Scaffold(
      appBar: AppBar(
        title: Text(_todaysSchedule.menuTitle),
      ),
      body: isSmolovJr
          ? _buildSmolovJrWorkout()
          : _buildGenericWorkout(),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildSmolovJrWorkout() {
    final totalCount = _successCount + _failCount;
    final isRunning = _stopwatch.isRunning;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 今日のメニュー詳細
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Smolov Jr.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_todaysSchedule.sessionTitle != null && _todaysSchedule.sessionTitle!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _todaysSchedule.sessionTitle!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF424242),
                      ),
                    ),
                  ],
                  if (_todaysSchedule.workoutDetails != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _todaysSchedule.workoutDetails!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // カウント結果表示
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'セット結果',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCountDisplay('成功', _successCount, Colors.green.shade700),
                      _buildCountDisplay('失敗', _failCount, Colors.red.shade700),
                      _buildCountDisplay('合計', totalCount, Colors.blueGrey),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ストップウォッチ
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'レストタイマー',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _elapsedTime,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                      color: isRunning ? const Color(0xFF424242) : Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: isRunning ? _stopStopwatch : _startStopwatch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRunning ? const Color(0xFFFFB74D) : const Color(0xFF81C784), // Orange stop, Green start
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isRunning ? 'ストップ' : 'スタート'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _resetStopwatch,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('リセット'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 成功・失敗ボタン
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _onSuccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C784), // Light Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '成功',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onFail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB74D), // Light Orange
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '失敗',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // カウントリセット
          TextButton(
            onPressed: _resetCounts,
            child: const Text(
              'カウントをリセット',
              style: TextStyle(color: Color(0xFFBA68C8), fontWeight: FontWeight.bold), // Light Purple
            ),
          ),
          const SizedBox(height: 24),

          // 完了ボタン
          ElevatedButton(
            onPressed: () async {
              try {
                // スケジュールを完了にする
                await _apiService.completeSchedule(_todaysSchedule.id);

                // ログを保存
                final log = WorkoutLog(
                  completedDate: DateTime.now(),
                  menuTitle: _todaysSchedule.menuTitle,
                  workoutDetails: _todaysSchedule.workoutDetails,
                  sessionTitle: _todaysSchedule.sessionTitle,
                  successCount: _successCount,
                  failCount: _failCount,
                );
                await _apiService.addLog(log);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ワークアウト完了！ 🎉'),
                      backgroundColor: Color(0xFF81C784),
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('エラー: $e'),
                      backgroundColor: const Color(0xFFFFB74D),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA68C8), // Light Purple
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'ワークアウト完了',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountDisplay(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildGenericWorkout() {
    final totalCount = _successCount + _failCount;
    final isRunning = _stopwatch.isRunning;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 今日のメニュー詳細
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_todaysSchedule.sessionTitle != null && _todaysSchedule.sessionTitle!.isNotEmpty) ...[
                    Text(
                      _todaysSchedule.sessionTitle!,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _todaysSchedule.menuTitle,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (_todaysSchedule.workoutDetails != null && _todaysSchedule.workoutDetails!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _todaysSchedule.workoutDetails!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // カウント結果表示
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'セット結果',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCountDisplay('成功', _successCount, Colors.green.shade700),
                      _buildCountDisplay('失敗', _failCount, Colors.red.shade700),
                      _buildCountDisplay('合計', totalCount, Colors.blueGrey),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ストップウォッチ
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'レストタイマー',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _elapsedTime,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                      color: isRunning ? const Color(0xFF424242) : Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: isRunning ? _stopStopwatch : _startStopwatch,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isRunning ? Colors.orange.shade700 : Colors.green.shade700,
                          side: BorderSide(
                            color: isRunning ? Colors.orange.shade700 : Colors.green.shade700,
                          ),
                        ),
                        child: Text(isRunning ? 'ストップ' : 'スタート'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _resetStopwatch,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: const Text('リセット'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 成功・失敗ボタン
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onSuccess,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '成功',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _onFail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '失敗',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // カウントリセット
          TextButton(
            onPressed: _resetCounts,
            child: Text(
              'カウントをリセット',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),

          // 完了ボタン
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _apiService.completeSchedule(_todaysSchedule.id);

                      // ログを保存
                      final log = WorkoutLog(
                        completedDate: DateTime.now(),
                        menuTitle: _todaysSchedule.menuTitle,
                        workoutDetails: _todaysSchedule.workoutDetails,
                        successCount: _successCount,
                        failCount: _failCount,
                      );
                      await _apiService.addLog(log);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ワークアウト完了！'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context, 'success');
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('エラー: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C784), // Light Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('ワークアウト完了', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _apiService.completeSchedule(_todaysSchedule.id);
                      await _apiService.addLog(
                        WorkoutLog(
                          completedDate: DateTime.now(),
                          menuTitle: _todaysSchedule.menuTitle,
                          workoutDetails: _todaysSchedule.workoutDetails,
                          sessionTitle: _todaysSchedule.sessionTitle,
                          successCount: _successCount,
                          failCount: _failCount,
                        ),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ワークアウトを記録しました'),
                            backgroundColor: Color(0xFFFFB74D), // Light Orange
                          ),
                        );
                        Navigator.pop(context, 'fail');
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('エラー: $e'),
                            backgroundColor: const Color(0xFFFFB74D),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB74D), // Light Orange
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('ワークアウト失敗', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
