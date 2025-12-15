import 'dart:convert';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/logger_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http; // for API calls
import 'package:url_launcher/url_launcher.dart'; // for opening your API link
import 'package:geocoding/geocoding.dart'; // NEW for reverse geocoding

/// Existing models and functions unchanged...

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class PredictedLocation {
  final String name;
  final double latitude;
  final double longitude;
  final double avgDownload;
  final double avgUpload;

  PredictedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.avgDownload,
    required this.avgUpload,
  });

  factory PredictedLocation.fromJson(Map<String, dynamic> json) {
    return PredictedLocation(
      name: json['name'] ?? 'Unknown',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      avgDownload: json['avg_download']?.toDouble() ?? 0.0,
      avgUpload: json['avg_upload']?.toDouble() ?? 0.0,
    );
  }
}

Future<List<PredictedLocation>> loadAverageValues() async {
  try {
    // Load the JSON file from assets
    final jsonString = await rootBundle.loadString('assets/predicted_locations.json');
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    // Convert JSON list into PredictedLocation objects
    return jsonList.map((item) => PredictedLocation.fromJson(item)).toList();
  } catch (e) {
    debugPrint("Error loading predicted locations: $e");
    return [];
  }
}


Future<List<PredictedLocation>> getTopPredictedLocations(provider, {int top = 6}) async {
  try {
    // Load all predicted locations
    final allLocations = await loadAverageValues();

    // Sort them by download speed (or any metric you prefer)
    allLocations.sort((a, b) => b.avgDownload.compareTo(a.avgDownload));

    // Return only the top N results
    return allLocations.take(top).toList();
  } catch (e) {
    debugPrint("Error getting top predicted locations: $e");
    return [];
  }
}


