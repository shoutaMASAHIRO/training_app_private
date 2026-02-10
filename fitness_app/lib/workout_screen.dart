import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/home_screen.dart'; // Add this import
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/models/workout_log.dart';
import 'package:fitness_app/services/database_service.dart';

class WorkoutScreen extends StatefulWidget {
  final WorkoutSchedule schedule;

  const WorkoutScreen({super.key, required this.schedule});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final DatabaseService _apiService = DatabaseService();
  late WorkoutSchedule _todaysSchedule;
  int _selectedIndex = 1; // Workouts tab

  // 各セットの状態 (null: 未完了, true: 成功, false: 失敗)
  List<bool?> _setStatuses = [];
  // 展開されたトレーニング内容
  List<Map<String, dynamic>> _expandedExercises = [];

  // ストップウォッチ
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsedTime = '00:00.00';

  @override
  void initState() {
    super.initState();
    _todaysSchedule = widget.schedule;
    _initializeWorkoutData();
  }

  void _initializeWorkoutData() {
    _expandedExercises = [];
    final details = _todaysSchedule.workoutDetails ?? '';
    final menuTitle = _todaysSchedule.menuTitle;

    final lines = details.split('\n');
    for (var line in lines) {
      if (line.isEmpty) continue;

      String name = menuTitle;
      String content = line;
      if (line.contains(':')) {
        final parts = line.split(': ');
        name = parts[0];
        content = parts.length > 1 ? parts[1] : '';
      }

      List<String> expandedSets = [];
      final segments = content.split(', ').where((s) => s.isNotEmpty).toList();
      for (var segment in segments) {
        final regExp = RegExp(r'(\d+\+?)\s*[xX]\s*(\d+\+?)');
        final match = regExp.firstMatch(segment);
        if (match != null) {
          final val1Str = match.group(1)!;
          final val2Str = match.group(2)!;

          int numSets;
          String repsLabel;

          if (menuTitle == 'Smolov Jr.' || menuTitle == '5/3/1') {
            repsLabel = val1Str.replaceAll('+', '～限界');
            numSets = int.parse(val2Str.replaceAll('+', ''));
          } else {
            numSets = int.parse(val1Str.replaceAll('+', ''));
            repsLabel = val2Str;
          }

          String weight = segment.contains('@') ? segment.split('@')[1].trim() : '';
          for (int i = 0; i < numSets; i++) {
            expandedSets.add('$repsLabel reps ${weight.isNotEmpty ? "@ $weight" : ""}');
          }
        } else {
          expandedSets.add(segment);
        }
      }
      if (expandedSets.isNotEmpty) {
        _expandedExercises.add({
          'name': name,
          'sets': expandedSets,
        });
      }
    }

    int totalSets = 0;
    for (var ex in _expandedExercises) {
      totalSets += (ex['sets'] as List).length;
    }
    _setStatuses = List.filled(totalSets, null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
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

  void _startStopwatch() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() { _elapsedTime = _formatTime(_stopwatch.elapsed); });
    });
  }

  void _stopStopwatch() {
    _stopwatch.stop();
    _timer?.cancel();
    setState(() { _elapsedTime = _formatTime(_stopwatch.elapsed); });
  }

  void _resetStopwatch() {
    _stopwatch.reset();
    _stopwatch.stop();
    _timer?.cancel();
    setState(() { _elapsedTime = '00:00.00'; });
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final centiseconds = twoDigits((duration.inMilliseconds.remainder(1000)) ~/ 10);
    return '$minutes:$seconds.$centiseconds';
  }

  void _updateSetStatus(int index, bool? status) {
    setState(() { _setStatuses[index] = status; });
  }

  Future<void> _resetCounts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.refresh_rounded, color: Color(0xFF00ACC1), size: 48),
            SizedBox(height: 16),
            Text('カウントのリセット', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ],
        ),
        content: const Text('現在のセット記録を\n全てリセットしますか？', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161))),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('キャンセル', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00ACC1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('リセット', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() { _setStatuses = List.filled(_setStatuses.length, null); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_todaysSchedule.menuTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMainInfoCard(),
            const SizedBox(height: 16),
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildTimerCard(),
            const SizedBox(height: 24),
            _buildCompleteButton(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(currentIndex: _selectedIndex, onTap: _onItemTapped),
    );
  }

  Widget _buildMainInfoCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_todaysSchedule.sessionTitle != null && _todaysSchedule.sessionTitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(_todaysSchedule.sessionTitle!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF212121))),
          ),
        _buildSetList(const Color(0xFF00ACC1)),
      ],
    );
  }

  Widget _buildSetList(Color themeColor) {
    if (_expandedExercises.isEmpty) return const SizedBox.shrink();
    List<Widget> setWidgets = [];
    int globalSetIndex = 0;

    for (var ex in _expandedExercises) {
      final name = ex['name'] as String;
      final sets = ex['sets'] as List<String>;
      setWidgets.add(_buildExerciseStatusCard(name, sets, globalSetIndex, themeColor));
      globalSetIndex += sets.length;
    }
    return Column(children: setWidgets);
  }

  Widget _buildExerciseStatusCard(String name, List<String> sets, int startIndex, Color themeColor) {
    final exerciseStatuses = _setStatuses.sublist(startIndex, (startIndex + sets.length).clamp(0, _setStatuses.length));
    final success = exerciseStatuses.where((s) => s == true).length;
    final fail = exerciseStatuses.where((s) => s == false).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.asset(
                      'image/icons/$name.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.contain,
                      cacheWidth: 224,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 24), // 16 -> 24
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF212121)),
                      ),
                    ),
                  ],
                ),
              ),
              Row(children: [_buildSmallCountChip('成功', success, const Color(0xFF00ACC1)), const SizedBox(width: 6), _buildSmallCountChip('失敗', fail, Colors.red)]),
            ],
          ),
          const Divider(height: 24),
          ...sets.asMap().entries.map((entry) {
            final currentIndex = startIndex + entry.key;
            if (currentIndex >= _setStatuses.length) return const SizedBox.shrink();
            return _buildSetRow(currentIndex, entry.key + 1, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildSetRow(int globalIndex, int setNum, String detail) {
    Widget detailWidget;
    if (detail.contains('reps') && detail.contains('@')) {
      final parts = detail.split('@');
      detailWidget = Row(children: [Text(parts[0].trim(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF212121))), const SizedBox(width: 8), const Icon(Icons.fitness_center, color: Color(0xFF00ACC1), size: 14), const SizedBox(width: 8), Text(parts[1].trim(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF00ACC1)))]);
    } else {
      detailWidget = Text(detail, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF212121)));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildStatusIcons(globalIndex),
          const SizedBox(width: 16),
          Text('Set $setNum', style: const TextStyle(color: Color(0xFF424242), fontWeight: FontWeight.w900, fontSize: 14)),
          const Spacer(),
          detailWidget,
        ],
      ),
    );
  }

  Widget _buildStatusIcons(int index) {
    final status = _setStatuses[index];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(onTap: () => _updateSetStatus(index, status == true ? null : true), child: Icon(status == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: status == true ? const Color(0xFF00ACC1) : Colors.grey.shade300, size: 24)),
        const SizedBox(width: 8),
        GestureDetector(onTap: () => _updateSetStatus(index, status == false ? null : false), child: Icon(status == false ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded, color: status == false ? Colors.red : Colors.grey.shade300, size: 24)),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('セット結果', style: TextStyle(fontSize: 16, color: Color(0xFF424242), fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSummaryContent(),
            const SizedBox(height: 16),
            TextButton(onPressed: _resetCounts, child: const Text('カウントをリセット', style: TextStyle(color: Color(0xFF00ACC1), fontWeight: FontWeight.bold, fontSize: 15))),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryContent() {
    List<Widget> rows = [];
    int idx = 0;
    for (var ex in _expandedExercises) {
      final name = ex['name'] as String;
      final num = (ex['sets'] as List).length;
      final success = _setStatuses.sublist(idx, (idx + num).clamp(0, _setStatuses.length)).where((s) => s == true).length;
      final fail = _setStatuses.sublist(idx, (idx + num).clamp(0, _setStatuses.length)).where((s) => s == false).length;
      rows.add(_buildSummaryRow(name, success, fail));
      idx += num;
    }
    return Column(children: rows);
  }

  Widget _buildSummaryRow(String name, int success, int fail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          _buildSmallCountChip('成功', success, const Color(0xFF00ACC1)),
          const SizedBox(width: 8),
          _buildSmallCountChip('失敗', fail, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSmallCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)), const SizedBox(width: 6), Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color))]),
    );
  }

  Widget _buildTimerCard() {
    final isRunning = _stopwatch.isRunning;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('レストタイマー', style: TextStyle(fontSize: 14, color: Color(0xFF424242), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_elapsedTime, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w300, color: Color(0xFF424242), fontFamily: 'monospace')),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: isRunning ? _stopStopwatch : _startStopwatch,
                  style: OutlinedButton.styleFrom(foregroundColor: isRunning ? Colors.orange.shade700 : const Color(0xFF00ACC1), side: BorderSide(color: isRunning ? Colors.orange.shade700 : const Color(0xFF00ACC1))),
                  child: Text(isRunning ? 'ストップ' : 'スタート'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _resetStopwatch, style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade600, side: BorderSide(color: Colors.grey.shade400)), child: const Text('リセット')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return ElevatedButton(
      onPressed: () async {
        final successCount = _setStatuses.where((s) => s == true).length;
        final failCount = _setStatuses.where((s) => s == false).length;
        final totalSets = _setStatuses.length;
        final incompleteCount = totalSets - (successCount + failCount);

        // 確認ダイアログを表示
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Column(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00ACC1), size: 48),
                SizedBox(height: 16),
                Text('ワークアウトの完了', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('本日のトレーニングを終了しますか？', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF616161))),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('成功', successCount, const Color(0xFF00ACC1)),
                      _buildStatColumn('失敗', failCount, Colors.red),
                      _buildStatColumn('未完了', incompleteCount, Colors.orange),
                    ],
                  ),
                ),
                if (incompleteCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      '※未完了のセットがあるため、\nこの記録は「未達成」として保存されます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange.shade900, // より濃いオレンジに変更して視認性を向上
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56, // 高さを増やしてゆとりを持たせる
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero, // SizedBoxで制御
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('完了する', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, height: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text('まだ続ける', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        try {
          // 全てのセットが成功している場合のみ「成功」とみなす
          final bool isOverallSuccess = (successCount == totalSets);
          final String resultStatus = isOverallSuccess ? 'success' : 'fail';

          await _apiService.completeSchedule(_todaysSchedule.id);
          final log = WorkoutLog(
            completedDate: DateTime.now(),
            menuTitle: _todaysSchedule.menuTitle,
            workoutDetails: _todaysSchedule.workoutDetails,
            sessionTitle: _todaysSchedule.sessionTitle,
            successCount: successCount,
            failCount: totalSets - successCount, // 未完了分も失敗としてカウントし「未達成」にする
          );
          await _apiService.addLog(log);
          
          if (mounted) {
            String message = isOverallSuccess 
                ? 'ワークアウト完了！ 🎉' 
                : 'ワークアウト完了（一部未達成あり）';
            Color snackColor = isOverallSuccess ? const Color(0xFF00ACC1) : Colors.orange;
            
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(message), 
              backgroundColor: snackColor,
            ));
            Navigator.pop(context, resultStatus);
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red));
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00ACC1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: const Text('ワークアウト完了', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatColumn(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _buildCountDisplay extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _buildCountDisplay(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text('$count', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF424242), fontWeight: FontWeight.bold))]);
  }
}