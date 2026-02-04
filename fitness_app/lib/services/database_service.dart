import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/models/workout_log.dart';
import 'package:fitness_app/services/database_helper.dart';

class DatabaseService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ==================== ユーザー認証 ====================

  /// パスワードをSHA-256でハッシュ化
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// ユーザー登録
  Future<bool> register(String username, String password) async {
    try {
      final db = await _dbHelper.database;
      final passwordHash = _hashPassword(password);

      await db.insert(
        DatabaseHelper.tableUsers,
        {
          DatabaseHelper.colUsername: username,
          DatabaseHelper.colPasswordHash: passwordHash,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      debugPrint('[DB] User registered: $username');
      return true;
    } catch (e) {
      debugPrint('[DB] Registration failed: $e');
      return false;
    }
  }

  /// ログイン認証
  Future<bool> login(String username, String password) async {
    try {
      final db = await _dbHelper.database;
      final passwordHash = _hashPassword(password);

      final List<Map<String, dynamic>> result = await db.query(
        DatabaseHelper.tableUsers,
        where: '${DatabaseHelper.colUsername} = ? AND ${DatabaseHelper.colPasswordHash} = ?',
        whereArgs: [username, passwordHash],
      );

      final success = result.isNotEmpty;
      debugPrint('[DB] Login ${success ? "successful" : "failed"} for: $username');
      return success;
    } catch (e) {
      debugPrint('[DB] Login error: $e');
      return false;
    }
  }

  /// ユーザー名の存在確認
  Future<bool> usernameExists(String username) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> result = await db.query(
        DatabaseHelper.tableUsers,
        where: '${DatabaseHelper.colUsername} = ?',
        whereArgs: [username],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('[DB] Username check error: $e');
      return false;
    }
  }

  // ==================== スケジュール ====================

  /// スケジュール全件取得
  Future<List<WorkoutSchedule>> getSchedules() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableSchedules,
        orderBy: '${DatabaseHelper.colScheduledDate} ASC',
      );

      final schedules = maps.map((map) => WorkoutSchedule.fromMap(map)).toList();
      debugPrint('[DB] Loaded ${schedules.length} schedules');
      return schedules;
    } catch (e) {
      debugPrint('[DB] Error loading schedules: $e');
      throw Exception('Failed to load schedules: $e');
    }
  }

  /// スケジュール追加（IDは自動生成）
  Future<WorkoutSchedule> addSchedule(WorkoutSchedule schedule) async {
    try {
      final db = await _dbHelper.database;
      final map = schedule.toMap();
      map.remove('id'); // IDは自動生成

      final id = await db.insert(
        DatabaseHelper.tableSchedules,
        map,
      );

      debugPrint('[DB] Schedule added with id: $id');

      // 挿入したレコードを取得して返す
      return WorkoutSchedule(
        id: id,
        scheduledDate: schedule.scheduledDate,
        isCompleted: schedule.isCompleted,
        menuTitle: schedule.menuTitle,
        menuDifficulty: schedule.menuDifficulty,
        workoutDetails: schedule.workoutDetails,
      );
    } catch (e) {
      debugPrint('[DB] Error adding schedule: $e');
      throw Exception('Failed to add schedule: $e');
    }
  }

  /// 複数スケジュールを一括追加
  Future<void> addSchedules(List<WorkoutSchedule> schedules) async {
    final db = await _dbHelper.database;
    debugPrint('[DB] Adding ${schedules.length} schedules...');

    await db.transaction((txn) async {
      for (final schedule in schedules) {
        final map = schedule.toMap();
        map.remove('id');
        await txn.insert(DatabaseHelper.tableSchedules, map);
      }
    });

    debugPrint('[DB] All schedules added');
  }

  /// スケジュール完了
  Future<void> completeSchedule(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        DatabaseHelper.tableSchedules,
        {DatabaseHelper.colIsCompleted: 1},
        where: '${DatabaseHelper.colScheduleId} = ?',
        whereArgs: [id],
      );
      debugPrint('[DB] Schedule $id marked as completed');
    } catch (e) {
      debugPrint('[DB] Error completing schedule: $e');
      throw Exception('Failed to complete schedule: $e');
    }
  }

  /// スケジュール削除
  Future<void> deleteSchedule(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        DatabaseHelper.tableSchedules,
        where: '${DatabaseHelper.colScheduleId} = ?',
        whereArgs: [id],
      );
      debugPrint('[DB] Schedule $id deleted');
    } catch (e) {
      debugPrint('[DB] Error deleting schedule: $e');
      throw Exception('Failed to delete schedule: $e');
    }
  }

  /// 特定メニューのスケジュールを一括削除
  Future<void> deleteSchedulesByMenuTitle(String menuTitle) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        DatabaseHelper.tableSchedules,
        where: '${DatabaseHelper.colMenuTitle} = ?',
        whereArgs: [menuTitle],
      );
      debugPrint('[DB] Deleted $count schedules with menuTitle: $menuTitle');
    } catch (e) {
      debugPrint('[DB] Error deleting schedules: $e');
      throw Exception('Failed to delete schedules: $e');
    }
  }

  /// 全スケジュールを削除
  Future<void> deleteAllSchedules() async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        DatabaseHelper.tableSchedules,
      );
      debugPrint('[DB] Deleted $count all schedules');
    } catch (e) {
      debugPrint('[DB] Error deleting all schedules: $e');
      throw Exception('Failed to delete all schedules: $e');
    }
  }

  /// 特定メニュー名とセッションタイトルに合致するスケジュールを一括削除
  Future<void> deleteSchedulesByMenuTitleAndSessionTitle(String menuTitle, String? sessionTitle) async {
    try {
      final db = await _dbHelper.database;
      int count;
      if (sessionTitle != null && sessionTitle.isNotEmpty) {
        count = await db.delete(
          DatabaseHelper.tableSchedules,
          where: '${DatabaseHelper.colMenuTitle} = ? AND ${DatabaseHelper.colSessionTitle} = ?',
          whereArgs: [menuTitle, sessionTitle],
        );
      } else {
        // sessionTitle がない場合は menuTitle のみで削除（以前の挙動に戻す）
        count = await db.delete(
          DatabaseHelper.tableSchedules,
          where: '${DatabaseHelper.colMenuTitle} = ? AND ${DatabaseHelper.colSessionTitle} IS NULL',
          whereArgs: [menuTitle],
        );
      }
      debugPrint('[DB] Deleted $count schedules with menuTitle: $menuTitle and sessionTitle: $sessionTitle');
    } catch (e) {
      debugPrint('[DB] Error deleting schedules: $e');
      throw Exception('Failed to delete schedules: $e');
    }
  }

  // ==================== ワークアウトログ ====================

  /// ログ一覧取得
  Future<List<WorkoutLog>> getLogs() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableLogs,
        orderBy: '${DatabaseHelper.colCompletedDate} DESC',
      );

      final logs = maps.map((map) => WorkoutLog.fromMap(map)).toList();
      debugPrint('[DB] Loaded ${logs.length} logs');
      return logs;
    } catch (e) {
      debugPrint('[DB] Error loading logs: $e');
      throw Exception('Failed to load logs: $e');
    }
  }

  /// ログ追加
  Future<void> addLog(WorkoutLog log) async {
    try {
      final db = await _dbHelper.database;
      final map = log.toMap();
      map.remove('id'); // IDは自動生成

      final id = await db.insert(DatabaseHelper.tableLogs, map);
      debugPrint('[DB] Log added with id: $id');
    } catch (e) {
      debugPrint('[DB] Error adding log: $e');
      throw Exception('Failed to add log: $e');
    }
  }

  /// 特定ログ削除
  Future<void> deleteLog(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        DatabaseHelper.tableLogs,
        where: '${DatabaseHelper.colLogId} = ?',
        whereArgs: [id],
      );
      debugPrint('[DB] Log $id deleted');
    } catch (e) {
      debugPrint('[DB] Error deleting log: $e');
      throw Exception('Failed to delete log: $e');
    }
  }

  /// 特定日のログ全削除
  Future<void> deleteLogsByDate(DateTime date) async {
    try {
      final db = await _dbHelper.database;
      final dateStr = date.toIso8601String().split('T')[0];
      final count = await db.delete(
        DatabaseHelper.tableLogs,
        where: '${DatabaseHelper.colCompletedDate} = ?',
        whereArgs: [dateStr],
      );
      debugPrint('[DB] Deleted $count logs for date: $dateStr');
    } catch (e) {
      debugPrint('[DB] Error deleting logs: $e');
      throw Exception('Failed to delete logs: $e');
    }
  }
}
