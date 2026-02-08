import 'package:flutter/material.dart';
import 'package:fitness_app/add_log_manual_screen.dart';
import 'package:fitness_app/create_custom_menu_screen.dart';
import 'package:fitness_app/login_screen.dart';
import 'package:fitness_app/home_screen.dart'; // Contains WorkoutDetailScreen now
import 'package:fitness_app/signup_screen.dart';
import 'package:fitness_app/add_schedule_screen.dart';
import 'package:fitness_app/workout_screen.dart';
import 'package:fitness_app/today_workouts_screen.dart';
import 'package:fitness_app/models/workout_schedule.dart';
import 'package:fitness_app/services/database_helper.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(); // Initialize date formatting
  DatabaseHelper.initializeDatabaseFactory();
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness App',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        // Add other locales you support
      ],
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF00BCD4), // Cyan
        colorScheme: const ColorScheme.light().copyWith(
          primary: const Color(0xFF00BCD4), // Cyan
          secondary: const Color(0xFF00BCD4), // Cyan (Monochromatic or accent)
          tertiary: const Color(0xFF4DD0E1), // Lighter Cyan
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF424242),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          bodyMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          bodySmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          displayMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          displaySmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          headlineSmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          titleMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          titleSmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          labelLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          labelMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
          labelSmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF00BCD4), // Cyan text/icons
          elevation: 0,
          centerTitle: true, // Centered title as per screenshots often have
          titleTextStyle: TextStyle(
            color: Color(0xFF00BCD4),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF00BCD4)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF00BCD4), // Cyan
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8), // Slightly less rounded as per screenshots
            ),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 1.5),
          ),
          hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          prefixIconColor: Colors.grey[400],
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00BCD4), // Cyan
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF00ACC1), // Cyan
        ),
        primaryIconTheme: const IconThemeData(
          color: Color(0xFF00ACC1), // Cyan
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return HomeScreen(initialIndex: args?['initialIndex'] as int?);
        },
        '/signup': (context) => const SignupScreen(),
        '/add_schedule': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return AddScheduleScreen(selectedDate: args?['selectedDate'] as DateTime?);
        },
        '/workout': (context) {
          final schedule = ModalRoute.of(context)!.settings.arguments as WorkoutSchedule;
          return WorkoutScreen(schedule: schedule);
        },
        '/today_workouts': (context) {
          final schedules = ModalRoute.of(context)!.settings.arguments as List<WorkoutSchedule>;
          return TodayWorkoutsScreen(initialSchedules: schedules);
        },
        '/workout_detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return WorkoutDetailScreen(
            workoutName: args['workoutName'] as String,
            startDate: args['startDate'] as DateTime?,
            isCustom: args['isCustom'] as bool? ?? false,
            details: args['details'] as String?,
          );
        },
        '/add_manual_log': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return AddManualLogScreen(
            selectedDate: args?['selectedDate'] as DateTime?,
            exerciseName: args?['exerciseName'] as String?,
          );
        },
        '/create_custom_menu': (context) => const CreateCustomMenuScreen(),
        '/exercise_detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ExerciseDetailScreen(exerciseName: args['exerciseName'] as String);
        },
      },
    );
  }
}
