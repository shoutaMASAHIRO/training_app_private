import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fitness_app/services/database_service.dart';
import 'package:fitness_app/models/workout_log.dart'; // Add this import

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final DatabaseService _apiService = DatabaseService();
  List<WorkoutLog> _logs = []; // Change type here
  bool _isLoading = true;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      // Short delay to allow tab transition animation to finish
      await Future.delayed(const Duration(milliseconds: 150));
      final allLogs = await _apiService.getLogs();
      
      // Progressで登録した「最重量の記録 (Max record)」を除外する
      // workoutDetailsに "Max record" という文字列が含まれているものを実績データとして扱う
      final filteredLogs = allLogs.where((log) {
        final details = log.workoutDetails ?? '';
        return !details.contains('Max record');
      }).toList();

      setState(() {
        _logs = filteredLogs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<WorkoutLog> _getLogsForDay(DateTime day) {
    // Change return type and access properties directly
    return _logs.where((log) {
      return isSameDay(log.completedDate, day);
    }).toList();
  }

  Future<void> _deleteLogsForDay(DateTime day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('${DateFormat('yyyy/MM/dd').format(day)}のログを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteLogsByDate(day);
        await _loadLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ログを削除しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e')),
          );
        }
      }
    }
  }

  Color _getMenuColor(String menuTitle) {
    return const Color(0xFF00ACC1); // Default to Cyan
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedDayLogs = _selectedDay != null ? _getLogsForDay(_selectedDay!) : [];

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar Header Section
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) => _getLogsForDay(day),
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                  weekendStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                calendarStyle: const CalendarStyle(
                  defaultTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  weekendTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  outsideTextStyle: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold),
                  todayDecoration: BoxDecoration(
                    color: Colors.white12, // さらに控えめに
                    shape: BoxShape.circle,
                  ),
                                                      todayTextStyle: TextStyle(
                                                        color: Colors.orangeAccent,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                      selectedDecoration: BoxDecoration(
                                                        color: Colors.transparent, // 塗りつぶしを透明に
                                                        shape: BoxShape.circle,
                                                        border: Border.fromBorderSide(
                                                          BorderSide(color: Colors.white, width: 2), // 太めの白い枠線に変更
                                                        ),
                                                      ),
                                                      selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                                      markerDecoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    calendarBuilders: CalendarBuilders(
                                                      selectedBuilder: (context, day, focusedDay) {
                                                        final isToday = isSameDay(day, DateTime.now());
                                                        return Center(
                                                          child: Container(
                                                            width: 32,
                                                            height: 32,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              border: Border.all(color: Colors.white, width: 2),
                                                            ),
                                                            child: Center(
                                                              child: Text(
                                                                '${day.day}',
                                                                style: TextStyle(
                                                                  color: isToday ? Colors.orangeAccent : Colors.white,
                                                                  fontWeight: FontWeight.w900,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },                      markerBuilder: (context, day, events) {
                    if (events.isEmpty) return const SizedBox.shrink();

                    // キャストしてWorkoutLogのリストとして扱う
                    final logs = events.cast<WorkoutLog>();
                    
                    // 失敗したログと成功したログを分ける
                    final failedLogs = logs.where((log) => (log.failCount ?? 0) > 0).toList();
                    final successLogs = logs.where((log) => (log.failCount ?? 0) == 0).toList();

                    // 表示用のマーカーリストを作成
                    final List<Widget> allMarkers = [];

                    // 失敗マーカーを追加
                    for (var _ in failedLogs) {
                      allMarkers.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.0),
                          child: SizedBox(
                            width: 10,
                            height: 10,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.rotate(
                                  angle: 0.785, // 45 degrees
                                  child: Container(
                                    width: 11,
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ),
                                Transform.rotate(
                                  angle: -0.785,
                                  child: Container(
                                    width: 11,
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // 成功マーカーを追加
                    for (var _ in successLogs) {
                      allMarkers.add(
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.0),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }

                    // 最大表示数を3に制限
                    const int maxDisplay = 3;
                    final displayMarkers = allMarkers.take(maxDisplay).toList();
                    final remainingCount = allMarkers.length - maxDisplay;

                    // 今日かどうかで位置を微調整 (今日だけ位置を下げる)
                    final double bottomPosition = isSameDay(day, DateTime.now()) ? -4 : 0;

                    return Positioned(
                      bottom: bottomPosition,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...displayMarkers,
                          if (remainingCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 2.0),
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+$remainingCount',
                                style: const TextStyle(
                                  color: Color(0xFF00ACC1),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 選択日のログ
            if (_selectedDay != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('yyyy/MM/dd').format(_selectedDay!),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                                          if (selectedDayLogs.isNotEmpty)
                                            TextButton.icon(
                                              onPressed: () => _deleteLogsForDay(_selectedDay!),
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                              label: const Text('すべて削除', style: TextStyle(color: Colors.red)),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                            ),                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedDayLogs.isEmpty)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(
                            child: Text(
                              'この日のログはありません',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // 失敗したログ（未達成）セクション
                      if (selectedDayLogs.any((log) => (log.failCount ?? 0) > 0)) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 16, bottom: 12),
                          child: Text(
                            '未達成',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.red),
                          ),
                        ),
                        ...selectedDayLogs.where((log) => (log.failCount ?? 0) > 0).map((log) => _buildLogCard(log, isSuccess: false)),
                      ],
                      // 成功したログ（完了）セクション
                      if (selectedDayLogs.any((log) => (log.failCount ?? 0) == 0)) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 16, bottom: 12),
                          child: Text(
                            '完了',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF00ACC1)),
                          ),
                        ),
                        ...selectedDayLogs.where((log) => (log.failCount ?? 0) == 0).map((log) => _buildLogCard(log, isSuccess: true)),
                      ],
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(WorkoutLog log, {required bool isSuccess}) {
    final menuTitle = log.menuTitle;
    final workoutDetails = log.workoutDetails;
    final successCount = log.successCount ?? 0;
    final failCount = log.failCount ?? 0;
    final totalCount = successCount + failCount;
    final accentColor = isSuccess ? const Color(0xFF00ACC1) : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 左側のアクセントバー (動的に色を変更)
              Container(
                width: 6,
                color: accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              menuTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF212121),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ワークアウト詳細
                      if (workoutDetails != null && workoutDetails.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.fitness_center, size: 18, color: accentColor), // アイコン色も合わせる
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                workoutDetails,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF424242),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // 成功/失敗カウント
                      if (totalCount > 0) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildCountChip('成功', successCount, const Color(0xFF00ACC1)),
                            _buildCountChip('失敗', failCount, Colors.red),
                            _buildCountChip('合計', totalCount, Colors.blueGrey),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 削除ボタン
              Material(
                color: Colors.red.shade50,
                child: InkWell(
                  onTap: () => _confirmDeleteLog(log),
                  child: Container(
                    width: 56,
                    alignment: Alignment.center,
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLog(WorkoutLog log) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログの削除', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('このログを削除してもよろしいですか？', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true && log.id != null) {
      try {
        await _apiService.deleteLog(log.id!);
        _loadLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ログを削除しました'), backgroundColor: Color(0xFF00ACC1)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w900, // Bolder
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900, // Bolder
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
