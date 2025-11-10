// Core Flutter imports
import 'package:flutter/material.dart';
// Hive Flutter import for local storage
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Your model
import 'models/network_log.dart';

// Your app screens
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/loginpage.dart';
import 'screens/logger_screen.dart';
import 'screens/history_screen.dart';
import 'screens/prediction_screen.dart';
import 'screens/map_screen.dart';

import 'package:provider/provider.dart';
import 'providers/logger_provider.dart'; // adjust path if needed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://lofhphqjdfairgjqhjvp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxvZmhwaHFqZGZhaXJnanFoanZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTU5NDEsImV4cCI6MjA3NjU3MTk0MX0.jvhRvUDFaDMB1ArZBxDsNPvrzlX_V6RvrejjycMeaE0',
  );

  // Hive initialization
  await Hive.initFlutter();
  Hive.registerAdapter(NetworkLogAdapter());
  await Hive.openBox<NetworkLog>('networkLog');
  await Hive.openBox('regionsCache');

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
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/logger': (context) => LoggerScreen(),
        '/history': (context) => const HistoryScreen(),
        '/map': (context) => const MapScreen(),
        '/login': (context) => const LoginPage(),
        '/prediction': (context) => const PredictionScreen(),
      },
    );
  }
}
