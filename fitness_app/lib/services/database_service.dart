import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/models/workout_log.dart';
import 'package:fitness_app/models/custom_program.dart';
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

  // ==================== セッション管理 ====================

  /// セッションを保存（ログイン状態を保持）
  Future<void> saveSession(String username) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // 既存のセッションをクリア
        await txn.delete(DatabaseHelper.tableSession);
        // 新しいセッションを保存
        await txn.insert(
          DatabaseHelper.tableSession,
          {DatabaseHelper.colSessionUsername: username},
        );
      });
      debugPrint('[DB] Session saved for: $username');
    } catch (e) {
      debugPrint('[DB] Save session error: $e');
    }
  }

  /// 現在のセッション（ログインユーザー名）を取得
  Future<String?> getSession() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> result = await db.query(
        DatabaseHelper.tableSession,
        limit: 1,
      );
      if (result.isNotEmpty) {
        return result.first[DatabaseHelper.colSessionUsername] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[DB] Get session error: $e');
      return null;
    }
  }

  /// セッションをクリア（ログアウト）
  Future<void> clearSession() async {
    try {
      final db = await _dbHelper.database;
      await db.delete(DatabaseHelper.tableSession);
      debugPrint('[DB] Session cleared');
    } catch (e) {
      debugPrint('[DB] Clear session error: $e');
    }
  }

  // ==================== アプリ設定 ====================

  /// 設定を保存
  Future<void> saveSetting(String key, String value) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        DatabaseHelper.tableSettings,
        {
          DatabaseHelper.colSettingKey: key,
          DatabaseHelper.colSettingValue: value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[DB] Setting saved: $key = $value');
    } catch (e) {
      debugPrint('[DB] Save setting error: $e');
    }
  }

  /// 設定を取得
  Future<String?> getSetting(String key) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> result = await db.query(
        DatabaseHelper.tableSettings,
        where: '${DatabaseHelper.colSettingKey} = ?',
        whereArgs: [key],
      );
      if (result.isNotEmpty) {
        return result.first[DatabaseHelper.colSettingValue] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[DB] Get setting error: $e');
      return null;
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

  /// 10x10プログラムの次回の重量を調整する
  Future<void> adjustNext10x10Workout(
      WorkoutSchedule completedSchedule, bool wasSuccess) async {
    try {
      final allSchedules = await getSchedules();
      allSchedules.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

      final remainingSchedules = allSchedules
          .where((s) =>
              s.menuTitle == '10x10' &&
              !s.isCompleted &&
              s.scheduledDate.isAfter(completedSchedule.scheduledDate))
          .toList();

      if (remainingSchedules.isEmpty) return;

      final details = completedSchedule.workoutDetails;
      double currentWeight = 0;
      if (details != null && details.contains('@')) {
        final weightString =
            details.split('@')[1].trim().split('kg')[0].trim();
        currentWeight = double.tryParse(weightString) ?? 0;
      }

      if (currentWeight <= 0) return;

      final List<WorkoutSchedule> updatedSchedules = [];
      for (int i = 0; i < remainingSchedules.length; i++) {
        final schedule = remainingSchedules[i];
        double newWeight;
        if (wasSuccess) {
          newWeight = currentWeight + ((i + 1) * 2.5);
        } else {
          newWeight = currentWeight + (i * 2.5);
        }

        updatedSchedules.add(WorkoutSchedule(
          id: 0,
          scheduledDate: schedule.scheduledDate,
          isCompleted: false,
          menuTitle: schedule.menuTitle,
          menuDifficulty: schedule.menuDifficulty,
          workoutDetails: '10x10 @ ${newWeight.toStringAsFixed(1)}kg',
          sessionTitle: schedule.sessionTitle,
        ));
      }

      for (final schedule in remainingSchedules) {
        await deleteSchedule(schedule.id);
      }
      await addSchedules(updatedSchedules);
    } catch (e) {
      debugPrint('[DB] Error adjusting 10x10 schedules: $e');
      rethrow;
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

  // ==================== カスタムプログラム ====================

  /// カスタムプログラム追加
  Future<void> addCustomProgram(CustomProgram program) async {
    try {
      final db = await _dbHelper.database;
      final map = program.toMap();
      map.remove('id'); // IDは自動生成

      final id = await db.insert(DatabaseHelper.tableCustomPrograms, map);
      debugPrint('[DB] Custom program added with id: $id');
    } catch (e) {
      debugPrint('[DB] Error adding custom program: $e');
      throw Exception('Failed to add custom program: $e');
    }
  }

  /// カスタムプログラム全取得
  Future<List<CustomProgram>> getCustomPrograms() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableCustomPrograms,
        orderBy: '${DatabaseHelper.colProgramId} DESC',
      );

      final programs = maps.map((map) => CustomProgram.fromMap(map)).toList();
      debugPrint('[DB] Loaded ${programs.length} custom programs');
      return programs;
    } catch (e) {
      debugPrint('[DB] Error loading custom programs: $e');
      throw Exception('Failed to load custom programs: $e');
    }
  }

  /// カスタムプログラム削除（関連する未完了スケジュールも削除）
  Future<void> deleteCustomProgram(int id) async {
    try {
      final db = await _dbHelper.database;
      
      // 1. プログラム名を取得しておく
      final List<Map<String, dynamic>> result = await db.query(
        DatabaseHelper.tableCustomPrograms,
        where: '${DatabaseHelper.colProgramId} = ?',
        whereArgs: [id],
      );
      
      if (result.isNotEmpty) {
        final programName = result.first[DatabaseHelper.colProgramName] as String;
        
        // 2. プログラム本体を削除
        await db.delete(
          DatabaseHelper.tableCustomPrograms,
          where: '${DatabaseHelper.colProgramId} = ?',
          whereArgs: [id],
        );
        
        // 3. スケジュールテーブルから、このプログラム名の未完了セッションを削除
        final count = await db.delete(
          DatabaseHelper.tableSchedules,
          where: '${DatabaseHelper.colMenuTitle} = ? AND ${DatabaseHelper.colIsCompleted} = 0',
          whereArgs: [programName],
        );
        
        debugPrint('[DB] Custom program "$programName" and $count related incomplete schedules deleted');
      }
    } catch (e) {
      debugPrint('[DB] Error deleting custom program and schedules: $e');
      throw Exception('Failed to delete custom program and schedules: $e');
    }
  }
}
