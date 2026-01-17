class WorkoutSchedule {
  final int id;
  final DateTime scheduledDate;
  final bool isCompleted;
  final String menuTitle;
  final String menuDifficulty;

  WorkoutSchedule({
    required this.id,
    required this.scheduledDate,
    required this.isCompleted,
    required this.menuTitle,
    required this.menuDifficulty,
  });

  factory WorkoutSchedule.fromJson(Map<String, dynamic> json) {
    return WorkoutSchedule(
      id: json['id'],
      scheduledDate: DateTime.parse(json['scheduled_date']),
      isCompleted: json['is_completed'],
      menuTitle: json['menu_title'],
      menuDifficulty: json['menu_difficulty'],
    );
  }
}