class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Default FUTA, Akure
  LatLng initialCenter = LatLng(7.3066, 5.1376);
  bool hasLocation = false;

  // ✅ Variable to hold readable region/street name
  String currentRegionName = "Fetching location name...";
  String currentStreetName = '';


  Marker? currentLocationMarker; // NEW


  @override
  void initState() {
    super.initState();
    final provider = context.read<LoggerProvider>();
    provider.init();
    provider.fetchAndUpdateLocation();
  }

  Future<Map<String, dynamic>> _runLocalPrediction(LoggerProvider provider) async {
    try {
      final position = provider.currentPosition;
      if (position == null) {
        throw Exception("Location not available.");
      }

      final lastSignal = provider.logs.isNotEmpty
          ? provider.logs.last.signalStrength ?? -85
          : -85;

      final now = DateTime.now();
      final hour = now.hour;
      final weekday = now.weekday - 1;

      final hourSin = sin(2 * pi * hour / 24);
      final hourCos = cos(2 * pi * hour / 24);

      // INPUT must be List<double>
      final input = [
        lastSignal.toDouble(),
        position.latitude,
        position.longitude,
        hourSin,
        hourCos,
        weekday.toDouble(),
      ];

      final interpreter =
      await Interpreter.fromAsset('models/network_predictor.tflite');

      try {
        // output buffer (1 batch, 1 prediction)
        List<List<double>> output = List.generate(
          1,
              (_) => List.filled(1, 0.0),
        );

        // Run inference
        interpreter.run(input, output);

        // Clean up
        interpreter.close();

        final prediction = max(0.0, output[0][0]);

        // 🔥 IMPORTANT: Return a MAP because your function requires it
        return {
          "prediction": prediction,
          "signal": lastSignal,
          "lat": position.latitude,
          "lng": position.longitude,
          "hour": hour,
          "weekday": weekday,
        };

      } catch (e) {
        throw Exception("Local prediction error: $e");
      }
    } catch (e) {
      throw Exception("Prediction run failed: $e");
    }
  }


  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );

    // 🗺️ Reverse geocode to get street name
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude ?? 7.3066, position.longitude?? 5.1376);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          currentStreetName = place.street ?? '';
        });
        print("Address: ${place.street}, ${place.locality}");
      }
    } catch (e) {
      print("Failed to get address: $e");
    }


    setState(() {
      initialCenter = LatLng(position.latitude, position.longitude);
      hasLocation = true;

      currentLocationMarker = Marker( // NEW
        width: 50,
        height: 50,
        point: LatLng(position.latitude, position.longitude),
        child: const Icon(
          Icons.my_location,
          color: Colors.blue,
          size: 40,
        ),
      );
    });

    // Update provider
    context.read<LoggerProvider>().updateLocation(position);
  }


  // ✅ Reverse geocoding method to get readable street/region name
  Future<void> _getReadableLocation(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          // Try to make the name more human-friendly
          currentRegionName = p.street?.isNotEmpty == true
              ? p.street!
              : (p.subLocality?.isNotEmpty == true
              ? p.subLocality!
              : p.locality ?? "Unknown area");
        });
      } else {
        setState(() {
          currentRegionName = "Unknown area";
        });
      }
    } catch (e) {
      print("Error getting location name: $e");
      setState(() {
        currentRegionName = "Error getting location name";
      });
    }
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
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .primary,
        actions: [
          IconButton(
            tooltip: 'Refresh predictions',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🗺️ Map section
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          provider.currentPosition?.latitude ?? 7.3066,
                          provider.currentPosition?.longitude ?? 5.1376,
                        ),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                          subdomains: ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            if (provider.currentPosition != null)
                              Marker(
                                width: 50,
                                height: 50,
                                point: LatLng(
                                  provider.currentPosition?.latitude ?? 7.3066,
                                  provider.currentPosition?.longitude ?? 5.1376,
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              ),
                            ...provider.logs.map(
                                  (log) =>
                                  Marker(
                                    width: 40,
                                    height: 40,
                                    point: LatLng(log.latitude ?? 7.3066, log.longitude ?? 5.1376),
                                    child: const Icon(
                                      Icons.place,
                                      color: Colors.green,
                                      size: 40,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                        Center(
                          child: Text(
                            provider.currentStreetName,
                            style: Theme
                                .of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🌐 Current Location Prediction (auto-refreshes every 30s)
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(seconds: 30), (x) => x),
                  builder: (context, _) {
                    final provider = Provider.of<LoggerProvider>(context, listen: true);
                    return FutureBuilder<Map<String, dynamic>>(
                      future: _runLocalPrediction(provider),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Card(
                            color: Colors.red[50],
                            child: ListTile(
                              leading: const Icon(Icons.error, color: Colors.red),
                              title: const Text("Prediction Error"),
                              subtitle: Text(snapshot.error.toString()),
                            ),
                          );
                        } else if (!snapshot.hasData) {
                          return const SizedBox();
                        }

                        final prediction = snapshot.data!;
                        final region = prediction['region'] ?? 'Current Area';
                        final predictedSpeed = prediction['predicted_speed'] ?? 'N/A';
                        final signal = prediction['signal_dbm'] ?? provider.lastSignalStrength ?? 'N/A';

                        return Card(
                          color: Colors.blue[50],
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.blue),
                            title: Text(
                              "Predicted Network Quality for $region",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Signal: $signal dBm\nPredicted Speed: $predictedSpeed Mbps\nPredicted Quality: Good",
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.blue),
                              tooltip: "Refresh Prediction",
                              onPressed: () {
                                // Manually trigger a rebuild
                                (context as Element).markNeedsBuild();
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),


                // 📍 Predicted Good Regions
                const Text(
                  "Predicted Good Regions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                FutureBuilder<List<PredictedLocation>>(
                  future: getTopPredictedLocations(provider, top: 10),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text('No locations logged yet.'));
                    } else {
                      final topLocations = snapshot.data!;
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: topLocations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final loc = topLocations[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                  Icons.place, color: Colors.green),
                              title: Text(
                                loc.name,
                                style:
                                const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Download: ${loc.avgDownload.toStringAsFixed(
                                    2)} Mbps | '
                                    'Upload: ${loc.avgUpload.toStringAsFixed(
                                    2)} Mbps',
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    provider.currentStreetName ?? "Locating...",
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
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
