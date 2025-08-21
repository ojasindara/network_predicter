import 'db.dart';
import '../core/geo.dart';

class RegionMatch {
  final int regionId;
  final String name;
  final double distanceM;
  RegionMatch(this.regionId, this.name, this.distanceM);
}

class RegionMatcher {
  final _db = AppDB();

  // returns nearest region within its radius; else null
  Future<RegionMatch?> findNearest(double lat, double lng) async {
    final regions = await _db.allRegions();
    RegionMatch? best;
    for (final r in regions) {
      final d = haversineMeters(lat, lng, r['latitude'] as double, r['longitude'] as double);
      final radius = (r['radius_m'] as int);
      if (d <= radius) {
        if (best == null || d < best!.distanceM) {
          best = RegionMatch(r['id'] as int, r['name'] as String, d);
        }
      }
    }
    return best;
  }
}
