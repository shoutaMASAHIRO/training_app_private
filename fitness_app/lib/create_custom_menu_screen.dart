import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/custom_program.dart';
import 'package:fitness_app/home_screen.dart';

class CreateCustomMenuScreen extends StatefulWidget {
  const CreateCustomMenuScreen({super.key});

  @override
  State<CreateCustomMenuScreen> createState() => _CreateCustomMenuScreenState();
}

class _CreateCustomMenuScreenState extends State<CreateCustomMenuScreen> {
  final TextEditingController _menuNameController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  
  bool _isSaving = false;
  int _selectedIndex = 1;

  // 候補となる種目リスト
  static const List<String> _exerciseOptions = [
    'Benchpress',
    'Squat',
    'Weighted Pullup',
    'Bulgarian Split Squat',
  ];

  // 作成中の種目リスト
  final List<Map<String, dynamic>> _exercises = [];

  @override
  void initState() {
    super.initState();
    // 初期状態で1つ種目を追加しておく
    _addExercise();
  }

  void _addExercise() {
    setState(() {
      _exercises.add({
        'name': _exerciseOptions.first,
        'sets_count': 3,
        'sets_data': List.generate(3, (index) => {'weight': TextEditingController(), 'reps': TextEditingController()}),
      });
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _updateSetsCount(int exerciseIndex, int newCount) {
    if (newCount < 1) return;
    setState(() {
      final currentData = _exercises[exerciseIndex]['sets_data'] as List<Map<String, TextEditingController>>;
      if (newCount > currentData.length) {
        // 増やす
        currentData.addAll(List.generate(newCount - currentData.length, 
          (index) => {'weight': TextEditingController(), 'reps': TextEditingController()}));
      } else if (newCount < currentData.length) {
        // 減らす
        for (int i = currentData.length - 1; i >= newCount; i--) {
          currentData[i]['weight']!.dispose();
          currentData[i]['reps']!.dispose();
        }
        currentData.removeRange(newCount, currentData.length);
      }
      _exercises[exerciseIndex]['sets_count'] = newCount;
    });
  }

  @override
  void dispose() {
    _menuNameController.dispose();
    for (var ex in _exercises) {
      for (var set in (ex['sets_data'] as List<Map<String, TextEditingController>>)) {
        set['weight']!.dispose();
        set['reps']!.dispose();
      }
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': index});
  }

  Color _getThemeColor() {
    return const Color(0xFF00ACC1); // Cyan
  }

  Future<void> _saveMenu() async {
    if (_menuNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メニュー名を入力してください')),
      );
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目を少なくとも1つ追加してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 詳細内容を文字列として構築
      StringBuffer detailsBuffer = StringBuffer();
      for (var ex in _exercises) {
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

      final program = CustomProgram(
        name: _menuNameController.text,
        description: 'カスタムプログラム',
        details: detailsBuffer.toString().trim(),
      );

      await _dbService.addCustomProgram(program);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('カスタムプログラムを作成しました'),
            backgroundColor: const Color(0xFF00ACC1),
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
    final themeColor = _getThemeColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('カスタムメニュー作成'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー説明カード
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
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'オリジナルプログラムの作成',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '種目とセットごとの詳細を設定します。',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // メニュー名入力
            const Text('プログラム名', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242))),
            const SizedBox(height: 8),
            TextField(
              controller: _menuNameController,
              decoration: InputDecoration(
                hintText: '例: 胸トレ、週明けルーチン',
                filled: true,
                fillColor: Colors.grey[100],
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: themeColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 種目リスト
            const Text('トレーニング内容', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242))),
            const SizedBox(height: 12),
            ...List.generate(_exercises.length, (index) => _buildExerciseCard(index, themeColor)),

            // 種目追加ボタン
            OutlinedButton.icon(
              onPressed: _addExercise,
              icon: Icon(Icons.add, color: themeColor),
              label: Text('種目を追加', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: themeColor),
              ),
            ),
            const SizedBox(height: 40),

            // 保存ボタン
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMenu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('プログラムを保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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

  Widget _buildExerciseCard(int index, Color themeColor) {
    final ex = _exercises[index];
    final sets = ex['sets_data'] as List<Map<String, TextEditingController>>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                        child: DropdownButtonFormField<String>(
                          value: ex['name'],
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
                          items: _exerciseOptions.map((e) => DropdownMenuItem(
                            value: e, 
                            child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242))),
                          )).toList(),
                          onChanged: (val) => setState(() => ex['name'] = val),
                          icon: Icon(Icons.unfold_more_rounded, color: themeColor, size: 20),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('セット数:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242))),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _updateSetsCount(index, ex['sets_count'] - 1),
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.grey.shade600,
                          ),
                          Text('${ex['sets_count']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF212121))), // Increased
                          IconButton(
                            onPressed: () => _updateSetsCount(index, ex['sets_count'] + 1),
                            icon: const Icon(Icons.add_circle_outline),
                            color: themeColor,
                          ),
                        ],
                      ),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text('セット', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242)))), // Darker/Bolder
                            Expanded(flex: 3, child: Text('重量 (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242)))), // Darker/Bolder
                            SizedBox(width: 16),
                            Expanded(flex: 3, child: Text('回数 (reps)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242)))), // Darker/Bolder
                          ],
                        ),
                      ),
                      ...List.generate(sets.length, (setIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text('#${setIndex + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF424242)))), // Darker
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: sets[setIndex]['weight'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121)), // Increased
                                  decoration: InputDecoration(
                                    hintText: '0.0',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: themeColor),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16), // Fixed spacing to match other screens if needed, but keeping 16 as per prev attempt
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: sets[setIndex]['reps'],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121)), // Increased
                                  decoration: InputDecoration(
                                    hintText: '10',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: themeColor),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
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
                    width: 56,
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
}
