import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/network_log.dart';
import '../services/location_service.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  String prediction = "Checking your location...";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _predict();
  }

  Future<void> _predict() async {
    try {
      // Get current location
      final position = await LocationService.getCurrentLocation();
      final logs = Hive.box<NetworkLog>('networkLogs').values.toList();

      // Find logs within 0.002 degrees (~200m)
      final nearbyLogs = logs.where((log) {
        return (log.latitude - position.latitude).abs() < 0.002 &&
            (log.longitude - position.longitude).abs() < 0.002;
      }).toList();

      if (nearbyLogs.isEmpty) {
        setState(() {
          prediction = "No previous data here.\nNetwork unknown.";
          loading = false;
        });
        return;
      }

      final avgStrength = nearbyLogs.map((log) => log.signalStrength).reduce((a, b) => a + b) / nearbyLogs.length;

      String status = switch (avgStrength) {
        >= 75 => "✅ Strong network expected",
        >= 50 => "⚠️ Fair network likely",
        _     => "❌ Weak network likely"
      };

      setState(() {
        prediction = "$status\n(based on ${nearbyLogs.length} nearby logs)";
        loading = false;
      });
    } catch (e) {
      setState(() {
        prediction = "Prediction failed: $e";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Predict Network"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            prediction,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
