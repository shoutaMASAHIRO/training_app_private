import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fitness_app/models/workout_schedule.dart';

import 'package:fitness_app/services/api_config.dart';

class ApiService {
  final String _baseUrl = apiBaseUrl;

  Future<List<WorkoutSchedule>> getSchedules() async {
    final response = await http.get(Uri.parse('$_baseUrl/schedules'));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<WorkoutSchedule> schedules =
          body.map((dynamic item) => WorkoutSchedule.fromJson(item)).toList();
      return schedules;
    } else {
      throw Exception('Failed to load schedules');
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
}
