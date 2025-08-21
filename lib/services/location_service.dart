import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    // Step 1: Check if location services are on
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them in settings.');
    }

    // Step 2: Check permission
    LocationPermission permission = await Geolocator.checkPermission();

    // Step 3: Request permission if denied
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      // Check again if still denied
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }
    }

    // Step 4: Handle permanently denied
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied. Please enable it in app settings.');
    }

    // Step 5: Get and return position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}

