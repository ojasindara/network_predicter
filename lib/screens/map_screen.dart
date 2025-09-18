import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLocation;
  String? _selectedNetwork;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNetworkDialog();
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(pos.latitude, pos.longitude);
    });
  }

  void _showNetworkDialog() async {
    final network = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select your network"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("MTN"),
                onTap: () => Navigator.pop(context, "MTN"),
              ),
              ListTile(
                title: const Text("Airtel"),
                onTap: () => Navigator.pop(context, "Airtel"),
              ),
              ListTile(
                title: const Text("Glo"),
                onTap: () => Navigator.pop(context, "Glo"),
              ),
              ListTile(
                title: const Text("9mobile"),
                onTap: () => Navigator.pop(context, "9mobile"),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _selectedNetwork = network;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedNetwork == null || _currentLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$_selectedNetwork Coverage"),
        actions: [
          IconButton(
            icon: const Icon(Icons.network_wifi),
            onPressed: _showNetworkDialog,
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _currentLocation!,
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation!,
                width: 50,
                height: 50,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

