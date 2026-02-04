class WorkoutSchedule {
  final int id;
  final DateTime scheduledDate;
  final bool isCompleted;
  final String menuTitle;
  final String menuDifficulty;
  final String? workoutDetails; // 例: "6x6 @ 70.0kg"

  WorkoutSchedule({
    required this.id,
    required this.scheduledDate,
    required this.isCompleted,
    required this.menuTitle,
    required this.menuDifficulty,
    this.workoutDetails,
  });

  // JSON用（後方互換性のため維持）
  factory WorkoutSchedule.fromJson(Map<String, dynamic> json) {
    return WorkoutSchedule(
      id: json['id'],
      scheduledDate: DateTime.parse(json['scheduled_date']),
      isCompleted: json['is_completed'],
      menuTitle: json['menu_title'],
      menuDifficulty: json['menu_difficulty'],
      workoutDetails: json['workout_details'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'is_completed': isCompleted,
      'menu_title': menuTitle,
      'menu_difficulty': menuDifficulty,
      'workout_details': workoutDetails,
    };
  }

  // SQLite用
  factory WorkoutSchedule.fromMap(Map<String, dynamic> map) {
    return WorkoutSchedule(
      id: map['id'] as int,
      scheduledDate: DateTime.parse(map['scheduled_date'] as String),
      isCompleted: (map['is_completed'] as int) == 1,
      menuTitle: map['menu_title'] as String,
      menuDifficulty: map['menu_difficulty'] as String,
      workoutDetails: map['workout_details'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'is_completed': isCompleted ? 1 : 0,
      'menu_title': menuTitle,
      'menu_difficulty': menuDifficulty,
      'workout_details': workoutDetails,
    };
  }
}
