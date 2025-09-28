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
  int _selectedIndex = 0;

  // Default FUTA, Akure
  LatLng initialCenter = LatLng(7.3066, 5.1376);
  bool hasLocation = false; // track if location is available

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if GPS is ON
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Default to FUTA
      return;
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Still denied → fallback FUTA
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Cannot request anymore → fallback FUTA
      return;
    }

    // If we reach here → Location is available
    Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, // can also use best, medium, low
          distanceFilter: 0,               // update whenever device moves
        ),
    );

    setState(() {
      initialCenter = LatLng(position.latitude, position.longitude);
      hasLocation = true;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Pass location state to other pages
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("A SYSTEM FOR INTERNET AVAILABILITY DATA LOGGING, MAPPING AND PREDICTION"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          // Map widget
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
                    urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: initialCenter,
                        width: 40,
                        height: 40,
                        child: Icon(
                          hasLocation ? Icons.my_location : Icons.location_pin,
                          color: hasLocation ? Colors.blue : Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Center(
              child: Text(
                hasLocation
                    ? "Using your current location"
                    : "Using FUTA as default (No logs saved)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
