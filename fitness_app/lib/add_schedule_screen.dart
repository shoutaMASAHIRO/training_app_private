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
  // _workoutDetailsController is removed as we use structured data now
  final DatabaseService _dbService = DatabaseService();
  late DateTime _selectedDate;
  int _selectedIndex = 0;
  bool _isSaving = false;
  List<CustomProgram> _customPrograms = [];

  // 編集用の種目リスト
  List<Map<String, dynamic>> _editableExercises = [];

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
    ],
  };

  // 全ての種目をフラットなリストとしても保持
  static final List<String> _allExercises = _categorizedExercises.values.expand((e) => e).toList();

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
      'description': '上級者向け: 最大重量と動的重量の組み合わせ',
      'color': Color(0xFF00ACC1),
      'icon': Icons.bolt,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _fetchCustomPrograms();
    // 初期状態で1つの種目を追加しておく
    _addExercise();
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

  void _addExercise() {
    setState(() {
      _editableExercises.add({
        'name': _allExercises.first,
        'sets_count': 3,
        'sets_data': List.generate(3, (index) => {
          'weight': TextEditingController(text: '0.0'),
          'reps': TextEditingController(text: '10')
        }),
      });
    });
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(Color themeColor) {
    List<DropdownMenuItem<String>> items = [];
    _categorizedExercises.forEach((category, exercises) {
      items.add(DropdownMenuItem(
        value: category,
        enabled: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '--- $category ---',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: themeColor.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ),
      ));
      for (var exercise in exercises) {
        items.add(DropdownMenuItem(
          value: exercise,
          child: Row(
            children: [
              Image.asset(
                'image/icons/$exercise.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 20, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242), fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ));
      }
    });
    return items;
  }

  List<Widget> _buildSelectedItems() {
    List<Widget> selectedWidgets = [];
    _categorizedExercises.forEach((category, exercises) {
      selectedWidgets.add(Text(category));
      for (var exercise in exercises) {
        selectedWidgets.add(
          Row(
            children: [
              Image.asset(
                'image/icons/$exercise.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 18, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exercise,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242), fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        );
      }
    });
    return selectedWidgets;
  }

  void _removeExercise(int index) {
    setState(() {
      final ex = _editableExercises[index];
      for (var set in (ex['sets_data'] as List<Map<String, TextEditingController>>)) {
        set['weight']!.dispose();
        set['reps']!.dispose();
      }
      _editableExercises.removeAt(index);
    });
  }

  Future<void> _showExerciseSelectionModal(BuildContext context, Function(String) onSelect) async {
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
      final currentData = _editableExercises[exerciseIndex]['sets_data'] as List<Map<String, TextEditingController>>;
      if (newCount > currentData.length) {
        currentData.addAll(List.generate(newCount - currentData.length, 
          (index) => {
            'weight': TextEditingController(text: '0.0'),
            'reps': TextEditingController(text: '10')
          }));
      } else if (newCount < currentData.length) {
        for (int i = currentData.length - 1; i >= newCount; i--) {
          currentData[i]['weight']!.dispose();
          currentData[i]['reps']!.dispose();
        }
        currentData.removeRange(newCount, currentData.length);
      }
      _editableExercises[exerciseIndex]['sets_count'] = newCount;
    });
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    for (var ex in _editableExercises) {
      for (var set in (ex['sets_data'] as List<Map<String, TextEditingController>>)) {
        set['weight']!.dispose();
        set['reps']!.dispose();
      }
    }
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
      case 4:
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialIndex': 4});
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
        const SnackBar(content: Text('ワークアウト名を入力してください')),
      );
      return;
    }

    if (_editableExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目を少なくとも1つ追加してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 編集された内容からworkoutDetails文字列を構築
      StringBuffer detailsBuffer = StringBuffer();
      for (var ex in _editableExercises) {
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

      final schedule = WorkoutSchedule(
        id: 0,
        scheduledDate: _selectedDate,
        isCompleted: false,
        menuTitle: _workoutNameController.text,
        menuDifficulty: 'Custom',
        workoutDetails: detailsBuffer.toString().trim(),
        sessionTitle: null,
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

  Widget _buildEditableExerciseCard(int index, Color themeColor) {
    final ex = _editableExercises[index];
    final sets = ex['sets_data'] as List<Map<String, TextEditingController>>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
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
                              suffixIcon: Icon(Icons.unfold_more_rounded, color: themeColor, size: 20),
                            ),
                            child: Row(
                              children: [
                                Image.asset(
                                  'image/icons/${ex['name']}.png',
                                  width: 20,
                                  height: 20,
                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 18, color: Colors.grey.shade400),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ex['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242), fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text('セット数', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121))),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => _updateSetsCount(index, ex['sets_count'] - 1),
                                  icon: const Icon(Icons.remove_rounded, size: 20),
                                  color: Colors.grey.shade600,
                                ),
                                Text(
                                  '${ex['sets_count']}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF212121)),
                                ),
                                IconButton(
                                  onPressed: () => _updateSetsCount(index, ex['sets_count'] + 1),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  color: themeColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text('SET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242), letterSpacing: 1))),
                            Expanded(flex: 3, child: Text('WEIGHT (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242), letterSpacing: 1))),
                            SizedBox(width: 16),
                            Expanded(flex: 3, child: Text('REPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF424242), letterSpacing: 1))),
                          ],
                        ),
                      ),
                      ...List.generate(sets.length, (setIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '#${setIndex + 1}',
                                  style: TextStyle(fontWeight: FontWeight.w900, color: themeColor),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: sets[setIndex]['weight'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121)),
                                  decoration: InputDecoration(
                                    hintText: '0.0',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: themeColor, width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: sets[setIndex]['reps'],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF212121)),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: themeColor, width: 1.5),
                                    ),
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
              // 削除ボタン
              Material(
                color: Colors.red.shade50,
                child: InkWell(
                  onTap: () => _removeExercise(index),
                  child: Container(
                    width: 50,
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

            // 単発ワークアウト追加セクション
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  'または単発ワークアウトを追加',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF00ACC1).withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _workoutNameController,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF212121), fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'ワークアウト名 (タイトル)',
                      labelStyle: const TextStyle(color: Color(0xFF00ACC1), fontWeight: FontWeight.w900, fontSize: 13),
                      hintText: '例: 胸トレ、自由メニューなど',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 詳細入力エリア (種目ごとのカード)
                  if (_editableExercises.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          '下のボタンから種目を追加してください',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_editableExercises.length, (index) => _buildEditableExerciseCard(index, const Color(0xFF00ACC1))),

                  const SizedBox(height: 8),

                  // 種目の追加ボタン (カードの下部に埋め込み)
                  InkWell(
                    onTap: _addExercise,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.1)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 20, color: Color(0xFF00ACC1)),
                          const SizedBox(width: 10),
                          Text(
                            'さらに種目を追加する',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00ACC1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF424242), // 保存ボタンは少し落ち着いた色に
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
                              'スケジュールを保存',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
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
