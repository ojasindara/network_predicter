// logger_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';

import '../data/db.dart';
import '../data/region_matcher.dart';
import '../models/network_log.dart';
import '../services/netspeed.dart'; // <-- your EventChannel wrapper

const String backendUrl = "http://10.139.39.204/logCell"; // change as needed

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerState();
}

class _LoggerState extends State<LoggerScreen> {
  final _db = AppDB();
  final _matcher = RegionMatcher();
  final _speedTester = FlutterInternetSpeedTest();

  double? _lat, _lng;
  double? _downloadMbps;
  double? _uploadMbps;
  double? _signalDbm = -1;
  String? _netType = "unknown";

  bool _isLoading = false;
  double? _lastTestedSpeed;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    NetSpeed.start();
  }

  // ---------------- Permissions ----------------
  Future<void> _requestPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
  }

  // ---------------- Speed formatting helper ----------------
  String _formatSpeed(double? rate, SpeedUnit unit) {
    if (rate == null) return '--';
    return '${rate.toStringAsFixed(2)} ${unit.name}';
  }

  /// Helper goes above _runSpeedTest (or anywhere in the class)
  double _extractRate(dynamic r) {
    if (r == null) return 0.0;
    if (r is double) return r;
    if (r is num) return r.toDouble();

    try {
      final tr = r.transferRate;
      if (tr == null) return 0.0;
      if (tr is double) return tr;
      if (tr is num) return tr.toDouble();

      final val = tr.value;
      if (val is double) return val;
      if (val is num) return val.toDouble();
    } catch (_) {}

    return 0.0;
  }


  // ---------------- One-time Speed Test ----------------
  Future<Map<String, double>> _runSpeedTest({int timeoutSec = 20}) async {
    final Completer<double> download = Completer();
    final Completer<double> upload = Completer();

    Timer? timer;
    timer = Timer(Duration(seconds: timeoutSec), () {
      if (!download.isCompleted) download.complete(0.0);
      if (!upload.isCompleted) upload.complete(0.0);
      try {
        _speedTester.cancelTest();
      } catch (_) {}
    });

    try {
      await _speedTester.startTesting(
        onCompleted: (downloadResult, uploadResult) {
          if (!download.isCompleted) download.complete(_extractRate(downloadResult));
          if (!upload.isCompleted) upload.complete(_extractRate(uploadResult));
        },
        onDownloadComplete: (d) {
          if (!download.isCompleted) download.complete(_extractRate(d));
        },
        onUploadComplete: (u) {
          if (!upload.isCompleted) upload.complete(_extractRate(u));
        },
        onError: (String errorMessage, String speedTestError) {
          if (!download.isCompleted) download.complete(0.0);
          if (!upload.isCompleted) upload.complete(0.0);
        },
      );

      final res = {
        'download': await download.future,
        'upload': await upload.future,
      };
      timer?.cancel();
      return res;
    } catch (_) {
      timer?.cancel();
      return {'download': 0.0, 'upload': 0.0};
    }
  }



  // ---------------- Refresh Live Readings ----------------
  Future<void> _grabLiveReadings() async {
    setState(() => _isLoading = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      final speeds = await _runSpeedTest();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _downloadMbps = speeds['download'];
        _uploadMbps = speeds['upload'];
        _lastTestedSpeed = _downloadMbps;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Log Now (local + remote) ----------------
  Future<void> _logNow() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No GPS fix yet. Refresh readings first.")),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final match = await _matcher.findNearest(_lat!, _lng!);

      await _db.insertLog(
        ts: DateTime.now(),
        lat: _lat!,
        lng: _lng!,
        signalDbm: _signalDbm,
        downloadMbps: _downloadMbps,
        netType: _netType,
        regionId: match?.regionId,
      );

      // Hive save
      final hiveBox = Hive.box<NetworkLog>('networkLogs');
      await hiveBox.add(NetworkLog(
        timestamp: DateTime.now(),
        latitude: _lat!,
        longitude: _lng!,
        signalStrength: (_signalDbm ?? 0).toInt(),
        downloadSpeed: _downloadMbps ?? 0.0,
        uploadSpeed: _uploadMbps ?? 0.0,
      ));

      // Remote sync
      final payload = {
        'ts': DateTime.now().toIso8601String(),
        'lat': _lat!,
        'lng': _lng!,
        'signal_dbm': _signalDbm ?? 0,
        'download_mbps': _downloadMbps ?? 0,
        'upload_mbps': _uploadMbps ?? 0,
        'net_type': _netType,
        'region_id': match?.regionId,
        'region_name': match?.name,
      };
      await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Log saved & synced.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved locally. Sync failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Save as Region ----------------
  Future<void> _saveAsRegionDialog() async {
    if (_lat == null || _lng == null) return;
    final nameCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '40');

    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Save as Region"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("GPS: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}"),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: radiusCtrl, decoration: const InputDecoration(labelText: "Radius (m)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );
    if (res == true) {
      await _db.insertRegion(nameCtrl.text, _lat!, _lng!,
          radiusM: int.tryParse(radiusCtrl.text) ?? 40);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Region saved")),
      );
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logger")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Live NetSpeed from EventChannel
            StreamBuilder<Map<String, double>>(
              stream: NetSpeed.speedStream,
              builder: (context, snap) {
                if (!snap.hasData) return const Text("Waiting for live speed...");
                final dl = snap.data!["download"] ?? 0.0;
                final ul = snap.data!["upload"] ?? 0.0;
                return Column(
                  children: [
                    Text(
                      "↓ ${dl.toStringAsFixed(2)} KB/s   ↑ ${ul.toStringAsFixed(2)} KB/s",
                      style: const TextStyle(fontSize: 16, color: Colors.green),
                    ),
                    if (_lastTestedSpeed != null)
                      Text(
                        "Last Tested: ${_lastTestedSpeed!.toStringAsFixed(2)} Mbps",
                        style: const TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                  ],
                );

              },
            ),
            const SizedBox(height: 16),

            // GPS + dBm + manual test
            Row(
              children: [
                Expanded(child: Text("GPS: ${_lat?.toStringAsFixed(5) ?? '--'}, ${_lng?.toStringAsFixed(5) ?? '--'}")),
                Text("Sig: ${_signalDbm?.toStringAsFixed(0)} dBm"),
              ],
            ),
            const SizedBox(height: 12),

            // Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _grabLiveReadings,
              icon: const Icon(Icons.refresh),
              label: Text(_isLoading ? "Please wait..." : "Refresh readings"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _logNow,
              icon: const Icon(Icons.save),
              label: const Text("Log Now"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isLoading ? null : _saveAsRegionDialog,
              child: const Text("Save as Region"),
            ),
          ],
        ),
      ),
    );
  }
}

