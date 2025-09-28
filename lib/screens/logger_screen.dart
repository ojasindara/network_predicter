// logger_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/cell_info_service.dart'; // adjust path if needed
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'package:telephony/telephony.dart';
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
  final Telephony telephony = Telephony.instance;
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
    // Location permission
    LocationPermission locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied) {
      locPerm = await Geolocator.requestPermission();
    }

    // Telephony permission
    final phoneState = await Permission.phone.status;
    if (!phoneState.isGranted) {
      await Permission.phone.request();
    }
  }
  Future<void> _updateSignalStrength() async {
    try {
      final int? dbm = await FlutterInternetSignal().getMobileSignalStrength();
      if (dbm != null) {
        setState(() {
          _signalDbm = dbm.toDouble();
        });
      }
    } catch (e) {
      debugPrint("Error getting mobile signal: $e");
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


  Future<Map<String, double>> _runSpeedTest({int samples = 5, int timeoutSec = 5, int delaySec = 3}) async {
    double totalDownload = 0.0;
    double totalUpload = 0.0;

    for (int i = 0; i < samples; i++) {
      final speeds = await _runSpeedTest(timeoutSec: timeoutSec);
      totalDownload += speeds['download'] ?? 0.0;
      totalUpload += speeds['upload'] ?? 0.0;
      await Future.delayed(Duration(seconds: delaySec)); // small pause between samples
    }

    return {
      'download': totalDownload / samples,
      'upload': totalUpload / samples,
    };
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
      // ---------------- Local DB + Hive ----------------
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

      final hiveBox = Hive.box<NetworkLog>('networkLogs');
      await hiveBox.add(NetworkLog(
        timestamp: DateTime.now(),
        latitude: _lat!,
        longitude: _lng!,
        signalStrength: (_signalDbm ?? 0).toInt(),
        downloadSpeed: _downloadMbps ?? 0.0,
        uploadSpeed: _uploadMbps ?? 0.0,
      ));

      // ---------------- Get Cell Info ----------------
      final cellInfo = await CellInfoService.getCellInfo(); // <-- your MethodChannel
      if (cellInfo == null) throw Exception("No cell info available");

      // ---------------- Remote sync (backend-friendly format) ----------------
      final payload = {
        "cid": cellInfo["cid"],
        "lac": cellInfo["tac"] ?? 0, // LTE uses TAC instead of LAC
        "mcc": cellInfo["mcc"],
        "mnc": cellInfo["mnc"],
        "lat": _lat,
        "lon": _lng,
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "signal": cellInfo["signalDbm"],
      };

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Log saved & synced.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Saved locally. Sync failed: ${response.body}")),
        );
      }
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

