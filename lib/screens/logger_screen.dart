import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/network_log.dart';
import '../providers/logger_provider.dart';
import '../services/logger_service.dart';

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerScreenState();
}

class _LoggerScreenState extends State<LoggerScreen> {
  StreamSubscription? _logSub;

  @override
  void initState() {
    super.initState();
    final loggerProvider = context.read<LoggerProvider>();
    loggerProvider.init();

    // Start listening for logs from LoggerService
    _logSub = LoggerService.startLogging((log) async {
      await loggerProvider.logNetwork(
        signalStrength: log.signalStrength ?? 0,
        downloadSpeed: log.downloadKb,
        uploadSpeed: log.uploadKb,
        weather: log.weather ?? '',
        temperature: log.temperature ?? 0.0,
      );
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    LoggerService.stopLogging();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoggerProvider>();
    final logs = provider.logs;
    final isLogging = provider.isLogging;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Logger Screen"),
        actions: [
          IconButton(
            icon: Icon(isLogging ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (isLogging) {
                LoggerService.stopLogging();
              } else {
                _restartLogging(provider);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: logs.isEmpty
            ? _buildPlaceholderUI(isLogging)
            : _buildLogDetails(logs.last, isLogging),
      ),
    );
  }

  Future<void> _restartLogging(LoggerProvider provider) async {
    LoggerService.stopLogging();
    _logSub?.cancel();

    _logSub = LoggerService.startLogging((log) async {
      await provider.logNetwork(
        signalStrength: log.signalStrength ?? -90,
        downloadSpeed: log.downloadKb,
        uploadSpeed: log.uploadKb,
        weather: log.weather ?? '',
        temperature: log.temperature ?? 0.0,
      );
    });
  }

  Widget _buildLogDetails(NetworkLog log, bool isLogging) {
    String safeValue(dynamic value, [String fallback = "Unknown"]) {
      if (value == null) return fallback;
      if (value is double && value.isNaN) return fallback;
      return value.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard("Download Speed", "${safeValue(log.downloadKb, "0.0")} MB/s"),
        const SizedBox(height: 10),
        _buildCard("Upload Speed", "${safeValue(log.uploadKb, "0.0")} MB/s"),
        const SizedBox(height: 10),
        _buildCard("Signal Strength", "${safeValue(log.signalStrength, "-90")} dBm"),
        const SizedBox(height: 10),
        _buildCard(
          "Location",
          (log.latitude != null && log.longitude != null)
              ? "${log.latitude!.toStringAsFixed(5)}, ${log.longitude!.toStringAsFixed(5)}"
              : "Home",
        ),
        const SizedBox(height: 10),
        _buildCard("Weather", safeValue(log.weather)),
        const SizedBox(height: 10),
        _buildCard(
            "Temperature", "${safeValue(log.temperature, "30.0")} °C"),
        const SizedBox(height: 10),
        _buildCard(
          "Timestamp",
          log.timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(log.timestamp)
              .toIso8601String()
              : "Unknown",
        ),
        const Spacer(),
        Center(
          child: Text(
            "Logging ${isLogging ? 'active' : 'paused'}",
            style: TextStyle(
              fontSize: 16,
              color: isLogging ? Colors.green : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderUI(bool isLogging) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_tethering, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            "Waiting for first network log...",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            "Logging is ${isLogging ? 'active' : 'paused'}",
            style: TextStyle(
              fontSize: 14,
              color: isLogging ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCard(String title, String value) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }
}
