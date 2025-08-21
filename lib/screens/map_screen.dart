/*
import 'package:flutter/material.dart';
//import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:hive/hive.dart';
import 'package:geolocator/geolocator.dart';
import '../models/network_log.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  // Replace with your actual Mapbox public access token
  static const String mapboxToken = "pk.eyJ1IjoiZGF2aWN0b3Jpb3VzIiwiYSI6ImNtOGZ4NTM0MzBqemgyanNmbTdsMHExOW8ifQ.IShyyHz9myXjsC2AqOzVKg";

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapboxMapController _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Network Map")),
      body: MapboxMap(
        accessToken: MapScreen.mapboxToken,
        initialCameraPosition: const CameraPosition(
          target: LatLng(6.5244, 3.3792), // Lagos default
          zoom: 12,


      ),
        onMapCreated: _onMapCreated,
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMapController controller) async {
    _mapController = controller;

    LatLng targetLocation = const LatLng(6.5244, 3.3792); // Default to Lagos
    double zoomLevel = 14.0;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.deniedForever && serviceEnabled) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        targetLocation = LatLng(position.latitude, position.longitude);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Showing default location (Lagos). Enable location for accurate view."),
          ),
        );
      }

    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to get location. Using default view (Lagos)."),
        ),
      );
    }

    // Move camera to user's or default location
    await _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(targetLocation, zoomLevel),
    );

    // Add network log pins
    final logBox = Hive.box<NetworkLog>('networkLogs');
    final logs = logBox.values.toList();

    for (final log in logs) {
      await _mapController.addSymbol(
        SymbolOptions(
          geometry: LatLng(log.latitude, log.longitude),
          iconImage: "marker-15",
          iconColor: _getColor(log.signalStrength),
          iconSize: 1.5,
        ),
      );
    }
  }

  // Choose pin color based on signal strength
  String _getColor(int strength) {
    if (strength >= 75) return "#2ecc71"; // Green
    if (strength >= 50) return "#f1c40f"; // Yellow
    return "#e74c3c"; // Red
  }
}
*/

import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map Placeholder")),
      body: const Center(
        child: Text("Map screen temporarily disabled"),
      ),
    );
  }
}
