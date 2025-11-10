import 'dart:async';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/network_log.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Handles Android service data streaming, Hive storage, and Supabase sync
class LoggerService {
  static const EventChannel _trafficChannel = EventChannel('netspeed_channel');
  static final SupabaseClient supabase = Supabase.instance.client;
  static StreamSubscription? _trafficSub;
  static bool _isSaving = false;

  static final StreamController<NetworkLog> _logController =
  StreamController<NetworkLog>.broadcast();

  static Stream<NetworkLog> get logStream => _logController.stream;

  /// Start the Kotlin background listener
  static StreamSubscription<NetworkLog> startLogging(void Function(NetworkLog log) onUpdate) {

  print("LoggerService: Starting to listen for Kotlin logs...");
  final controller = StreamController<NetworkLog>();


  _trafficSub = _trafficChannel.receiveBroadcastStream().listen(
          (event) async {
        try {
          final data = Map<String, dynamic>.from(event);

          // Defensive parsing
          final timestampMs = (data['timestamp'] is int)
              ? data['timestamp'] as int
              : int.tryParse(data['timestamp'].toString()) ??
              DateTime.now().millisecondsSinceEpoch;

          // Convert KB → MB
          final downloadMb = ((data['downloadKb'] ?? 0).toDouble()) / 1024.0;
          final uploadMb = ((data['uploadKb'] ?? 0).toDouble()) / 1024.0;

          final regionB = (data['region'] ?? 'home');

          final log = NetworkLog(
            downloadKb: downloadMb,
            uploadKb: uploadMb,
            signalStrength: (data['signalStrength'] ?? 0).toInt(),
            latitude: (data['latitude'] ?? 0.0).toDouble(),
            longitude: (data['longitude'] ?? 0.0).toDouble(),
            weather: data['weather'] ?? '',
            temperature: (data['temperature'] ?? 0.0).toDouble(),
            timestamp: timestampMs,
            region: regionB
          );

          print("LoggerService: Log created -> $log");

          _logController.add(log);
          await _persistLog(log);
          onUpdate(log); // <— VERY important, tells LoggerScreen about new data
        } catch (e, st) {
          print('LoggerService error: $e\n$st');
        }
      },
      onError: (error) => print('Traffic channel error: $error'),
    );
  // Return a proper StreamSubscription<NetworkLog>
  return controller.stream.listen((event) {});// <— Return actual subscription, not a dummy controller
  }

  /// Initialize Hive
  static Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen('networkLogs')) {
        await Hive.openBox<NetworkLog>('networkLogs');
      }
      print("LoggerService: Hive initialized successfully.");
    } catch (e, st) {
      print("LoggerService initialization error: $e\n$st");
    }
  }

  /// Stop Kotlin listener and stream
  static void stopLogging() {
    _trafficSub?.cancel();
    print("LoggerService: Stopped logging.");
  }

  /// Persist logs locally and sync to Supabase
  static Future<void> _persistLog(NetworkLog log) async {
    final box = Hive.box<NetworkLog>('networkLog');
    await box.add(log);
    print("LoggerService: Log added to Hive -> $log");

    if (_isSaving) return;
    _isSaving = true;

    try {
      await Future.delayed(const Duration(seconds: 10));

      final unsynced = box.values.take(4).toList();
      for (final entry in unsynced) {
        final lat = entry.latitude ?? 0.0;
        final lon = entry.longitude ?? 0.0;

        await supabase.from('speed_logs').insert({
          'download': entry.downloadKb,
          'upload': entry.uploadKb,
          'latitude': lat,
          'longitude': lon,
          'signal_strength': entry.signalStrength ?? 0,
          'weather': entry.weather,
          'temperature': entry.temperature,
          'timestamp': entry.timestamp,
          'Region': entry.region,
        });
      }

      print("LoggerService: Synced ${unsynced.length} logs to Supabase.");
    } catch (e, st) {
      print("LoggerService: Error syncing to Supabase: $e\n$st");
    } finally {
      _isSaving = false;
    }
  }

  /// (Optional) Get device location — useful for future enhancements
  static Future<LatLng?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print("Geolocator error: $e");
      return null;
    }
  }
}
