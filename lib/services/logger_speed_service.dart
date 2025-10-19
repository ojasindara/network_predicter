import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

// ---------------- Download Speed Service ----------------
Future<double> logger_download_service() async {
  final url = Uri.parse('https://fsn1-speed.hetzner.com/10MB.bin');
  final stopwatch = Stopwatch()..start();

  try {
    final request = await HttpClient().getUrl(url);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception("Download failed: ${response.statusCode}");
    }

    int bytesReceived = 0;
    await for (var data in response) {
      bytesReceived += data.length;
    }

    stopwatch.stop();
    final seconds = stopwatch.elapsedMilliseconds / 1000;
    final bits = bytesReceived * 8;
    final mbps = (bits / seconds) / (1024 * 1024);
    return double.parse(mbps.toStringAsFixed(2));
  } catch (e) {
    print("Error in download test: $e");
    return 0.0;
  }
}

// ---------------- Upload Speed Service ----------------
Future<double> logger_upload_service() async {
  final url = Uri.parse('http://speedtest.tele2.net/upload.php');
  final stopwatch = Stopwatch()..start();

  try {
    // generate random 5 MB data
    final random = Random();
    final data = List<int>.generate(5 * 1024 * 1024, (_) => random.nextInt(256));

    final request = http.MultipartRequest('POST', url)
      ..files.add(http.MultipartFile.fromBytes('file', data, filename: 'upload_test.bin'));

    final response = await request.send();

    stopwatch.stop();
    final seconds = stopwatch.elapsedMilliseconds / 1000;

    if (response.statusCode != 200) {
      throw Exception("Upload failed: ${response.statusCode}");
    }

    final bits = data.length * 8;
    final mbps = (bits / seconds) / (1024 * 1024);
    return double.parse(mbps.toStringAsFixed(2));
  } catch (e) {
    print("Error in upload test: $e");
    return 0.0;
  }
}
