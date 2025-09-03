import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = true;
  String prediction = "Good";

  LatLng? currentLocation;
  List<LatLng> historyLocations = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // Request permission
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // If denied, keep currentLocation null
      return;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
      historyLocations.add(currentLocation!); // save in history for now
    });
  }

  @override
  Widget build(BuildContext context) {
    // Decide map center
    LatLng initialCenter;
    if (currentLocation != null) {
      initialCenter = currentLocation!;
    } else if (historyLocations.isNotEmpty) {
      initialCenter = historyLocations.last;
    } else {
      initialCenter = const LatLng(6.5244, 3.3792); // Lagos
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Network Predictor"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status section
            Card(
              color: isConnected ? Colors.green[100] : Colors.red[100],
              child: ListTile(
                leading: Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                title: Text(
                  "Network Status: ${isConnected ? "Online" : "Offline"}",
                  style: const TextStyle(fontSize: 18),
                ),
                subtitle: Text("Predicted: $prediction"),
              ),
            ),
            const SizedBox(height: 20),

            // Map
            SizedBox(
              height: 300,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: initialCenter,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Navigation buttons
            ElevatedButton.icon(
              icon: const Icon(Icons.network_check),
              label: const Text("Log Network"),
              onPressed: () {
                Navigator.pushNamed(context, '/logger');
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text("View History"),
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.map),
              label: const Text("View Map"),
              onPressed: () {
                Navigator.pushNamed(context, '/map');
              },
            ),
          ],
        ),
      ),
    );
  }
}
