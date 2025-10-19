import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math';

Future<void> testUploadSpeed() async {
  final url = Uri.parse('http://speedtest.tele2.net/upload.php'); // Tele2 upload endpoint
  final client = HttpClient();

  // Generate random data (5 MB)
  final data = Uint8List(5 * 1024 * 1024);
  final random = Random();
  for (int i = 0; i < data.length; i++) {
    data[i] = random.nextInt(256);
  }

  final stopwatch = Stopwatch()..start();
  final request = await client.postUrl(url);

  // Send the data
  request.add(data);

  // Close the request and get response
  final response = await request.close();
  await response.drain(); // consume the response fully
  stopwatch.stop();

  final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
  final speedMbps = (data.length * 8) / (elapsedSeconds * 1000000);

  print('Upload speed: ${speedMbps.toStringAsFixed(2)} Mbps');
  client.close();
}
