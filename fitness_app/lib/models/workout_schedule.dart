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
}
