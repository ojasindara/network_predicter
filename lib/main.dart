// Core Flutter imports
import 'package:flutter/material.dart';
// Hive Flutter import for local storage
import 'package:hive_flutter/hive_flutter.dart';

// Your model
import 'models/network_log.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Your app screens (kept in /screens folder)
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/loginpage.dart';
import 'screens/logger_screen.dart';
import 'screens/history_screen.dart';
import 'screens/map_screen.dart';
import 'package:provider/provider.dart';
import 'providers/logger_provider.dart'; // adjust path if needed

import 'screens/compare_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings before Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Hive initialization
  await Hive.initFlutter();
  Hive.registerAdapter(NetworkLogAdapter());
  await Hive.openBox<NetworkLog>('networkLogs');

  // Launch the app with Provider
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoggerProvider()..init()),
      ],
      child: const MyApp(),
    ),
  );
}

// Root widget of the entire app
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Internet speed logging, coverage mapping and Availability Predicter',

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
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
