// logger_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../data/db.dart';
import '../data/region_matcher.dart';
import '../models/network_log.dart';
import '../services/netspeed.dart';
import '../services/cell_info_service.dart';

const String backendUrl = "http://10.139.39.204/logCell"; // adjust as needed

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerState();
}

class _LoggerState extends State<LoggerScreen> {
  final _db = AppDB();
  final _matcher = RegionMatcher();

  Timer? _logTimer;
  final int _logIntervalSec = 60;

  // GPS / signal / network
  double? _lat, _lng;
  double? _signalDbm = -1;
  String? _netType = "unknown";

  // Tested speeds (Mbps)
  double? _downloadMbps;
  double? _uploadMbps;

  // Live stream values (KB/s)
  double _liveDownloadKb = 0.0;
  double _liveUploadKb = 0.0;

  // Freeze last stream value
  Map<String, double> _lastStreamValue = {"download": 0.0, "upload": 0.0};
  double? _lastDlTested;
  double? _lastUlTested;

  bool _isLoading = false;
  bool _isAutoLogging = false;
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    NetSpeed.start();
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    try {
      NetSpeed.stop();
    } catch (_) {}
    super.dispose();
  }

  // ---------------- Permissions ----------------
  Future<void> _requestPermissions() async {
    LocationPermission locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied) {
      locPerm = await Geolocator.requestPermission();
    }
    if (!await Permission.phone.isGranted) {
      await Permission.phone.request();
    }
  }

  Future<void> _ensureHiveBoxOpen() async {
    try {
      if (!Hive.isBoxOpen('networkLogs')) {
        await Hive.openBox<NetworkLog>('networkLogs');
      }
    } catch (e) {
      debugPrint("Hive open failed: $e");
    }
  }

  Future<void> _updateSignalStrength() async {
    try {
      final int? dbm = await FlutterInternetSignal().getMobileSignalStrength();
      if (dbm != null && mounted) setState(() => _signalDbm = dbm.toDouble());
    } catch (e) {
      debugPrint("Error getting signal: $e");
    }
  }

  Future<void> _updateNetType() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      String nt;
      if (connectivityResult == ConnectivityResult.wifi) nt = "Wi-Fi";
      else if (connectivityResult == ConnectivityResult.mobile) nt = "Mobile";
      else nt = "None";
      if (mounted) setState(() => _netType = nt);
    } catch (e) {
      debugPrint("Error getting network type: $e");
    }
  }

  // ---------------- Freeze last stream value ----------------
  void _freezeLastStreamValue() {
    setState(() {
      _lastDlTested = (_lastStreamValue["download"] ?? 0.0) / 125.0; // KB/s -> Mbps
      _lastUlTested = (_lastStreamValue["upload"] ?? 0.0) / 125.0;
      _downloadMbps = _lastDlTested;
      _uploadMbps = _lastUlTested;
    });
  }

  // ---------------- Grab Live Readings ----------------
  Future<void> _grabLiveReadings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      await _updateSignalStrength();
      await _updateNetType();

      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });

      _freezeLastStreamValue();
    } catch (e) {
      debugPrint("Error grabbing live readings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to get readings: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Logging ----------------
  Future<void> _logNow({bool continuous = false}) async {
    if (_lat == null || _lng == null) {
      if (!continuous && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No GPS fix yet. Refresh readings first.")));
      }
      return;
    }

    if (!continuous && mounted) setState(() => _isLoading = true);

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

      await _ensureHiveBoxOpen();
      try {
        final hiveBox = Hive.box<NetworkLog>('networkLogs');
        await hiveBox.add(NetworkLog(
          timestamp: DateTime.now(),
          latitude: _lat!,
          longitude: _lng!,
          signalStrength: (_signalDbm ?? 0).toInt(),
          downloadSpeed: (_downloadMbps ?? 0.0) * 1000,
          uploadSpeed: (_uploadMbps ?? 0.0) * 1000,
        ));
      } catch (e) {
        debugPrint("Hive add failed: $e");
      }

      Map<String, dynamic>? cellInfo;
      try {
        cellInfo = await CellInfoService.getCellInfo();
      } catch (e) {
        debugPrint("Cell info fetch failed: $e");
        cellInfo = null;
      }

      final payload = {
        "cid": cellInfo?["cid"] ?? 0,
        "lac": cellInfo?["tac"] ?? 0,
        "mcc": cellInfo?["mcc"] ?? 0,
        "mnc": cellInfo?["mnc"] ?? 0,
        "lat": _lat,
        "lon": _lng,
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "signal": cellInfo?["signalDbm"] ?? _signalDbm,
        "download_kbps": (_downloadMbps ?? 0.0) * 1000,
        "upload_kbps": (_uploadMbps ?? 0.0) * 1000,
        "net_type": _netType,
        "region_id": match?.regionId,
        "region_name": match?.name,
      };

      try {
        // Upload directly to Firebase Firestore
        await FirebaseFirestore.instance.collection('networkLogs').add(payload);

        if (!continuous && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Log saved & synced to Firebase.")),
          );
        }
      } catch (e) {
        if (!continuous && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Saved locally. Firebase sync failed: $e")),
          );
        }
      }


      // ---------------- Continuous Logging ----------------
  Future<void> _startContinuousLogging() async {
    if (_isAutoLogging) return;
    _isAutoLogging = true;
    setState(() {});

    _logTimer?.cancel();
    _logTimer = Timer.periodic(Duration(seconds: _logIntervalSec), (t) async {
      if (_isLogging) return;
      _isLogging = true;
      try {
        await _grabLiveReadings();
        await _logNow(continuous: true);
      } catch (e) {
        debugPrint("Auto-log tick error: $e");
      } finally {
        _isLogging = false;
      }
    });

    _isLogging = true;
    try {
      await _grabLiveReadings();
      await _logNow(continuous: true);
    } catch (e) {
      debugPrint("Initial auto-log error: $e");
    } finally {
      _isLogging = false;
    }

    setState(() {});
  }

  void _stopContinuousLogging() {
    _logTimer?.cancel();
    _logTimer = null;
    _isAutoLogging = false;
    setState(() {});
  }

  // ---------------- Save as Region ----------------
  Future<void> _saveAsRegionDialog() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No GPS fix yet. Refresh readings first.")));
      return;
    }

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
      await _db.insertRegion(nameCtrl.text, _lat!, _lng!, radiusM: int.tryParse(radiusCtrl.text) ?? 40);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Region saved")));
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
            StreamBuilder<Map<String, double>>(
              stream: NetSpeed.speedStream,
              builder: (context, snap) {
                if (!snap.hasData) return const Text("Waiting for live speed...");

                final dlKb = snap.data!["download"] ?? 0.0;
                final ulKb = snap.data!["upload"] ?? 0.0;

                _lastStreamValue = snap.data!;
                _liveDownloadKb = dlKb;
                _liveUploadKb = ulKb;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Live (instant): ↓ ${dlKb.toStringAsFixed(2)} KB/s   ↑ ${ulKb.toStringAsFixed(2)} KB/s",
                        style: const TextStyle(fontSize: 16, color: Colors.green)),
                    const SizedBox(height: 6),
                    Text(
                      "Tested: DL ${(_downloadMbps ?? 0.0).toStringAsFixed(2)} Mbps  |  UL ${(_uploadMbps ?? 0.0).toStringAsFixed(2)} Mbps",
                      style: const TextStyle(fontSize: 15, color: Colors.blue),
                    ),
                    if (_lastDlTested != null && _lastUlTested != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          "Last tested: DL ${_lastDlTested!.toStringAsFixed(2)} Mbps  |  UL ${_lastUlTested!.toStringAsFixed(2)} Mbps",
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text("GPS: ${_lat?.toStringAsFixed(5) ?? '--'}, ${_lng?.toStringAsFixed(5) ?? '--'}")),
                Text("Sig: ${_signalDbm == -1 ? '--' : _signalDbm?.toStringAsFixed(0)} dBm"),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _grabLiveReadings,
              icon: const Icon(Icons.refresh),
              label: Text(_isLoading ? "Please wait..." : "Refresh readings"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () {
                _freezeLastStreamValue();
                _logNow(continuous: false);
              },
              icon: const Icon(Icons.save),
              label: const Text("Save Current Reading"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isAutoLogging ? _stopContinuousLogging : _startContinuousLogging,
              icon: Icon(_isAutoLogging ? Icons.stop : Icons.play_arrow),
              label: Text(_isAutoLogging ? "Stop Auto Log" : "Start Auto Log"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saveAsRegionDialog,
              child: const Text("Save as Region"),
            ),
          ],
        ),
      ),
    );
  }
}
