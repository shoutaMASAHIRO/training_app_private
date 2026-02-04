class WorkoutLog {
  final int? id; // Optional, as it might not be needed for display
  final DateTime completedDate;
  final String menuTitle;
  final String? workoutDetails;
  final int? successCount;
  final int? failCount;

  WorkoutLog({
    this.id,
    required this.completedDate,
    required this.menuTitle,
    this.workoutDetails,
    this.successCount,
    this.failCount,
  });

  // JSON用（後方互換性のため維持）
  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'],
      completedDate: DateTime.parse(json['completed_date']),
      menuTitle: json['menu_title'],
      workoutDetails: json['workout_details'],
      successCount: json['success_count'],
      failCount: json['fail_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completed_date': completedDate.toIso8601String().split('T')[0],
      'menu_title': menuTitle,
      'workout_details': workoutDetails,
      'success_count': successCount,
      'fail_count': failCount,
    };
  }

  // SQLite用
  factory WorkoutLog.fromMap(Map<String, dynamic> map) {
    return WorkoutLog(
      id: map['id'] as int?,
      completedDate: DateTime.parse(map['completed_date'] as String),
      menuTitle: map['menu_title'] as String,
      workoutDetails: map['workout_details'] as String?,
      successCount: map['success_count'] as int?,
      failCount: map['fail_count'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'completed_date': completedDate.toIso8601String().split('T')[0],
      'menu_title': menuTitle,
      'workout_details': workoutDetails,
      'success_count': successCount,
      'fail_count': failCount,
    };
  }
}
