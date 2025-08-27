import 'package:flutter/material.dart';
import '../data/db.dart';
import '../data/region_matcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

// ------------------ Helper Function for Download Speed ------------------
Future<double> getDownloadSpeedMbps() async {
  try {
    final url = Uri.parse('https://speed.hetzner.de/100MB.bin'); // test file
    final stopwatch = Stopwatch()..start();

    final request = await HttpClient().getUrl(url);
    final response = await request.close();

    int bytes = 0;
    await for (var data in response) {
      bytes += data.length;
    }

    stopwatch.stop();

    double mbps = (bytes * 8) / (stopwatch.elapsedMilliseconds / 1000) / 1000000;
    return mbps;
  } catch (e) {
    return 0.0; // fallback if test fails
  }
}

// ------------------ LoggerScreen ------------------
class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerState();
}

class _LoggerState extends State<LoggerScreen> {
  final _db = AppDB();
  final _matcher = RegionMatcher();

  double? _lat, _lng;
  double? _signalDbm = -1; // placeholder
  double? _downloadMbps;
  String? _netType = "unknown"; // placeholder

  bool _isLoading = false;

  // ------------------ Live readings ------------------
  Future<void> _grabLiveReadings() async {
    setState(() => _isLoading = true);
    try {
      // Get GPS
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get download speed
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

  // ------------------ Log to backend ------------------
  Future<void> _logNow() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No GPS fix yet")),
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

      final res = await http.post(
        Uri.parse("http://10.139.39.204/logCell"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Log synced successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${res.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to sync: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ------------------ Save Region ------------------
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

  // ------------------ Build UI ------------------
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
                Text('GPS: ${_lat?.toStringAsFixed(5) ?? '--'}, ${_lng?.toStringAsFixed(5) ?? '--'}'),
                Text('Signal: ${_signalDbm?.toStringAsFixed(0) ?? '--'} dBm'),
                Text('Speed: ${_downloadMbps?.toStringAsFixed(2) ?? '--'} Mbps'),
                Text('Net: ${_netType ?? '--'}'),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
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
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _isLoading ? null : _logNow,
              icon: const Icon(Icons.save),
              label: const Text('Log now'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isLoading ? null : _saveAsRegionDialog,
              child: const Text('Save this as a region'),
            ),
          ],
        ),
      ),
    );
  }
}
