// logger_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/db.dart';
import '../data/region_matcher.dart';
import '../models/network_log.dart';
import '../services/netspeed.dart';
import '../services/logger_speed_service.dart';
import '../services/logger_download_service.dart';
import '../services/logger_upload_service.dart';
import '../services/cell_info_service.dart';



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

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000; // Earth radius in meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // Tested speeds (Mbps)
  double? _downloadMbps;
  double? _uploadMbps;

  // Live stream values (KB/s)
  double _liveDownloadKb = 0.0;
  double _liveUploadKb = 0.0;
  double? _downloadSpeed;
  double? _uploadSpeed;


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
      // Step 1: Get GPS coordinates
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // Step 2: Update signal strength and network type
      await _updateSignalStrength();
      await _updateNetType();

      // Step 3: Run download and upload speed tests
      final downloadSpeed = await logger_download_service();
      final uploadSpeed = await logger_upload_service();

      // Step 4: Update state with all readings
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _downloadSpeed = downloadSpeed; // in Mbps
        _uploadSpeed = uploadSpeed;     // in Mbps
      });

      // Step 5: Save or freeze data
      _freezeLastStreamValue();

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

//Manual logging
  Future<void> _logNow({bool continuous = false}) async {
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
      // ✅ No new speed test — use current live readings
      final match = await _matcher.findNearest(_lat!, _lng!);

      // 🔹 1. Save to local SQLite
      await _db.insertLog(
        ts: DateTime.now(),
        lat: _lat!,
        lng: _lng!,
        signalDbm: _signalDbm,
        downloadMbps: _downloadMbps,
        netType: _netType,
        regionId: match?.regionId,
      );

      // 🔹 2. Save to local Hive cache
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

      // 🔹 3. Prepare payload for Firebase
      final payload = {
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "latitude": _lat,
        "longitude": _lng,
        "signal_dbm": _signalDbm,
        "download_kbps": (_downloadMbps ?? 0.0) * 1000,
        "upload_kbps": (_uploadMbps ?? 0.0) * 1000,
        "net_type": _netType,
        "region_id": match?.regionId,
        "region_name": match?.name,
      };

      // 🔹 4. Send to Firebase Firestore
      try {
        await FirebaseFirestore.instance.collection('networkLogs').add(payload);
        debugPrint("✅ Firebase upload success");
      } catch (e) {
        debugPrint("❌ Firebase upload failed: $e");
      }

      // 🔹 5. Optional: Cell info + duplicate Firebase backup
      Map<String, dynamic>? cellInfo;
      try {
        cellInfo = await CellInfoService.getCellInfo();
      } catch (e) {
        debugPrint("Cell info fetch failed: $e");
      }

      final payload2 = {
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

      await FirebaseFirestore.instance.collection('networkLogs').add(payload2);

      if (!continuous && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Log saved & synced to Firebase.")),
        );
      }
    } catch (e) {
      debugPrint("Logging failed: $e");
      if (!continuous && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logging failed: $e")),
        );
      }
    } finally {
      if (!continuous && mounted) setState(() => _isLoading = false);
    }
  }


  // ---------------- Continuous Logging ----------------
  Future<void> _startContinuousLogging() async {
    if (_isAutoLogging) return; // Already running
    _isAutoLogging = true;
    setState(() {});

    // Cancel any previous timer just to be safe
    _logTimer?.cancel();

    // 🔹 Run immediately once
    await _logNow(continuous: true);

    // 🔹 Then repeat every 20 seconds
    _logTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (!_isAutoLogging) {
        timer.cancel();
        return;
      }

      try {
        await _logNow(continuous: true);
        debugPrint("⏱ Auto log saved at ${DateTime.now()}");
      } catch (e) {
        debugPrint("⚠️ Auto log error: $e");
      }
    });

    setState(() {});
  }

  void _stopContinuousLogging() {
    _logTimer?.cancel();
    _logTimer = null;
    _isAutoLogging = false;
    setState(() {});
    debugPrint("🛑 Continuous logging stopped.");
  }

  // ---------------- Save as Region ----------------
  Future<void> _saveAsRegionDialog(double lat, double lng, String name) async {
    final box = Hive.box('regionsCache');
    List<Map<String, dynamic>> cachedRegions =
    List<Map<String, dynamic>>.from(box.get('regions', defaultValue: []));

    // Check for duplicates (within 10 meters)
    final duplicate = cachedRegions.any((region) {
      final dist = _calculateDistance(
        lat,
        lng,
        region['lat'],
        region['lng'],
      );
      return dist < 10; // same region threshold
    });

    if (duplicate) {
      debugPrint("Region already exists near this location.");
      return; // don’t save again
    }

    final regionData = {
      'name': name,
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Save to Firebase
    await FirebaseFirestore.instance.collection('regions').add(regionData);

    // Save locally to Hive
    cachedRegions.add(regionData);
    await box.put('regions', cachedRegions);

    debugPrint("Region saved successfully.");
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
                    Text("Live download speed (instant): ↓ ${_downloadSpeed != null ? _downloadSpeed!.toStringAsFixed(2) : '__'} MB/s      Upload speed ↑ ${_uploadSpeed != null ? _uploadSpeed!.toStringAsFixed(2) : '__'} KB/s",
                        style: const TextStyle(fontSize: 16, color: Colors.green)),
                    const SizedBox(height: 6),
                    if (_lastDlTested != null || _lastUlTested != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          "Last saved: DL ${_lastDlTested?.toStringAsFixed(2) ?? '--'} Mbps  |  UL ${_lastUlTested?.toStringAsFixed(2) ?? '--'} Mbps",
                          style: const TextStyle(fontSize: 15, color: Colors.blue),
                        ),
                      )
                    else
                      const Text(
                        "No saved data yet.",
                        style: TextStyle(fontSize: 15, color: Colors.black54),
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
              onPressed: () => _saveAsRegionDialog(_lat!, _lng!, "Region A"),
              child: const Text("Save as Region"),
            ),
            const SizedBox(height: 12),
            const Text(
              "Saved Regions:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: FutureBuilder(
                future: Hive.openBox('regionsCache'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final box = Hive.box('regionsCache');
                  List<Map<String, dynamic>> localRegions =
                  List<Map<String, dynamic>>.from(box.get('regions', defaultValue: []));

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('regions').snapshots(),
                    builder: (context, firebaseSnapshot) {
                      if (firebaseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (firebaseSnapshot.hasData) {
                        final firebaseRegions = firebaseSnapshot.data!.docs
                            .map((doc) => doc.data() as Map<String, dynamic>)
                            .toList();

                        // ✅ Merge Firebase regions into local cache
                        for (final region in firebaseRegions) {
                          final exists = localRegions.any((r) =>
                          r['lat'] == region['lat'] && r['lng'] == region['lng']);
                          if (!exists) {
                            localRegions.add(region);
                          }
                        }

                        // ✅ Update Hive cache
                        box.put('regions', localRegions);
                      }

                      if (localRegions.isEmpty) {
                        return const Center(child: Text("No regions saved yet."));
                      }

                      return ListView.builder(
                        itemCount: localRegions.length,
                        itemBuilder: (context, index) {
                          final region = localRegions[index];
                          return Card(
                            child: ListTile(
                              title: Text(region['name'] ?? 'Unnamed Region'),
                              subtitle: Text(
                                'Lat: ${region['lat']?.toStringAsFixed(4)} | '
                                    'Lng: ${region['lng']?.toStringAsFixed(4)}',
                              ),
                              trailing: Text(
                                region['timestamp']?.split('.')[0] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            )

          ],
        ),
      ),
    );
  }
}
