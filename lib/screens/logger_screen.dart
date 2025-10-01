// logger_screen.dart
// Replace your existing LoggerScreen with this file.
// It would require the same imports you already have in your project.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/cell_info_service.dart'; // adjust path if needed
import '../services/network_speed_test.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';

import '../data/db.dart';
import '../data/region_matcher.dart';
import '../models/network_log.dart';
import '../services/netspeed.dart'; // your EventChannel wrapper

const String backendUrl = "http://10.139.39.204/logCell"; // change as needed

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerState();
}

class _LoggerState extends State<LoggerScreen> {
  final _db = AppDB();
  final _matcher = RegionMatcher();
  final FlutterInternetSpeedTest _speedTester = FlutterInternetSpeedTest();
  Timer? _logTimer;
  final int _logIntervalSec = 60; // log every 60 seconds

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

  // ---------------- Rate extractor (robust) ----------------
  double _extractRate(dynamic tr) {
    try {
      if (tr == null) return 0.0;
      // Many TestResult shapes expose transferRate or transferRateInMbps, try both
      if (tr is double) return tr;
      if (tr is num) return tr.toDouble();

      if (tr.transferRate != null) {
        final v = tr.transferRate;
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
      }
      if (tr.transferRateMbps != null) {
        final v = tr.transferRateMbps;
        if (v is num) return v.toDouble();
      }
      // fallback: try commonly named fields
      if (tr.value != null) {
        final v = tr.value;
        if (v is num) return v.toDouble();
      }
    } catch (_) {}
    return 0.0;
  }

  Future<void> _updateSignalStrength() async {
    try {
      final int? dbm = await FlutterInternetSignal().getMobileSignalStrength();
      if (dbm != null && mounted) setState(() => _signalDbm = dbm.toDouble());
    } catch (e) {
      debugPrint("Error getting mobile signal: $e");
    }
  }
  // ---------------- Speed test wrapper (uses callbacks) ----------------
  Future<Map<String, double>> _runSpeedTest({int timeoutSec = 12}) async {
    final completer = Completer<Map<String, double>>();
    double? dlRate;
    double? ulRate;
    Timer? timeoutTimer;

    void tryCompleteIfReady() {
      if ((dlRate != null && ulRate != null) && !completer.isCompleted) {
        // both values present — complete with them
        completer.complete({'download': dlRate!, 'upload': ulRate!});
      }
    }

    // Timeout safeguard: complete with whatever we have if time runs out
    timeoutTimer = Timer(Duration(seconds: timeoutSec), () {
      if (!completer.isCompleted) {
        completer.complete({
          'download': dlRate ?? 0.0,
          'upload': ulRate ?? 0.0,
        });
      }
    });

    try {
      _speedTester.startTesting(
        useFastApi: true,
        onStarted: () {
          // optional UI hook
        },
        onProgress: (dynamic percent, dynamic data) {
          // optional: update progress
        },
        // When the package gives both results at once:
        onCompleted: (downloadResult, uploadResult) {
          try {
            dlRate = downloadResult.valueAsMbps;  // 👈 clean Mbps
            ulRate = uploadResult.valueAsMbps;    // 👈 clean Mbps
          } catch (_) {
            dlRate = 0.0;
            ulRate = 0.0;
          }

          if (!completer.isCompleted) {
            completer.complete({
              'download': dlRate ?? 0.0,
              'upload': ulRate ?? 0.0,
            });
          }
        },

        // When package provides separate callbacks:
        onDownloadComplete: (dynamic data) {
          try {
            dlRate = _extractRate(data);
          } catch (_) {}
          tryCompleteIfReady();
        },
        onUploadComplete: (dynamic data) {
          try {
            ulRate = _extractRate(data);
          } catch (_) {}
          tryCompleteIfReady();
        },
        onError: (String errMsg, String speedTestErr) {
          if (!completer.isCompleted) {
            completer.complete({'download': dlRate ?? 0.0, 'upload': ulRate ?? 0.0});
          }
        },
        onDefaultServerSelectionInProgress: () {},
        onDefaultServerSelectionDone: (dynamic client) {},
        onCancel: () {
          if (!completer.isCompleted) {
            completer.complete({'download': dlRate ?? 0.0, 'upload': ulRate ?? 0.0});
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete({'download': dlRate ?? 0.0, 'upload': ulRate ?? 0.0});
      }
    }

    // Ensure timeoutTimer is cancelled when the future completes
    return completer.future.whenComplete(() => timeoutTimer?.cancel());
  }

// Hybrid _extractRate: tries many common fields and parses strings too



  Future<void> _updateNetType() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      String nt;
      if (connectivityResult == ConnectivityResult.wifi) {
        nt = "Wi-Fi";
      } else if (connectivityResult == ConnectivityResult.mobile) {
        nt = "Mobile";
      } else {
        nt = "None";
      }
      if (mounted) setState(() => _netType = nt);
    } catch (e) {
      debugPrint("Error getting network type: $e");
    }
  }

