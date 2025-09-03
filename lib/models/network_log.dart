import 'package:hive/hive.dart';

part 'network_log.g.dart';

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

  NetworkLog({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.signalStrength,
    required this.downloadSpeed,
    required this.uploadSpeed,
  });

  // For converting to JSON when sending to backend
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'signalStrength': signalStrength,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
    };
  }

  // For converting from JSON when receiving from backend
  factory NetworkLog.fromMap(Map<String, dynamic> map) {
    return NetworkLog(
      timestamp: DateTime.parse(map['timestamp']),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      signalStrength: map['signalStrength'] is int
          ? map['signalStrength'] as int
          : (map['signalStrength'] as num).toInt(),
      downloadSpeed: (map['downloadSpeed'] as num).toDouble(),
      uploadSpeed: (map['uploadSpeed'] as num).toDouble(),
    );
  }
}
