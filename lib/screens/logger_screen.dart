// logger_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../data/db.dart';
import '../data/region_matcher.dart';
import '../models/network_log.dart';

const String backendUrl = "http://10.139.39.204/logCell"; // change to your backend

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerState();
}

class _LoggerState extends State<LoggerScreen> {
  final _db = AppDB();
  final _matcher = RegionMatcher();

  double? _lat, _lng;
  double? _signalDbm = -1; // placeholder (you may update with actual reading)
  double? _downloadMbps;
  String? _netType = "unknown";

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // ------------------- Permissions -------------------
  Future<void> _requestPermissions() async {
    // Location via Geolocator
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      // note: if denied forever, user must open settings to enable
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission denied. Some features won't work.")),
      );
    }

    // Other permissions (storage, camera) if you truly need them
    final others = <Permission>[Permission.storage, Permission.camera];
    for (final p in others) {
      final status = await p.status;
      if (status.isDenied) {
        final req = await p.request();
        if (req.isPermanentlyDenied) {
          // Let user know
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${p.toString()} permanently denied. Please enable in settings.')),
          );
        }
      }
    }
  }

  // ------------------- Download speed (bounded) -------------------
  /// Downloads up to [maxBytesToRead] bytes or until [timeoutSec] seconds pass,
  /// then returns an estimate of Mbps.
  Future<double> getDownloadSpeedMbps({int maxBytesToRead = 3 * 1024 * 1024, int timeoutSec = 15}) async {
    try {
      final url = Uri.parse('https://speed.hetzner.de/100MB.bin');
      final stopwatch = Stopwatch()..start();
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: timeoutSec);

      final request = await client.getUrl(url).timeout(Duration(seconds: timeoutSec));
      final response = await request.close().timeout(Duration(seconds: timeoutSec));

      int bytesRead = 0;
      final completer = Completer<void>();
      final subscription = response.listen(
            (data) {
          bytesRead += data.length;
          if (bytesRead >= maxBytesToRead && !completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () => completer.complete(),
        onError: (e) {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      // Wait until we either read enough or timeout
      await completer.future.timeout(Duration(seconds: timeoutSec), onTimeout: () {
        // If timeout, cancel subscription
        subscription.cancel();
      });
      stopwatch.stop();
      await subscription.cancel();
      client.close(force: true);

      if (stopwatch.elapsedMilliseconds == 0) return 0.0;

      // bytes -> bits, divide by seconds, convert to megabits
      final mbps = (bytesRead * 8) / (stopwatch.elapsedMilliseconds / 1000) / 1000000;
      return mbps.isFinite ? mbps : 0.0;
    } catch (e) {
      // Don't crash the app if the test fails
      return 0.0;
    }
  }

  // ------------------- Live readings -------------------
  Future<void> _grabLiveReadings() async {
    setState(() => _isLoading = true);
    try {
      // Location
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      // Speed test
      final speed = await getDownloadSpeedMbps();

      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _downloadMbps = speed;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching readings: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------- Log now: save locally (Hive) + local DB + remote -------------------
  Future<void> _logNow() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No GPS fix yet. Please refresh readings first.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final match = await _matcher.findNearest(_lat!, _lng!);

      // Insert to your local DB (existing AppDB)
      await _db.insertLog(
        ts: DateTime.now(),
        lat: _lat!,
        lng: _lng!,
        signalDbm: _signalDbm,
        downloadMbps: _downloadMbps,
        netType: _netType,
        regionId: match?.regionId,
      );

      // Also save to Hive so HistoryScreen (which reads Hive) will show it
      try {
        final hiveBox = Hive.box<NetworkLog>('networkLogs');
        final log = NetworkLog(
          timestamp: DateTime.now(),
          latitude: _lat!,
          longitude: _lng!,
          signalStrength: (_signalDbm ?? 0).toInt(),
        );
        await hiveBox.add(log);
      } catch (e) {
        // If Hive fails, do not block overall logging — just notify
        debugPrint("Failed to save to Hive: $e");
      }

      // Prepare remote payload
      final payload = {
        'ts': DateTime.now().toIso8601String(),
        'lat': _lat ?? 0.0,
        'lng': _lng ?? 0.0,
        'signal_dbm': _signalDbm ?? 0.0,
        'download_mbps': _downloadMbps ?? 0.0,
        'net_type': _netType ?? 'unknown',
        'region_id': match?.regionId,
        'region_name': match?.name,
      };

      // POST to remote backend (non-blocking if remote fails)
      try {
        final res = await http
            .post(
          Uri.parse(backendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Log saved locally and synced to server.")),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Server error: ${res.statusCode}. Saved locally.")),
          );
        }
      } catch (e) {
        // Network error — we already saved locally, inform user
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved locally — failed to sync to server.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to log: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------- Save Region (unchanged) -------------------
  Future<void> _saveAsRegionDialog() async {
    if (_lat == null || _lng == null) return;

    final nameCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '40');

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save this location as a region'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('GPS: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}'),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Region name'),
            ),
            TextField(
              controller: radiusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Match radius (m)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final r = int.tryParse(radiusCtrl.text.trim()) ?? 40;
        await _db.insertRegion(nameCtrl.text.trim(), _lat!, _lng!, radiusM: r);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Region saved')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to save region: $e")),
        );
      }
    }
  }

  // ------------------- Build UI -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.place),
            onPressed: () => Navigator.pushNamed(context, '/regions'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.pushNamed(context, '/compare'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('GPS: ${_lat?.toStringAsFixed(5) ?? '--'}, ${_lng?.toStringAsFixed(5) ?? '--'}')),
                const SizedBox(width: 8),
                Text('Signal: ${_signalDbm?.toStringAsFixed(0) ?? '--'} dBm'),
                const SizedBox(width: 8),
                Text('Speed: ${_downloadMbps?.toStringAsFixed(2) ?? '--'} Mbps'),
                const SizedBox(width: 8),
                Text('Net: ${_netType ?? '--'}'),
              ],
            ),
            const SizedBox(height: 12),

            // full-width refresh button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _grabLiveReadings,
                icon: _isLoading
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.refresh),
                label: Text(_isLoading ? 'Please wait...' : 'Refresh readings'),
              ),
            ),
            const SizedBox(height: 8),

            // full-width log button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _logNow,
                icon: const Icon(Icons.save),
                label: const Text('Log now'),
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _saveAsRegionDialog,
                child: const Text('Save this as a region'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
