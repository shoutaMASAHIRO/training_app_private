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
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Slightly off-white for depth
        primaryColor: const Color(0xFF81C784), // Light Green
        colorScheme: const ColorScheme.light().copyWith(
          primary: const Color(0xFF81C784), // Light Green
          secondary: const Color(0xFFBA68C8), // Light Purple
          tertiary: const Color(0xFFFFB74D), // Light Orange
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF424242), // Darker grey for text readability
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF424242), // Dark grey text
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF424242),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF81C784), // Light Green
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB), // Very light grey/white
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF81C784), width: 2), // Light Green
          ),
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIconColor: const Color(0xFFBA68C8), // Light Purple icons
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFBA68C8), // Light Purple
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFF5F5F5), width: 1.5),
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
