import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/network_log.dart';

/// A robust logger for continuous monitoring of traffic, location, and signal strength.
class LoggerService {
  static const EventChannel _trafficChannel = EventChannel('netspeed_channel');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription? _trafficSub;
  static DateTime? _lastLocationFetch;
  static Position? _cachedPosition;

  /// Starts listening to system traffic stream and logs data
  static void startLogging(void Function(NetworkLog log) onUpdate) {
    _trafficSub = _trafficChannel.receiveBroadcastStream().listen(
          (event) async {
        try {
          final data = Map<String, dynamic>.from(event);
          final download = (data['download_kb_s'] ?? 0).toDouble();
          final upload = (data['upload_kb_s'] ?? 0).toDouble();

          final now = DateTime.now();

          // Throttle GPS updates (every 10s)
          if (_lastLocationFetch == null ||
              now.difference(_lastLocationFetch!) > const Duration(seconds: 10)) {
            final pos = await _safeGetPosition();
            if (pos != null) {
              _cachedPosition = pos;
              await _cacheLastLocation(pos); // save to Hive
            } else {
              _cachedPosition ??= await _getCachedLocation();
            }
            _lastLocationFetch = now;
          } else {
            _cachedPosition ??= await _getCachedLocation();
          }

          final signal = await _safeGetSignalStrength();

          final log = NetworkLog(
            downloadSpeed: download,
            uploadSpeed: upload,
            signalStrength: signal.toInt(),
            latitude: _cachedPosition?.latitude ?? 0.0,
            longitude: _cachedPosition?.longitude ?? 0.0,
            timestamp: now,
          );

          onUpdate(log);
          await _persistLog(log);
        } catch (e) {
          print('LoggerService error: $e');
        }
      },
      onError: (error) => print('Traffic channel error: $error'),
    );
  }

  static void stopLogging() => _trafficSub?.cancel();

  /// For WorkManager background logging
  static Future<void> logNowBackground() async {
    try {
      final pos = await _safeGetPosition() ?? await _getCachedLocation();
      final signal = await _safeGetSignalStrength();

      final log = NetworkLog(
        downloadSpeed: 0.0,
        uploadSpeed: 0.0,
        signalStrength: signal.toInt(),
        latitude: pos?.latitude ?? 0.0,
        longitude: pos?.longitude ?? 0.0,
        timestamp: DateTime.now(),
      );

      await _persistLog(log);
    } catch (e) {
      print('Background log failed: $e');
    }
  }

  // ----------------- Helpers -----------------

  static Future<Position?> _safeGetPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<double> _safeGetSignalStrength() async {
    try {
      final plugin = FlutterInternetSignal();
      final mobileStrength = await plugin.getMobileSignalStrength();
      if (mobileStrength != null) {
        return mobileStrength.toDouble();
      }
      // fallback to WiFi if needed
      final wifiInfo = await plugin.getWifiSignalInfo();
      if (wifiInfo?.dbm != null) {
        return wifiInfo!.dbm!.toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting signal strength: $e');
      return 0.0;
    }
  }



  static Future<void> _persistLog(NetworkLog log) async {
    final box = Hive.box<NetworkLog>('networkLogs');
    await box.add(log);

    try {
      await _firestore.collection('speed_logs').add({
        'download': log.downloadSpeed,
        'upload': log.uploadSpeed,
        'latitude': log.latitude,
        'longitude': log.longitude,
        'signalStrength': log.signalStrength,
        'timestamp': log.timestamp.toIso8601String(),
      });
    } catch (_) {
      // ignore write failures if offline
    }
  }

  // Save last location to Hive box
  static Future<void> _cacheLastLocation(Position pos) async {
    final box = await Hive.openBox('lastLocation');
    await box.put('latitude', pos.latitude);
    await box.put('longitude', pos.longitude);
  }

  // Retrieve last known location from Hive
  static Future<Position?> _getCachedLocation() async {
    final box = await Hive.openBox('lastLocation');
    final lat = box.get('latitude');
    final lon = box.get('longitude');
    if (lat != null && lon != null) {
      return Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        headingAccuracy: 1.0,     // ✅ new required parameter
        altitudeAccuracy: 1.0,    // ✅ new required parameter
      );
    }
    return null;
  }
}
