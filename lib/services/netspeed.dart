import 'dart:async';
import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';

/// A real NetSpeed stream using flutter_internet_speed_test plugin.
class NetSpeed {
  static final StreamController<Map<String, double>> _controller =
  StreamController.broadcast();

  static Stream<Map<String, double>> get speedStream => _controller.stream;

  static final FlutterInternetSpeedTest _speedTest = FlutterInternetSpeedTest();
  static bool _isTesting = false;

  /// Start a real speed test and emit live results
  static Future<void> start() async {
    if (_isTesting) return; // Prevent multiple tests
    _isTesting = true;

    await _speedTest.startTesting(
      onStarted: () {
        print("Speed test started");
      },
      onProgress: (double percent, TestResult data) {
        // Emitting live progress
        if (data.type == TestType.download) {
          _controller.add({"download": data.transferRate, "upload": 0});
        } else if (data.type == TestType.upload) {
          _controller.add({"download": 0, "upload": data.transferRate});
        }
      },
      onCompleted: (TestResult download, TestResult upload) {
        // Final results
        _controller.add({
          "download": download.transferRate,
          "upload": upload.transferRate,
        });
        print("Speed test complete");
        _isTesting = false;
      },
      onError: (String errorMessage, String speedTestError) {
        print("Error: $errorMessage ($speedTestError)");
        _isTesting = false;
      },
      onDefaultServerSelectionDone: (server) {
        print("Server selected: $server");
      },
      onDownloadComplete: (TestResult download) {
        print("Download done: ${download.transferRate} Mbps");
      },
      onUploadComplete: (TestResult upload) {
        print("Upload done: ${upload.transferRate} Mbps");
      },
    );
  }

  /// Stop the current test (optional, plugin stops automatically)
  static void stop() {
    // The plugin doesn’t support force-stopping mid-test yet,
    // so this mainly resets state.
    _isTesting = false;
  }

  /// Clean up (optional)
  static Future<void> dispose() async {
    await _controller.close();
  }
}

