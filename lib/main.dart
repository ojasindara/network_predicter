// Core Flutter imports
import 'package:flutter/material.dart';
// Hive Flutter import for local storage
import 'package:hive_flutter/hive_flutter.dart';

// Your app screens (kept in /screens folder)
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/logger_screen.dart';
import 'screens/history_screen.dart';
import 'screens/map_screen.dart';
import 'screens/compare_screen.dart';

void main() async {
  // Ensures widgets are properly initialized before any async code
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes Hive local database system (for saving data locally)
  await Hive.initFlutter();

  // Launch the app
  runApp(const MyApp());
}

// Root widget of the entire app
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Tracker',

      // 🔹 App theme (using Material 3)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // 🔹 First screen shown when app launches
      initialRoute: '/',

      // 🔹 Register routes for navigation
      routes: {
        '/': (context) => const SplashScreen(),   // Splash Screen
        '/home': (context) => const HomeScreen(), // Main Home
        '/logger': (context) => const LoggerScreen(), // Network Logger
        '/history': (context) => const HistoryScreen(), // History Page
        '/map': (context) => const MapScreen(), // Map Page
      },
    );
  }
}
