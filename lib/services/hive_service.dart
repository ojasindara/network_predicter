import 'package:hive/hive.dart';
import '../models/network_log.dart';

class HiveService {
  static Future<void> saveLog(NetworkLog log) async {
    final box = await Hive.openBox('network_logs');
    await box.add(log.toMap());
  }

  static Future<List<NetworkLog>> getLogs() async {
    final box = await Hive.openBox('network_logs');
    return box.values.map((e) => NetworkLog.fromMap(Map<String, dynamic>.from(e))).toList();
  }
}
