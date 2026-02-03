import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/models/workout_log.dart'; // Add this import

import 'package:fitness_app/services/api_config.dart';

class ApiService {
  final String _baseUrl = apiBaseUrl;

  Future<List<WorkoutSchedule>> getSchedules() async {
    debugPrint('[API] GET $_baseUrl/schedules');
    final response = await http.get(Uri.parse('$_baseUrl/schedules'));
    debugPrint('[API] Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<WorkoutSchedule> schedules =
          body.map((dynamic item) => WorkoutSchedule.fromJson(item)).toList();
      debugPrint('[API] Loaded ${schedules.length} schedules');
      return schedules;
    } else {
      debugPrint('[API] Error body: ${response.body}');
      throw Exception('Failed to load schedules: ${response.statusCode}');
    }
  }

  Future<void> completeSchedule(int id) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/schedules/$id/complete'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to complete schedule');
    }
  }

  Future<void> deleteSchedule(int id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/schedules/$id'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete schedule');
    }
  }

  // スケジュールを追加
  Future<WorkoutSchedule> addSchedule(WorkoutSchedule schedule) async {
    final url = '$_baseUrl/schedules';
    final body = jsonEncode(schedule.toJson());
    debugPrint('[API] POST $url');
    debugPrint('[API] Request body: $body');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    debugPrint('[API] Response status: ${response.statusCode}');
    debugPrint('[API] Response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return WorkoutSchedule.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add schedule: ${response.statusCode} - ${response.body}');
    }
  }

  // 複数スケジュールを一括追加
  Future<void> addSchedules(List<WorkoutSchedule> schedules) async {
    debugPrint('[API] Adding ${schedules.length} schedules...');
    for (int i = 0; i < schedules.length; i++) {
      debugPrint('[API] Adding schedule ${i + 1}/${schedules.length}');
      await addSchedule(schedules[i]);
    }
    debugPrint('[API] All schedules added');
  }

  // 特定メニューのスケジュールを一括削除
  Future<void> deleteSchedulesByMenuTitle(String menuTitle) async {
    debugPrint('[API] Deleting schedules with menuTitle: $menuTitle');
    final schedules = await getSchedules();
    final targetSchedules = schedules.where((s) => s.menuTitle == menuTitle).toList();
    debugPrint('[API] Found ${targetSchedules.length} schedules to delete');

    for (final schedule in targetSchedules) {
      debugPrint('[API] Deleting schedule id: ${schedule.id}');
      await deleteSchedule(schedule.id);
    }
    debugPrint('[API] Deletion complete');
  }

  // --- Workout Logs API ---

  // ログ一覧取得
  Future<List<WorkoutLog>> getLogs() async {
    final response = await http.get(Uri.parse('$_baseUrl/logs'));
    debugPrint('[API] GET $_baseUrl/logs');
    debugPrint('[API] Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<WorkoutLog> logs =
          body.map((dynamic item) => WorkoutLog.fromJson(item)).toList();
      debugPrint('[API] Loaded ${logs.length} logs');
      return logs;
    } else {
      debugPrint('[API] Error body: ${response.body}');
      throw Exception('Failed to load logs: ${response.statusCode}');
    }
  }

  // ログ追加
  Future<void> addLog(WorkoutLog log) async {
    final url = '$_baseUrl/logs';
    final body = jsonEncode(log.toJson());
    debugPrint('[API] POST $url');
    debugPrint('[API] Request body: $body');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    debugPrint('[API] Response status: ${response.statusCode}');
    debugPrint('[API] Response body: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add log: ${response.statusCode} - ${response.body}');
    }
  }

  // 特定ログ削除
  Future<void> deleteLog(int id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/logs/$id'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete log');
    }
  }

  // 特定日のログ全削除
  Future<void> deleteLogsByDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final response = await http.delete(Uri.parse('$_baseUrl/logs/by-date/$dateStr'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete logs');
    }
  }
}
