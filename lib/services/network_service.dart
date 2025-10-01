import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetch top predicted locations from backend
Future<List<PredictedLocation>> fetchTopLocations() async {
  final response = await http.get(Uri.parse('http://192.168.0.100:3000/networkLogs'));

  if (response.statusCode == 200) {
    List<dynamic> data = jsonDecode(response.body);

    // Sort by average speed descending
    data.sort((a, b) {
      double avgA = (a['download'] + a['upload']) / 2;
      double avgB = (b['download'] + b['upload']) / 2;
      return avgB.compareTo(avgA);
    });

    // Map to PredictedLocation objects
    return data.map((e) => PredictedLocation.fromJson(e)).toList();
  } else {
    throw Exception('Failed to load locations');
  }
}

/// Model for predicted network locations from backend
class PredictedLocation {
  final String name;
  final double download;
  final double upload;

  PredictedLocation({
    required this.name,
    required this.download,
    required this.upload,
  });

  factory PredictedLocation.fromJson(Map<String, dynamic> json) {
    return PredictedLocation(
      name: json['name'],
      download: (json['download'] as num).toDouble(),
      upload: (json['upload'] as num).toDouble(),
    );
  }
}
