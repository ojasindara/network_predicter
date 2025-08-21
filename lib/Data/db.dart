import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDB {
  static final AppDB _i = AppDB._();
  AppDB._();
  factory AppDB() => _i;

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'netpredict.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (d, v) async {
        // Regions: user-named places
        await d.execute('''
          CREATE TABLE regions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            radius_m INTEGER NOT NULL DEFAULT 40
          );
        ''');
        // Logs: signal measurements; link to region if matched
        await d.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            region_id INTEGER,
            signal_dbm REAL,
            download_mbps REAL,
            net_type TEXT,
            lat REAL,
            lng REAL,
            ts INTEGER NOT NULL,
            FOREIGN KEY(region_id) REFERENCES regions(id) ON DELETE SET NULL
          );
        ''');
        // Speed lookups per region (fast comparisons)
        await d.execute('CREATE INDEX idx_logs_region ON logs(region_id);');
        await d.execute('CREATE INDEX idx_logs_ts ON logs(ts);');
      },
    );
  }

  // --- Regions ---
  Future<int> insertRegion(String name, double lat, double lng, {int radiusM = 40}) async {
    final d = await db;
    return d.insert('regions', {
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'radius_m': radiusM,
    });
  }

  Future<List<Map<String, dynamic>>> allRegions() async {
    final d = await db;
    return d.query('regions', orderBy: 'name ASC');
  }

  Future<int> updateRegion(int id, {String? name, double? lat, double? lng, int? radiusM}) async {
    final d = await db;
    final updates = <String, Object?>{};
    if (name != null) updates['name'] = name;
    if (lat != null) updates['latitude'] = lat;
    if (lng != null) updates['longitude'] = lng;
    if (radiusM != null) updates['radius_m'] = radiusM;
    return d.update('regions', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRegion(int id) async {
    final d = await db;
    return d.delete('regions', where: 'id = ?', whereArgs: [id]);
  }

  // --- Logs ---
  Future<int> insertLog({
    int? regionId,
    required double? signalDbm,
    required double? downloadMbps,
    required String? netType,
    required double lat,
    required double lng,
    required DateTime ts,
  }) async {
    final d = await db;
    return d.insert('logs', {
      'region_id': regionId,
      'signal_dbm': signalDbm,
      'download_mbps': downloadMbps,
      'net_type': netType,
      'lat': lat,
      'lng': lng,
      'ts': ts.millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> logsForRegion(int regionId) async {
    final d = await db;
    return d.query('logs', where: 'region_id = ?', whereArgs: [regionId], orderBy: 'ts DESC');
  }

  // Aggregates for comparison
  Future<List<Map<String, dynamic>>> regionAverages() async {
    final d = await db;
    return d.rawQuery('''
      SELECT r.id, r.name,
             AVG(l.signal_dbm) AS avg_signal_dbm,
             AVG(l.download_mbps) AS avg_download_mbps,
             COUNT(l.id) AS samples
      FROM regions r
      LEFT JOIN logs l ON l.region_id = r.id
      GROUP BY r.id, r.name
      ORDER BY avg_download_mbps DESC NULLS LAST, avg_signal_dbm DESC NULLS LAST;
    ''');
  }
}
