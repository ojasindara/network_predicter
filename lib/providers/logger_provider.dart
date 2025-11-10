import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/network_log.dart';
import '../services/logger_service.dart';
import '../data/app_db.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LoggerProvider extends ChangeNotifier {
  final AppDB _db = AppDB();

  List<NetworkLog> _logs = [];

  String get currentStreetName => _currentStreetName;

  void updateStreetName(String name) {
    _currentStreetName = name;
    notifyListeners();
  }


  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;
  String _currentStreetName = "Home";
  List<NetworkLog> get logs => _logs;
  int? _lastSignalStrength; // private variable
  int? get lastSignalStrength => _lastSignalStrength; // public getter


  bool _isLogging = false;
  bool get isLogging => _isLogging;

  Future<void> updatePosition(Position position) async {
    _currentPosition = position;
    notifyListeners();
  }


  /// Initialize provider: load existing logs
  Future<void> init() async {
    _logs = await _db.getAllLogs();
    notifyListeners();
  }

  Future<void> fetchAndUpdateLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    _currentPosition = position;
    await _updateReadableAddress();
    notifyListeners();
  }

  Future<void> _updateReadableAddress() async {
    if (_currentPosition == null) return;
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _currentStreetName =
        p.street?.isNotEmpty == true ? p.street! : (p.locality ?? "Futa");
      }
    } catch (_) {
      _currentStreetName = "Unknown";
    }
    notifyListeners();
  }


  Future<void> startListening() async {
    await LoggerService.initialize();
    await LoggerService.startLogging((log) {
      _logs.add(log);
      _lastSignalStrength = log.signalStrength;
      notifyListeners();
    });

    LoggerService.logStream.listen((log) async {
      await logNetwork(
        signalStrength: log.signalStrength ?? -90,
        downloadSpeed: log.downloadKb,
        uploadSpeed: log.uploadKb,
        weather: log.weather ?? '',
        temperature: log.temperature ?? 0.0,
      );
    });
  }


  /// Update current device location
  void updateLocation(Position position) {
    _currentPosition = position;
    notifyListeners();
  }

  /// Log network data
  Future<void> logNetwork({
    required int signalStrength,
    required double downloadSpeed,
    required double uploadSpeed,
    String weather = '',
    double temperature = 0.0,
  }) async {
    if (_isLogging) return;

    _isLogging = true;
    notifyListeners();

    try {
      final log = NetworkLog(
        timestamp: DateTime.now().millisecondsSinceEpoch, // ✅ int
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        signalStrength: signalStrength,
        downloadKb: downloadSpeed,
        uploadKb: uploadSpeed,
        weather: weather,
        temperature: temperature,
        region: _currentStreetName,
      );

      await _db.insertLog(log);
      _logs.add(log);
      notifyListeners();
    } finally {
      _isLogging = false;
      notifyListeners();
    }
  }
}
