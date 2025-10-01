import 'package:hive/hive.dart';
import '../models/network_log.dart';

class AppDB {
  static const String boxName = 'network_logs';

  /// Open the Hive box (call this at app startup)
  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<NetworkLog>(boxName);
    }
  }

  /// Get all saved logs
  Future<List<NetworkLog>> getAllLogs() async {
    final box = Hive.box<NetworkLog>(boxName);
    return box.values.toList();
  }

  /// Insert a new log
  Future<void> insertLog(NetworkLog log) async {
    final box = Hive.box<NetworkLog>(boxName);
    await box.add(log);
  }
}
