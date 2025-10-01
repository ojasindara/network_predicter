class Location {
  final String name;
  final double download;
  final double upload;

  Location({
    required this.name,
    required this.download,
    required this.upload,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      name: json['name'],
      download: (json['download'] as num).toDouble(),
      upload: (json['upload'] as num).toDouble(),
    );
  }
}
