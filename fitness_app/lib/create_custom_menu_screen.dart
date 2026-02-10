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

  // 候補となる種目リスト（カテゴリ別）
  static const Map<String, List<String>> _categorizedExercises = {
    '脚（前）': [
      'バックスクワット',
      'フロントスクワット',
      'ボックススクワット',
      'スミススクワット',
      'ゴブレッドスクワット',
      'ブルガリアンスクワット',
      'ハックスクワット',
      'レッグプレス',
      'レッグエクステンション',
    ],
    '脚（後）': [
      'コンベンショナルデッドリフト',
      'スモウデッドリフト',
      'ルーマニアンデッドリフト',
      'スティフレッグデッドリフト',
      'グッドモーニング',
      'ヒップスラスト',
      'レッグカール',
    ],
    'ふくらはぎ': [
      'カーフレイズ',
      'シーテッドカーフレイズ',
      'ドンキーカーフレイズ',
    ],
    '胸': [
      'バーベルベンチプレス',
      'ナローバーベルベンチプレス',
      'インクラインベンチプレス',
      'ダンベルプレス',
      'インクラインダンベルプレス',
      'ディップス',
      'ペックフライ',
      'インクラインダンベルフライ',
      'ケーブルフライ',
      'ダンベルプルオーバー',
    ],
    '背中': [
      'ラットプルダウン',
      'プルアップ',
      'インバーテッドロー',
      'Tバーロー',
      'ワンハンドロー',
    ],
    '肩': [
      'バーベルショルダープレス',
      'ダンベルショルダープレス',
      'サイドレイズ',
      'フロントレイズ',
    ],
    '二頭筋': [
      'バーベルカール',
      'ダンベルカール',
      'プリーチャーカール',
      'ケーブルカール',
    ],
    '三頭筋': [
      'JMプレス',
      'バーベルエクステンション',
      'ケーブルエクステンション',
      'ケーブルプレスダウン',
      'キックバック',
    ],
    '前腕': [
      'バーベルリストカール',
      'ダンベルリストカール',
      'ケーブルリストカール',
      '握力',
    ],
  };

  // 全ての種目をフラットなリストとしても保持（初期値用など）
  static final List<String> _allExercises = _categorizedExercises.values.expand((e) => e).toList();

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
        'name': _allExercises.first,
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

  Future<void> _showExerciseSelectionModal(BuildContext context, Function(String) onSelect) async {
    // キーボードを閉じる
    FocusScope.of(context).unfocus();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return GestureDetector(
                onTap: () {}, // コンテンツ内タップで閉じないようにする
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          '種目を選択',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.grey[800]
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 30),
                                                    children: _categorizedExercises.entries.map((entry) {
                                                      return Theme(
                                                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                        child: ExpansionTile(
                                                          maintainState: false, // 軽量化
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
                                                                  cacheWidth: 150, // 192 -> 150
                                                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade400),
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
          ),
        );
      },
    );
  }

  void _updateSetsCount(int exerciseIndex, int newCount) {
    if (newCount < 1) return;
    setState(() {
      final currentData = _exercises[exerciseIndex]['sets_data'] as List<Map<String, TextEditingController>>;
      if (newCount > currentData.length) {
        // 増やす際に、最後のセットの内容を継承する
        for (int i = currentData.length; i < newCount; i++) {
          final lastWeight = currentData.isNotEmpty ? currentData.last['weight']!.text : '';
          final lastReps = currentData.isNotEmpty ? currentData.last['reps']!.text : '';
          currentData.add({
            'weight': TextEditingController(text: lastWeight),
            'reps': TextEditingController(text: lastReps),
          });
        }
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
              height: 64, // 56から64に増加
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMenu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24), // パディングを追加
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('プログラムを保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
                        child: InkWell(
                          onTap: () {
                            _showExerciseSelectionModal(context, (selected) {
                              setState(() {
                                ex['name'] = selected;
                              });
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
                                borderSide: BorderSide(color: themeColor, width: 2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'image/icons/${ex['name']}.png',
                                          fit: BoxFit.cover,
                                          cacheWidth: 240,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: themeColor,
                                        shape: BoxShape.circle,
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                      ),
                                      child: const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
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
                                          ex['name'],
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF212121), fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.touch_app_rounded, color: themeColor, size: 16),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'タップして種目を変更',
                                  style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
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
