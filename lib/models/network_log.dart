import 'package:hive/hive.dart';

part 'network_log.g.dart';

@HiveType(typeId: 0)
class NetworkLog extends HiveObject {
  @HiveField(0)
  final double downloadKb;

  @HiveField(1)
  final double uploadKb;

  @HiveField(2)
  final int? signalStrength;

  @HiveField(3)
  final double? latitude;

  @HiveField(4)
  final double? longitude;

  @HiveField(5)
  final String? weather;

  @HiveField(6)
  final double? temperature;

  @HiveField(7)
  final int timestamp; // Using millisecondsSinceEpoch like Kotlin Long

  @HiveField(8)
  final String? region;

  NetworkLog({
    required this.downloadKb,
    required this.uploadKb,
    this.signalStrength,
    this.latitude,
    this.longitude,
    this.weather,
    this.temperature,
    required this.timestamp,
    this.region
  });

  /// Convert to Map for Supabase
  Map<String, dynamic> toMap() {
    return {
      'download_kb': downloadKb,
      'upload_kb': uploadKb,
      'signal_strength': signalStrength,
      'latitude': latitude,
      'longitude': longitude,
      'weather': weather,
      'temperature': temperature,
      'timestamp': timestamp,
      'Region': region
    };
  }

  /// Create instance from Map (Supabase query)
  factory NetworkLog.fromMap(Map<String, dynamic> map) {
    return NetworkLog(
      downloadKb: (map['download_kb'] as num).toDouble(),
      uploadKb: (map['upload_kb'] as num).toDouble(),
      signalStrength: map['signal_strength'] != null ? (map['signal_strength'] as num).toInt() : null,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      weather: map['weather'] as String?,
      temperature: map['temperature'] != null ? (map['temperature'] as num).toDouble() : null,
      timestamp: map['timestamp'] as int,
      region: map['Region'] as String?,
    );
  }
}
