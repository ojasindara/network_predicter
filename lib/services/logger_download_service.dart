import 'dart:io';
import 'dart:typed_data';

Future<double> testDownloadSpeed() async {
  try {
    // You can adjust 10MB.bin to a smaller or larger file if needed
    final url = Uri.parse('https://fsn1-speed.hetzner.com/10MB.bin');
    final stopwatch = Stopwatch()..start();

    final request = await HttpClient().getUrl(url);
    final response = await request.close();

    int bytes = 0;

    // Read the response stream correctly
    await for (final chunk in response.timeout(const Duration(seconds: 60))) {
      bytes += chunk.length;
    }

    stopwatch.stop();
    final seconds = stopwatch.elapsedMilliseconds / 1000;

    // Convert bytes/sec → Mbps
    final speedMbps = (bytes * 8 / seconds) / (1024 * 1024);
    return speedMbps;
  } catch (e) {
    print('Speed test error: $e');
    return 0.0;
  }
}