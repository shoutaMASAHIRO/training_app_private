import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // テーブル名
  static const String tableUsers = 'users';
  static const String tableSchedules = 'workout_schedules';
  static const String tableLogs = 'workout_logs';
  static const String tableCustomPrograms = 'custom_programs';

  // usersテーブルのカラム
  static const String colUserId = 'id';
  static const String colUsername = 'username';
  static const String colPasswordHash = 'password_hash';

  // workout_schedulesテーブルのカラム
  static const String colScheduleId = 'id';
  static const String colScheduledDate = 'scheduled_date';
  static const String colIsCompleted = 'is_completed';
  static const String colMenuTitle = 'menu_title';
  static const String colMenuDifficulty = 'menu_difficulty';
  static const String colWorkoutDetails = 'workout_details';
  static const String colSessionTitle = 'session_title';

  // workout_logsテーブルのカラム
  static const String colLogId = 'id';
  static const String colCompletedDate = 'completed_date';
  static const String colLogMenuTitle = 'menu_title';
  static const String colLogWorkoutDetails = 'workout_details';
  static const String colLogSessionTitle = 'session_title';
  static const String colSuccessCount = 'success_count';
  static const String colFailCount = 'fail_count';

  // custom_programsテーブルのカラム
  static const String colProgramId = 'id';
  static const String colProgramName = 'name';
  static const String colProgramDescription = 'description';
  static const String colProgramDetails = 'details';

  /// データベースファクトリの初期化
  static void initializeDatabaseFactory() {
    // Android/iOSでは追加の初期化は不要
    // デスクトップ対応が必要な場合はsqflite_common_ffiを追加してください
    debugPrint('[DB] Database factory initialized for mobile platform');
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fitness_app.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final String databasesPath = await getDatabasesPath();
    final String path = join(databasesPath, fileName);
    debugPrint('[DB] Database path: $path');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DB] Upgrading database from version $oldVersion to $newVersion');
    if (oldVersion < 2) {
      // Add the new column 'session_title' to workout_schedules table
      await db.execute('ALTER TABLE $tableSchedules ADD COLUMN $colSessionTitle TEXT;');
      debugPrint('[DB] Added column $colSessionTitle to $tableSchedules');
    }
    if (oldVersion < 3) {
      // Add the new column 'session_title' to workout_logs table
      await db.execute('ALTER TABLE $tableLogs ADD COLUMN $colLogSessionTitle TEXT;');
      debugPrint('[DB] Added column $colLogSessionTitle to $tableLogs');
    }
    if (oldVersion < 4) {
      // Create custom_programs table
      await db.execute('''
        CREATE TABLE $tableCustomPrograms (
          $colProgramId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colProgramName TEXT NOT NULL,
          $colProgramDescription TEXT,
          $colProgramDetails TEXT
        )
      ''');
      debugPrint('[DB] Created table: $tableCustomPrograms');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    debugPrint('[DB] Creating database tables...');

    // usersテーブル
    await db.execute('''
      CREATE TABLE $tableUsers (
        $colUserId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colUsername TEXT NOT NULL UNIQUE,
        $colPasswordHash TEXT NOT NULL
      )
    ''');
    debugPrint('[DB] Created table: $tableUsers');

    // workout_schedulesテーブル
    await db.execute('''
      CREATE TABLE $tableSchedules (
        $colScheduleId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colScheduledDate TEXT NOT NULL,
        $colIsCompleted INTEGER NOT NULL DEFAULT 0,
        $colMenuTitle TEXT NOT NULL,
        $colMenuDifficulty TEXT NOT NULL,
        $colWorkoutDetails TEXT,
        $colSessionTitle TEXT
      )
    ''');
    debugPrint('[DB] Created table: $tableSchedules');

    // workout_logsテーブル
    await db.execute('''
      CREATE TABLE $tableLogs (
        $colLogId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colCompletedDate TEXT NOT NULL,
        $colLogMenuTitle TEXT NOT NULL,
        $colLogWorkoutDetails TEXT,
        $colLogSessionTitle TEXT,
        $colSuccessCount INTEGER,
        $colFailCount INTEGER
      )
    ''');
    debugPrint('[DB] Created table: $tableLogs');

    // custom_programsテーブル
    await db.execute('''
      CREATE TABLE $tableCustomPrograms (
        $colProgramId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colProgramName TEXT NOT NULL,
        $colProgramDescription TEXT,
        $colProgramDetails TEXT
      )
    ''');
    debugPrint('[DB] Created table: $tableCustomPrograms');

    debugPrint('[DB] Database creation complete');
  }

  /// データベースを閉じる
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
