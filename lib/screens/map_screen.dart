import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/logger_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../providers/logger_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 0;

  LatLng initialCenter = LatLng(7.3066, 5.1376); // default FUTA, Akure
  bool hasLocation = false;
  String currentRegionName = "Fetching location name...";
  String? currentStreetName;
  Marker? currentLocationMarker;
  String? _selectedNetwork;
  List<Marker> _networkMarkers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNetworkDialog();
    });
    context.read<LoggerProvider>().init();
  }

  // ======= Debug-enabled location fetching =======
  Future<void> _determinePosition() async {
    try {
      print("[DEBUG] Checking if location services are enabled...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("[DEBUG] Location services are disabled. Opening settings...");
        await Geolocator.openLocationSettings();
        return;
      }

      print("[DEBUG] Checking location permissions...");
      LocationPermission permission = await Geolocator.checkPermission();
      print("[DEBUG] Current permission: $permission");

      if (permission == LocationPermission.denied) {
        print("[DEBUG] Requesting location permission...");
        permission = await Geolocator.requestPermission();
        print("[DEBUG] Permission after request: $permission");
        if (permission == LocationPermission.denied) {
          print("[DEBUG] User denied permission.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("[DEBUG] Permission denied forever. Opening app settings...");
        await Geolocator.openAppSettings();
        return;
      }

      print("[DEBUG] Attempting to get current position...");
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        );
        print("[DEBUG] Position obtained: lat=${position.latitude}, lon=${position.longitude}");
      } catch (e) {
        print("[DEBUG] Error fetching position: $e");
        return;
      }

      // Reverse geocode
      try {
        print("[DEBUG] Performing reverse geocoding...");
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        String street = placemarks.isNotEmpty ? (placemarks.first.street ?? "Unknown Street") : "Unknown Street";
        print("[DEBUG] Reverse geocoding result: $street");

        setState(() {
          initialCenter = LatLng(position.latitude, position.longitude);
          hasLocation = true;
          currentStreetName = street;
          currentLocationMarker = Marker(
            width: 50,
            height: 50,
            point: LatLng(position.latitude, position.longitude),
            child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
          );
        });

        // Update provider
        context.read<LoggerProvider>().updateLocation(position);
      } catch (e) {
        print("[DEBUG] Reverse geocoding failed: $e");
        setState(() {
          currentRegionName = "Unknown area";
        });
      }
    } catch (e) {
      print("[DEBUG] _determinePosition failed unexpectedly: $e");
    }
  }

  // ======= Network selection dialog =======
  Future<void> _showNetworkDialog() async {
    final network = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select your network"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text("MTN"), onTap: () => Navigator.pop(context, "MTN")),
              ListTile(title: const Text("Airtel"), onTap: () => Navigator.pop(context, "Airtel")),
              ListTile(title: const Text("Glo"), onTap: () => Navigator.pop(context, "Glo")),
              ListTile(title: const Text("9mobile"), onTap: () => Navigator.pop(context, "9mobile")),
            ],
          ),
        );
      },
    );

    if (!mounted || network == null) return;

    setState(() {
      _selectedNetwork = network;
    });

    _fetchNetworkData(network);
  }

  Future<void> _fetchNetworkData(String network) async {
    setState(() {
      _isLoading = true;
      _networkMarkers = [];
    });

    try {
      await Future.delayed(const Duration(seconds: 1)); // simulate fetch
      _networkMarkers = [
        Marker(
          point: LatLng(7.2622, 5.1200), // FUTA
          width: 50,
          height: 50,
          child: Icon(
            Icons.location_on,
            color: network == "MTN" ? Colors.green : Colors.blue,
            size: 40,
          ),
        ),
      ];
    } catch (e) {
      print("[DEBUG] Error fetching network data: $e");
    } finally {
      setState(() {
        _isLoading = false;
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
        title: const Text("NETWORK LOGGING, MAPPING AND PREDICTING APP"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    provider.currentPosition?.latitude ?? defaultLat,
                    provider.currentPosition?.longitude ?? defaultLng,
                  ),
                  initialZoom: 15,
                  onTap: (tapPos, point) async {
                    print("[DEBUG] Map tapped at ${point.latitude}, ${point.longitude}");
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      if (currentLocationMarker != null) currentLocationMarker!,
                      ..._networkMarkers,
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text(provider.currentStreetName)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.network_check), label: 'Log Network'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

