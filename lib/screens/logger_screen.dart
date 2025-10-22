import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import '../models/network_log.dart';
import '../services/logger_service.dart';

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({Key? key}) : super(key: key);

  @override
  State<LoggerScreen> createState() => _LoggerScreenState();
}

class _LoggerScreenState extends State<LoggerScreen> {
  NetworkLog? _latestLog;
  bool _isLogging = false;
  StreamSubscription? _logSub;

  @override
  void initState() {
    super.initState();
    _startLogger();
  }

  @override
  void dispose() {
    LoggerService.stopLogging();
    _logSub?.cancel();
    super.dispose();
  }

  void _startLogger() {
    setState(() => _isLogging = true);
    LoggerService.startLogging((log) {
      setState(() => _latestLog = log);
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = _latestLog;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Logger Screen"),
        actions: [
          IconButton(
            icon: Icon(_isLogging ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (_isLogging) {
                LoggerService.stopLogging();
              } else {
                _startLogger();
              }
              setState(() => _isLogging = !_isLogging);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: log == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _buildCard("Download Speed", "${log.downloadSpeed.toStringAsFixed(2)} MB/s"),
            const SizedBox(height: 10),
            _buildCard("Upload Speed", "${log.uploadSpeed.toStringAsFixed(2)} MB/s"),
            const SizedBox(height: 10),
            _buildCard("Signal Strength", "${log.signalStrength} dBm"),
            const SizedBox(height: 10),
            _buildCard("Location", "${log.latitude.toStringAsFixed(5)}, ${log.longitude.toStringAsFixed(5)}"),
            const SizedBox(height: 10),
            _buildCard("Timestamp", log.timestamp.toIso8601String()),
            const Spacer(),
            Text(
              "Logging ${_isLogging ? 'active' : 'paused'}",
              style: TextStyle(
                fontSize: 16,
                color: _isLogging ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
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
