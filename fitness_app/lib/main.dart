import 'package:flutter/material.dart';
import 'package:fitness_app/add_log_manual_screen.dart';
import 'package:fitness_app/create_custom_menu_screen.dart';
import 'package:fitness_app/login_screen.dart';
import 'package:fitness_app/home_screen.dart'; // Contains WorkoutDetailScreen now
import 'package:fitness_app/signup_screen.dart';
import 'package:fitness_app/add_schedule_screen.dart';
import 'package:fitness_app/workout_screen.dart';
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
        primaryColor: Colors.black87,
        colorScheme: const ColorScheme.light().copyWith(
          primary: Colors.black87,
          secondary: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // More rounded
            ),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18), // Increased padding
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F8F8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // Increased padding
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black87,
          ),
        )
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
          return AddManualLogScreen(selectedDate: args?['selectedDate'] as DateTime?);
        },
        '/create_custom_menu': (context) => const CreateCustomMenuScreen(),
      },
    );
  }
}
