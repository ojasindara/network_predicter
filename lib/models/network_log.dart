import 'package:hive/hive.dart';

part 'network_log.g.dart';

@HiveType(typeId: 0)
class NetworkLog {
  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final double latitude;

  @HiveField(2)
  final double longitude;

  @HiveField(3)
  final int signalStrength;

  NetworkLog({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.signalStrength,
  });

  // For converting to JSON when sending to backend
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'signalStrength': signalStrength,
    };
  }

  // For converting from JSON when receiving from backend
  factory NetworkLog.fromMap(Map<String, dynamic> map) {
    return NetworkLog(
      timestamp: DateTime.parse(map['timestamp']),
      latitude: map['latitude'],
      longitude: map['longitude'],
      signalStrength: map['signalStrength'],
    );
  }
}
