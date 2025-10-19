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
  List<Marker> _networkMarkers = [];
  bool _isLoading = false;

  final LatLng _futaLocation = LatLng(7.2622, 5.1200); // FUTA, Akure

  @override
  void initState() {
    super.initState();
    _determinePosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNetworkDialog();
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

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

      if (network == "MTN") {
        _networkMarkers = [
          Marker(
            point: _futaLocation,
            width: 50,
            height: 50,
            child: const Icon(
              Icons.location_on,
              color: Colors.green,
              size: 40,
            ),
          ),
        ];
      } else {
        _networkMarkers = [
          Marker(
            point: _futaLocation,
            width: 50,
            height: 50,
            child: const Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ];
      }
}    catch (e) {
      print("Error fetching network data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Uri? _getCoverageUrl() {
    if (_selectedNetwork == "MTN") return Uri.parse("https://coverage.mtn.ng/");
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Retrieve arguments from Navigator
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final LatLng location = args['location'];
    final bool hasLocation = args['hasLocation'];

    return Scaffold(
      appBar: AppBar(
        title: Text(hasLocation ? "Map View (Logged)" : "Map View (Default)"),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: location,
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: location,
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
    );
  }
}
