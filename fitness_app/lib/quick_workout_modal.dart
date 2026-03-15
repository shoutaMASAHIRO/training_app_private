import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_log.dart';

class QuickWorkoutModal extends StatefulWidget {
  const QuickWorkoutModal({super.key});

  @override
  State<QuickWorkoutModal> createState() => _QuickWorkoutModalState();
}

class _QuickWorkoutModalState extends State<QuickWorkoutModal> {
  // Phase 0: Selection, 1: Tracking
  int _phase = 0;

  // Selection Data
  String _selectedExercise = 'バーベルベンチプレス'; // 初期値
  final List<Map<String, TextEditingController>> _setsData = [];
  final DatabaseService _dbService = DatabaseService();

  // Tracking Data
  List<bool?> _setStatuses = [];
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsedTime = '00:00.00';

  // Exercises List (Categorized)
  static const Map<String, List<String>> _categorizedExercises = {
    '脚（前）': ['バックスクワット', 'フロントスクワット', 'ボックススクワット', 'スミススクワット', 'ゴブレッドスクワット', 'ブルガリアンスクワット', 'ハックスクワット', 'レッグプレス', 'レッグエクステンション'],
    '脚（後）': ['コンベンショナルデッドリフト', 'スモウデッドリフト', 'ルーマニアンデッドリフト', 'スティフレッグデッドリフト', 'グッドモーニング', 'ヒップスラスト', 'レッグカール'],
    'ふくらはぎ': ['カーフレイズ', 'シーテッドカーフレイズ', 'ドンキーカーフレイズ'],
    '胸': ['バーベルベンチプレス', 'ナローバーベルベンチプレス', 'インクラインベンチプレス', 'ダンベルプレス', 'インクラインダンベルプレス', 'ディップス', 'ペックフライ', 'インクラインダンベルフライ', 'ケーブルフライ', 'ダンベルプルオーバー'],
    '背中': ['ラットプルダウン', 'プルアップ', 'インバーテッドロー', 'Tバーロー', 'ワンハンドロー'],
    '肩': ['バーベルショルダープレス', 'ダンベルショルダープレス', 'サイドレイズ', 'フロントレイズ'],
    '二頭筋': ['バーベルカール', 'ダンベルカール', 'プリーチャーカール', 'ケーブルカール'],
    '三頭筋': ['JMプレス', 'バーベルエクステンション', 'ケーブルエクステンション', 'ケーブルプレスダウン', 'キックバック'],
    '前腕': ['バーベルリストカール', 'ダンベルリストカール', 'ケーブルリストカール', '握力'],
  };

  @override
  void initState() {
    super.initState();
    _loadLastExercise();
    _addSet(); // Default 1 set
    _addSet();
    _addSet(); // Default 3 sets
  }

  Future<void> _loadLastExercise() async {
    final lastEx = await _dbService.getSetting('last_quick_exercise');
    if (lastEx != null && mounted) {
      setState(() {
        _selectedExercise = lastEx;
      });
    }
  }

