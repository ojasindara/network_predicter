import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';

class NetworkSpeedTest {
  final FlutterInternetSpeedTest _speedTest = FlutterInternetSpeedTest();

  void startSpeedTest({
    required Function(TestResult download, TestResult upload) onCompleted,
    required Function(double percent, TestResult data) onProgress,
    required Function(String errorMessage, String speedTestError) onError,
  }) {
    _speedTest.startTesting(
      useFastApi: true,
      onStarted: () {
        print("Speed test started...");
      },
      onCompleted: (download, upload) {
        onCompleted(download, upload);
      },
      onProgress: (percent, data) {
        onProgress(percent, data);
      },
      onError: (errorMessage, speedTestError) {
        onError(errorMessage, speedTestError);
      },
      onDefaultServerSelectionInProgress: () {
        print("Selecting default server...");
      },
      onDefaultServerSelectionDone: (client) {
        print("Server selected: ${client?.ip} (${client?.location})");
      },
      onDownloadComplete: (data) {
        print("Download complete: ${data.transferRate} ${data.unit}");
      },
      onUploadComplete: (data) {
        print("Upload complete: ${data.transferRate} ${data.unit}");
      },
      onCancel: () {
        print("Test cancelled.");
      },
    );
  }
}
extension TestResultValue on TestResult {
  /// Returns the value as Mbps (double)
  double get valueAsMbps {
    // transferRate might be num, so ensure conversion to double
    final rate = transferRate is num ? (transferRate as num).toDouble() : double.tryParse('$transferRate') ?? 0.0;

    if (unit == SpeedUnit.kbps) {
      return rate / 1000.0; // kbps → Mbps
    } else if (unit == SpeedUnit.mbps) {   // <-- use mbps (lowercase)
      return rate;
    }
    // fallback
    return rate;
  }
}
