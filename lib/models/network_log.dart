import 'package:hive/hive.dart';

part 'network_log.g.dart'; // 👈 Don't forget to rebuild Hive adapters when you add fields

@HiveType(typeId: 0)
class NetworkLog extends HiveObject {
  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final double latitude;

  @HiveField(2)
  final double longitude;

  @HiveField(3)
  final int signalStrength;

  @HiveField(4)
  final double downloadSpeed; // Mbps

  @HiveField(5)
  final double uploadSpeed; // Mbps

  @HiveField(6) // 👈 New field
  final String region;

  NetworkLog({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.signalStrength,
    required this.downloadSpeed,
    required this.uploadSpeed,
    this.region = "", // default empty if not provided
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'signalStrength': signalStrength,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'region': region, // 👈 include region
    };
  }

  factory NetworkLog.fromMap(Map<String, dynamic> map) {
    return NetworkLog(
      timestamp: DateTime.parse(map['timestamp']),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      signalStrength: (map['signalStrength'] as num).toInt(),
      downloadSpeed: (map['downloadSpeed'] as num).toDouble(),
      uploadSpeed: (map['uploadSpeed'] as num).toDouble(),
      region: map['region'] ?? "", // 👈 load region
    );
  }
}
