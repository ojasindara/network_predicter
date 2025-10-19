import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/logger_provider.dart';

/// Unified model used for both JSON averages and local logs
class PredictedLocation {
  final String name;
  final double latitude;
  final double longitude;
  final double download;
  final double upload;

  PredictedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.download,
    required this.upload,
  });
}

/// Loads the static averages JSON from assets/predicted_averages.json
Future<List<PredictedLocation>> loadAverageValues() async {
  final jsonString = await rootBundle.loadString('assets/predicted_locations.json');
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

  return jsonList.map((e) {
    final map = e as Map<String, dynamic>;
    return PredictedLocation(
      name: map['name'] ?? 'Unknown',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      download: (map['avg_download'] ?? 0).toDouble(),
      upload: (map['avg_upload'] ?? 0).toDouble(),
    );
  }).toList();
}

/// Converts local provider logs into PredictedLocation entries safely
List<PredictedLocation> getLocalLogsAsPredicted(LoggerProvider provider) {
  final List<PredictedLocation> result = [];
  final logs = provider.logs ?? <dynamic>[];

  for (var i = 0; i < logs.length; i++) {
    final log = logs[i];

    double readDouble(dynamic src, List<String> keys, {double fallback = 0.0}) {
      try {
        if (src == null) return fallback;
        // If it's a Map
        if (src is Map) {
          for (final k in keys) {
            final v = src[k];
            if (v is num) return v.toDouble();
          }
        }
        // If it has properties (model class)
        for (final k in keys) {
          try {
            final v = src?.toJson != null ? src.toJson()[k] : null;
            if (v is num) return v.toDouble();
          } catch (_) {}
          try {
            final v = src?.latitude != null && k == 'latitude' ? src.latitude : null;
            if (v is num) return v.toDouble();
          } catch (_) {}
          try {
            final v = src?.longitude != null && k == 'longitude' ? src.longitude : null;
            if (v is num) return v.toDouble();
          } catch (_) {}
          try {
            final v = src?.download != null && k == 'download' ? src.download : null;
            if (v is num) return v.toDouble();
          } catch (_) {}
          try {
            final v = src?.upload != null && k == 'upload' ? src.upload : null;
            if (v is num) return v.toDouble();
          } catch (_) {}
        }
      } catch (_) {}
      return fallback;
    }

    final lat = readDouble(log, ['latitude', 'lat', 'latLng', 'locationLatitude'], fallback: 0.0);
    final lng = readDouble(log, ['longitude', 'lng', 'lon', 'locationLongitude'], fallback: 0.0);

    // speed fields
    double download = readDouble(log, ['download', 'downloadSpeed', 'dlspeed', 'speed_download'], fallback: 0.0);
    double upload = readDouble(log, ['upload', 'uploadSpeed', 'ulspeed', 'speed_upload'], fallback: 0.0);

    // name
    String name = 'Saved location ${i + 1}';
    try {
      if (log is Map && log['name'] is String && (log['name'] as String).isNotEmpty) {
        name = log['name'] as String;
      } else if (log?.name is String && (log.name as String).isNotEmpty) {
        name = log.name as String;
      }
    } catch (_) {}

    if (lat != 0.0 || lng != 0.0) {
      result.add(PredictedLocation(name: name, latitude: lat, longitude: lng, download: download, upload: upload));
    }
  }

  return result;
}

/// Combines JSON averages with local logs. Local logs are only included if
/// their download speed is greater than the maximum download present in the JSON.
Future<List<PredictedLocation>> getTopPredictedLocations(LoggerProvider provider, {int top = 10}) async {
  final jsonLocations = await loadAverageValues();
  final localLogs = getLocalLogsAsPredicted(provider);

  final maxJsonDownload = jsonLocations.isNotEmpty ? jsonLocations.map((e) => e.download).reduce((a, b) => a > b ? a : b) : 0.0;

  final highLocalLogs = localLogs.where((log) => log.download > maxJsonDownload).toList();

  final combined = <PredictedLocation>[];
  combined.addAll(jsonLocations);
  combined.addAll(highLocalLogs);

  combined.sort((a, b) => b.download.compareTo(a.download));

  return combined.take(top).toList();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Default FUTA, Akure
  LatLng initialCenter = LatLng(7.3066, 5.1376);
  bool hasLocation = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    // Initialize provider logs
    context.read<LoggerProvider>().init();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Prompt user to enable location
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) {
      // User must enable manually in settings
      await Geolocator.openAppSettings();
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );

    setState(() {
      initialCenter = LatLng(position.latitude, position.longitude);
      hasLocation = true;
    });

    // Update provider
    context.read<LoggerProvider>().updateLocation(position);
  }
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushNamed(
          context,
          '/logger',
          arguments: {
            'location': initialCenter,
            'hasLocation': hasLocation,
          },
        );
        break;
      case 1:
        Navigator.pushNamed(context, '/history');
        break;
      case 2:
        Navigator.pushNamed(
          context,
          '/map',
          arguments: {
            'location': initialCenter,
            'hasLocation': hasLocation,
          },
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoggerProvider>();
    final defaultLat = 7.3066;
    final defaultLng = 5.1376;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "NETWORK LOGGING, MAPPING AND PREDICTING APP",
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            tooltip: 'Refresh predictions',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map showing all logged locations
          SizedBox(
            height: 300,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    provider.currentPosition?.latitude ?? defaultLat,
                    provider.currentPosition?.longitude ?? defaultLng,
                  ),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: (provider.logs ?? <dynamic>[]).map((log) {
                      double lat = 0.0;
                      double lng = 0.0;
                      try {
                        if (log is Map) {
                          lat = (log['latitude'] ?? log['lat'] ?? defaultLat).toDouble();
                          lng = (log['longitude'] ?? log['lng'] ?? defaultLng).toDouble();
                        } else {
                          lat = (log.latitude ?? defaultLat).toDouble();
                          lng = (log.longitude ?? defaultLng).toDouble();
                        }
                      } catch (_) {
                        lat = defaultLat;
                        lng = defaultLng;
                      }

                      return Marker(
                        width: 40,
                        height: 40,
                        point: LatLng(lat, lng),
                        child: const Icon(
                          Icons.place,
                          color: Colors.green,
                          size: 40,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Predicted Good Regions (hybrid: JSON + high local logs)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Predicted Good Regions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: FutureBuilder<List<PredictedLocation>>(
                      future: getTopPredictedLocations(provider, top: 10),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('No locations logged yet.'));
                        } else {
                          final topLocations = snapshot.data!;
                          return ListView.separated(
                            itemCount: topLocations.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final loc = topLocations[index];
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  leading: const Icon(Icons.place, color: Colors.green),
                                  title: Text(
                                    loc.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Download: ${loc.download.toStringAsFixed(2)} Mbps | '
                                        'Upload: ${loc.upload.toStringAsFixed(2)} Mbps',
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Current location info
                Center(
                  child: Text(
                    hasLocation
                        ? "Using your current location"
                        : "Using approximate location",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.network_check),
            label: 'Log Network',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onItemTapped,
      ),
    );
  }
}