  @override
  void dispose() {
    for (var set in _setsData) {
      set['weight']?.dispose();
      set['reps']?.dispose();
    }
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _addSet() {
    setState(() {
      _setsData.add({
        'weight': TextEditingController(text: _setsData.isNotEmpty ? _setsData.last['weight']!.text : '60'),
        'reps': TextEditingController(text: _setsData.isNotEmpty ? _setsData.last['reps']!.text : '10'),
      });
    });
  }

  void _removeSet(int index) {
    if (_setsData.length <= 1) return;
    setState(() {
      _setsData[index]['weight']?.dispose();
      _setsData[index]['reps']?.dispose();
      _setsData.removeAt(index);
    });
  }

  void _startWorkout() {
    setState(() {
      _phase = 1;
      _setStatuses = List.filled(_setsData.length, null);
    });
  }

  // --- Timer Logic ---
  void _startStopwatch() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _elapsedTime = _formatTime(_stopwatch.elapsed);
        });
      }
    });
  }

  void _stopStopwatch() {
    _stopwatch.stop();
    _timer?.cancel();
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

  // --- Completion Logic ---
  Future<void> _finishWorkout() async {
    final successCount = _setStatuses.where((s) => s == true).length;
    final totalSets = _setStatuses.length;
    // 成功したセット以外（失敗 + 未完了）をすべて失敗数としてカウントし、
    // 1つでも未達成があればログ画面で「未達成」に分類されるようにする
    final failCount = totalSets - successCount;
    
    // Construct detail string
    StringBuffer details = StringBuffer();
    for (int i = 0; i < _setsData.length; i++) {
      final weight = _setsData[i]['weight']!.text;
      final reps = _setsData[i]['reps']!.text;
      if (details.isNotEmpty) details.write('\n');
      details.write('$_selectedExercise: $reps reps @ ${weight}kg');
    }

    try {
      final log = WorkoutLog(
        completedDate: DateTime.now(),
        menuTitle: 'Quick Workout',
        sessionTitle: _selectedExercise,
        workoutDetails: details.toString(),
        successCount: successCount,
        failCount: failCount,
      );
      await _dbService.addLog(log);
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ワークアウトを記録しました！'), backgroundColor: Color(0xFF00ACC1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Spacer for centering title
                Text(
                  _phase == 0 ? 'クイックワークアウト設定' : 'ワークアウト中',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF424242)),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF424242), size: 20),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          Flexible(
            child: _phase == 0 ? _buildSelectionPhase() : _buildTrackingPhase(),
          ),
        ],
      ),
    );
  }

  Future<void> _showExerciseSelectionModal(BuildContext context, Function(String) onSelect) async {
    FocusScope.of(context).unfocus();
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48), // Spacer
                      const Text(
                        '種目を選択',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Color(0xFF424242),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF424242), size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 30),
                    children: _categorizedExercises.entries.map((entry) {
                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          maintainState: false,
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
                                  cacheWidth: 150,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center, size: 48, color: Colors.grey),
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
    );
  }

  Widget _buildSelectionPhase() {
    const themeColor = Color(0xFF00ACC1);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Exercise Selector
        const Text('種目を選択', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 16),
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
                  _selectedExercise = selected;
                });
                _dbService.saveSetting('last_quick_exercise', selected);
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: InputDecorator(
              decoration: InputDecoration(
                hintText: '種目を選択してください',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
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
                  borderSide: const BorderSide(color: themeColor, width: 2),
                ),
              ),
              child: _selectedExercise.isNotEmpty
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
                                'image/icons/$_selectedExercise.png',
                                fit: BoxFit.cover,
                                cacheWidth: 352,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 72, color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: themeColor,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
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
                                _selectedExercise,
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF212121), fontSize: 18),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.touch_app_rounded, color: themeColor, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'タップして種目を変更',
                        style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                    ],
                  )
                : const Text('種目を選択してください'),
            ),
          ),
        ),
        // Sets Configuration
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'セット数',
                style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF424242), fontSize: 16),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_setsData.length > 1) {
                        _removeSet(_setsData.length - 1);
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        '${_setsData.length}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF212121)),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _addSet,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                    color: const Color(0xFF00ACC1),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Header for sets list
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 50, child: Text('セット', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
              Expanded(child: Text('重量 (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
              SizedBox(width: 12),
              Expanded(child: Text('回数 (reps)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
            ],
          ),
        ),

        ..._setsData.asMap().entries.map((entry) {
          final index = entry.key;
          final set = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00ACC1), fontSize: 16),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: set['weight'],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: set['reps'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _startWorkout,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00ACC1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('トレーニング開始', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTrackingPhase() {
    return Column(
      children: [
        // Timer
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              const Text('レストタイマー', style: TextStyle(fontSize: 14, color: Color(0xFF424242), fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_elapsedTime, style: const TextStyle(fontSize: 48, fontFamily: 'monospace', fontWeight: FontWeight.w300, color: Color(0xFF424242))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _stopwatch.isRunning ? _stopStopwatch : _startStopwatch,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _stopwatch.isRunning ? Colors.orange.shade700 : const Color(0xFF00ACC1),
                      side: BorderSide(color: _stopwatch.isRunning ? Colors.orange.shade700 : const Color(0xFF00ACC1)),
                    ),
                    child: Text(_stopwatch.isRunning ? 'ストップ' : 'スタート'),
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

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _setsData.length,
            itemBuilder: (context, index) {
              final status = _setStatuses[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedExercise,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00ACC1),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Set ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${_setsData[index]['weight']!.text}kg x ${_setsData[index]['reps']!.text} reps',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF212121)),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            const Text(
                              '成功',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF00ACC1)),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                              icon: Icon(
                                status == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: status == true ? const Color(0xFF00ACC1) : Colors.grey.shade300,
                                size: 28,
                              ),
                              onPressed: () => setState(() => _setStatuses[index] = status == true ? null : true),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            const Text(
                              '失敗',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.red),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                              icon: Icon(
                                status == false ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded,
                                color: status == false ? Colors.red : Colors.grey.shade300,
                                size: 28,
                              ),
                              onPressed: () => setState(() => _setStatuses[index] = status == false ? null : false),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finishWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ACC1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('完了して記録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}
