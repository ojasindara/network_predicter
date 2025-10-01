import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../data/db.dart' as db;
import '../models/network_log.dart';
import '../data/app_db.dart';


class LoggerProvider extends ChangeNotifier {
  final AppDB _db = AppDB();

  List<NetworkLog> _logs = [];
  List<NetworkLog> get logs => _logs;

  bool _isLogging = false;
  bool get isLogging => _isLogging;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  /// Initialize provider: load existing logs
  Future<void> init() async {
    _logs = await _db.getAllLogs();
    notifyListeners();
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
  }) async {
    if (_isLogging) return;

    _isLogging = true;
    notifyListeners();

    try {
      final log = NetworkLog(
        timestamp: DateTime.now(),
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        signalStrength: signalStrength,
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
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
