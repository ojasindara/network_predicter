// Core Flutter imports
import 'package:flutter/material.dart';
// Hive Flutter import for local storage
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

// Your model
import 'models/network_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Your app screens (kept in /screens folder)
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/loginpage.dart';
import 'screens/logger_screen.dart';
import 'services/logger_service.dart';
import 'screens/history_screen.dart';
import 'screens/map_screen.dart';
import 'package:provider/provider.dart';
import 'providers/logger_provider.dart'; // adjust path if needed


void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Background task triggered: $task");

    // Call your logging function
    await LoggerService.logNowBackground(); // static function

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings before Firebase
  await Supabase.initialize(
    url: 'https://lofhphqjdfairgjqhjvp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxvZmhwaHFqZGZhaXJnanFoanZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTU5NDEsImV4cCI6MjA3NjU3MTk0MX0.jvhRvUDFaDMB1ArZBxDsNPvrzlX_V6RvrejjycMeaE0',
  );
  //Workmanager initialize
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // set to false for production
  );

  // Hive initialization
  await Hive.initFlutter();
  Hive.registerAdapter(NetworkLogAdapter());
  await Hive.openBox<NetworkLog>('networkLogs');
  await Hive.openBox('regionsCache');

  // Schedule a periodic task
  Workmanager().registerPeriodicTask(
    "network_logger_task",
    "logNow",
    frequency: const Duration(minutes: 15), // minimum 15 mins on Android
  );


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
