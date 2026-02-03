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
}
