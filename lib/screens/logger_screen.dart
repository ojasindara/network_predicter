import 'package:flutter/material.dart';
import '../data/db.dart';
import '../data/region_matcher.dart';
import 'dart:convert'; // <-- needed for jsonEncode
import 'package:http/http.dart' as http;

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerState();
}

class _LoggerState extends State<LoggerScreen> {
  final _db = AppDB();
  final _matcher = RegionMatcher();

  double? _lat, _lng;
  double? _signalDbm;
  double? _downloadMbps; // set this if you measure throughput
  String? _netType;

  bool _isLoading = false;

  Future<void> _grabLiveReadings() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with actual GPS + signal fetching logic
      // For now, just dummy values to prevent null errors
      await Future.delayed(const Duration(seconds: 1)); // simulate delay
      setState(() {
        _lat = 6.5244; // Example: Lagos lat
        _lng = 3.3792; // Example: Lagos lng
        _signalDbm = -85;
        _netType = "4G";
        _downloadMbps = 12.5;
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

  Future<void> _logNow() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No GPS fix yet")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Find nearest region
      final match = await _matcher.findNearest(_lat!, _lng!);

      // Save locally first
      await _db.insertLog(
        ts: DateTime.now(),
        lat: _lat!,
        lng: _lng!,
        signalDbm: _signalDbm,
        downloadMbps: _downloadMbps,
        netType: _netType,
        regionId: match?.regionId,
      );


      // Build payload for backend
      final payload = {
        'ts': DateTime.now().toIso8601String(),
        'lat': _lat ?? 0.0,
        'lng': _lng ?? 0.0,
        'signal_dbm': _signalDbm ?? 0.0,
        'download_mbps': _downloadMbps ?? 0.0,
        'net_type': _netType ?? 'unknown',
        'region_id': match?.regionId,  // correct casing
        'region_name': match?.name,
      };

      final res = await http.post(
        Uri.parse("http://10.0.2.2:3000/logCell"), // your backend endpoint
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAsRegionDialog() async {
    if (_lat == null || _lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ No GPS data to save")),
      );
      return;
    }

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
              decoration: const InputDecoration(
                labelText: 'Region name (e.g., My Room)',
              ),
            ),
            TextField(
              controller: radiusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Match radius (meters)',
              ),
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
            // show live readings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GPS: ${_lat?.toStringAsFixed(5) ?? '--'}, ${_lng?.toStringAsFixed(5) ?? '--'}'),
                Text('Signal: ${_signalDbm?.toStringAsFixed(0) ?? '--'} dBm'),
                Text('Speed: ${_downloadMbps?.toStringAsFixed(2) ?? '--'} Mbps'),
              ],
            ),
            const SizedBox(height: 12),

            // Buttons with loader state
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
