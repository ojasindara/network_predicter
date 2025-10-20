import 'dart:async';
import 'package:flutter/services.dart';

// ---------------- Download Speed Service ----------------
Future<double> logger_download_service() async {
  final completer = Completer<double>();

  final channel = MethodChannel('com.networkpredictor/speedtest');

  // Listener for platform channel responses
  Future<dynamic> listener(MethodCall call) async {
    if (call.method == 'onSpeedTestComplete') {
      final speedBps = call.arguments as int;
      final speedMbps = speedBps / 1e6; // Convert to Mbps
      completer.complete(double.parse(speedMbps.toStringAsFixed(2)));
    } else if (call.method == 'onSpeedTestError') {
      completer.complete(0.0);
    }

    // Return null if nothing needs to be returned
    return null;
  }

  channel.setMethodCallHandler(listener);

  // Start download test
  await channel.invokeMethod('startDownloadTest', {
    'url': 'http://ipv4.ikoula.testdebit.info/1M.iso',
  });

  return completer.future;
}

// ---------------- Upload Speed Service ----------------
Future<double> logger_upload_service() async {
  final completer = Completer<double>();

  final channel = MethodChannel('com.networkpredictor/speedtest');

  // Listener for platform channel responses
  Future<dynamic> listener(MethodCall call) async {
    if (call.method == 'onSpeedTestComplete') {
      final speedBps = call.arguments as int;
      final speedMbps = speedBps / 1e6; // Convert to Mbps
      completer.complete(double.parse(speedMbps.toStringAsFixed(2)));
    } else if (call.method == 'onSpeedTestError') {
      completer.complete(0.0);
    }

  }

  channel.setMethodCallHandler(listener);

  // Start upload test
  await channel.invokeMethod('startUploadTest', {
    'url': 'https://network-predicter.wuaze.com/upload.php',
    'fileSize': 5 * 1024 * 1024, // 5 MB
  });

  return completer.future;
}
