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
      final logs = await _apiService.getLogs(); // Returns List<WorkoutLog>
      setState(() {
        _logs = logs;
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
    switch (menuTitle) {
      case 'Smolov Jr.':
        return Colors.red;
      case '10x10':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カレンダー
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
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
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: Colors.grey.shade700),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Colors.grey.shade700),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(color: Colors.black87),
                    markerDecoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    markerSize: 6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 選択日のログ
            if (_selectedDay != null) ...[
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
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('削除'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                ],
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
              else
                ...selectedDayLogs.map((log) => _buildLogCard(log)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(WorkoutLog log) {
    final menuTitle = log.menuTitle;
    final workoutDetails = log.workoutDetails;
    final successCount = log.successCount ?? 0;
    final failCount = log.failCount ?? 0;
    final totalCount = successCount + failCount;
    final menuColor = _getMenuColor(menuTitle);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // メニュー名バッジ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: menuColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                menuTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            // ワークアウト詳細
            if (workoutDetails != null && workoutDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.fitness_center, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    workoutDetails,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            // 成功/失敗カウント
            if (totalCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildCountChip('成功', successCount, Colors.green.shade700),
                  const SizedBox(width: 8),
                  _buildCountChip('失敗', failCount, Colors.red.shade700),
                  const SizedBox(width: 8),
                  _buildCountChip('合計', totalCount, Colors.blueGrey),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
