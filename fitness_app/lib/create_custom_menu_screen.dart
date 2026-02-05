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
    return Colors.black87;
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'オリジナルプログラムの作成',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            const Text('プログラム名', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _menuNameController,
              decoration: InputDecoration(
                hintText: '例: 胸トレ、週明けルーチン',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 種目リスト
            const Text('トレーニング内容', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(_exercises.length, (index) => _buildExerciseCard(index, themeColor)),

            // 種目追加ボタン
            OutlinedButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: const Text('種目を追加'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),

            // 保存ボタン
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMenu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('プログラムを保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: ex['name'],
                    decoration: const InputDecoration(
                      labelText: '種目',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _exerciseOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => ex['name'] = val),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeExercise(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('セット数:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _updateSetsCount(index, ex['sets_count'] - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${ex['sets_count']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => _updateSetsCount(index, ex['sets_count'] + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text('セット', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  Expanded(flex: 3, child: Text('重量 (kg)', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  SizedBox(width: 16),
                  Expanded(flex: 3, child: Text('回数 (reps)', style: TextStyle(fontSize: 12, color: Colors.grey))),
                ],
              ),
            ),
            ...List.generate(sets.length, (setIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Text('#${setIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: sets[setIndex]['weight'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: '0.0',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: sets[setIndex]['reps'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '10',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    );
  }
}