  // ---------------- Refresh Live Readings ----------------
  Future<void> _grabLiveReadings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      // update signal & net type
      await _updateSignalStrength();
      await _updateNetType();

      // run a speed test and apply results
      final speeds = await _runSpeedTest(timeoutSec: 10);

      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _downloadMbps = speeds['download'];
        _uploadMbps = speeds['upload'];
        _lastTestedSpeed = _downloadMbps;
      });
    } catch (e) {
      debugPrint("Error grabbing live readings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to get readings: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Logging ----------------
  Future<void> _logNow({bool continuous = false}) async {
    // If no GPS, nothing to log (manual flow would show snackbar)
    if (_lat == null || _lng == null) {
      if (!continuous && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No GPS fix yet. Refresh readings first.")),
        );
      }
      return;
    }

    if (!continuous && mounted) setState(() => _isLoading = true);

    try {
      final match = await _matcher.findNearest(_lat!, _lng!);

      // Save to SQLite/local DB
      await _db.insertLog(
        ts: DateTime.now(),
        lat: _lat!,
        lng: _lng!,
        signalDbm: _signalDbm,
        downloadMbps: _downloadMbps,
        netType: _netType,
        regionId: match?.regionId,
      );

      // Save to Hive (ensure box opened in main())
      try {
        final hiveBox = Hive.box<NetworkLog>('networkLogs');
        await hiveBox.add(NetworkLog(
          timestamp: DateTime.now(),
          latitude: _lat!,
          longitude: _lng!,
          signalStrength: (_signalDbm ?? 0).toInt(),
          downloadSpeed: (_downloadMbps ?? 0.0) * 1000, // kbps
          uploadSpeed: (_uploadMbps ?? 0.0) * 1000,     // kbps
        ));
      } catch (e) {
        debugPrint("Hive add failed: $e");
      }

      // Get cell info (graceful)
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

      // Remote sync
      try {
        final response = await http.post(
          Uri.parse(backendUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        );

        if (!continuous && mounted) {
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Log saved & synced.")));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved locally. Sync failed: ${response.body}")));
          }
        }
      } catch (e) {
        if (!continuous && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved locally. Sync failed: $e")));
        }
      }
    } catch (e) {
      debugPrint("Logging failed: $e");
      if (!continuous && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved locally. Sync failed: $e")));
      }
    } finally {
      if (!continuous && mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Continuous Logging ----------------
  Future<void> _startContinuousLogging() async {
    // take one immediate reading, so logs would have values at once
    try {
      await _grabLiveReadings();
    } catch (e) {
      debugPrint("Initial grab before auto-log failed: $e");
    }

    _logTimer?.cancel();

    // periodic safe wrapper so exceptions won't stop the timer
    _logTimer = Timer.periodic(Duration(seconds: _logIntervalSec), (t) async {
      try {
        // refresh readings then log
        await _grabLiveReadings();
        await _logNow(continuous: true);
      } catch (e) {
        debugPrint("Auto-log tick error: $e");
        // keep going
      }
    });

    if (mounted) setState(() {});
  }

  void _stopContinuousLogging() {
    _logTimer?.cancel();
    _logTimer = null;
    if (mounted) setState(() {});
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
                Text("Sig: ${_signalDbm == -1 ? '--' : _signalDbm?.toStringAsFixed(0)} dBm"),
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
            // Auto Log start/stop
            ElevatedButton.icon(
              onPressed: _logTimer == null ? _startContinuousLogging : _stopContinuousLogging,
              icon: Icon(_logTimer == null ? Icons.play_arrow : Icons.stop),
              label: Text(_logTimer == null ? "Start Auto Log" : "Stop Auto Log"),
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
