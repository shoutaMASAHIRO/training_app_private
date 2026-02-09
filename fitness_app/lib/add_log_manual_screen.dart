import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_log.dart';
import 'package:fitness_app/home_screen.dart';

class AddManualLogScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final String? exerciseName;

  const AddManualLogScreen({super.key, this.selectedDate, this.exerciseName});

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
  int _selectedIndex = 3; // Progress tab (Updated index)

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

  // 全ての種目をフラットなリストとしても保持
  static final List<String> _allExercises = _categorizedExercises.values.expand((e) => e).toList();

  Color _getExerciseColor(String? exercise) {
    return const Color(0xFF00ACC1); // Default to Cyan
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

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    if (widget.exerciseName != null) {
      _exerciseNameController.text = widget.exerciseName!;
    }
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    _weightController.dispose();
    _maxRepsWeightController.dispose();
    _maxRepsCountController.dispose();
    super.dispose();
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '実績の記録',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '日付',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _selectDate,
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
            const SizedBox(height: 12),

            // 種目選択カード
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fitness_center, color: themeColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '種目名',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          _showExerciseSelectionModal(context, (selected) {
                            setState(() {
                              _exerciseNameController.text = selected;
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
                              borderSide: BorderSide(color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: const Color(0xFF00ACC1).withValues(alpha: 0.2), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 2),
                            ),
                          ),
                          child: _exerciseNameController.text.isNotEmpty 
                            ? Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00ACC1).withValues(alpha: 0.05),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.1), width: 2),
                                        ),
                                        child: Image.asset(
                                          'image/icons/${_exerciseNameController.text}.png',
                                          width: 144,
                                          height: 144,
                                          fit: BoxFit.contain,
                                          cacheWidth: 288,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, size: 72, color: Colors.grey.shade400),
                                        ),
                                      ),
                                      // タッチできることを示すオーバーレイアイコン
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF00ACC1),
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
                                                                              _exerciseNameController.text,
                                                                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF212121), fontSize: 18),
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                          ),
                                                                          const SizedBox(width: 8),
                                                                          const Icon(Icons.touch_app_rounded, color: Color(0xFF00ACC1), size: 18),
                                                                        ],
                                                                      ),                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'タップして種目を変更',
                                    style: TextStyle(color: Color(0xFF00ACC1), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                            : Text(
                                '種目を選択してください',
                                style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 16),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 重量・REP入力カード
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monitor_weight_outlined, color: themeColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '達成重量 or 最大rep (どちらか記入)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                      decoration: InputDecoration(
                        hintText: '0.0',
                        suffixText: 'kg',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: themeColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                            decoration: InputDecoration(
                              hintText: '重量',
                              suffixText: 'kg',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: themeColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('x', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxRepsCountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                            decoration: InputDecoration(
                              hintText: '回数',
                              suffixText: 'reps',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: themeColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
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
              height: 72, // さらに高さを増やして十分なゆとりを持たせる
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1), // Cyan
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), // パディングをさらに拡大
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                          Icon(Icons.check_circle_outline, size: 24),
                          SizedBox(width: 16), // アイコンと文字の間隔をさらに広げる
                          Text(
                            '実績を保存',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2), // 太さと文字間隔を調整
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
