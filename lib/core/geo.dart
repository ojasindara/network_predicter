import 'dart:math';

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = (lat2 - lat1) * pi / 180.0;
  final dLon = (lon2 - lon1) * pi / 180.0;
  final a = sin(dLat/2)*sin(dLat/2) +
      cos(lat1*pi/180.0)*cos(lat2*pi/180.0) *
          sin(dLon/2)*sin(dLon/2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}
