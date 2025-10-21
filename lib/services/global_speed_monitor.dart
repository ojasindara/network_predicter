import 'dart:async';
import 'package:flutter_internet_speed_test_pro/flutter_internet_speed_test_pro.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalSpeedMonitor {
  static final GlobalSpeedMonitor _instance = GlobalSpeedMonitor._internal();
  factory GlobalSpeedMonitor() => _instance;
  GlobalSpeedMonitor._internal();

  final FlutterInternetSpeedTest _internetSpeedTest = FlutterInternetSpeedTest();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Timer? _timer;
  bool _isTesting = false;
  double? downloadRate;
  double? uploadRate;
  String? unit;

  // Optional callback to notify screens of updates
  ValueNotifier<Map<String, dynamic>> speedDataNotifier = ValueNotifier({});



  void start() {
    if (_timer != null) return; // Prevent multiple timers

    _runSpeedTest(); // Run once immediately
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _runSpeedTest());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runSpeedTest() async {
    if (_isTesting) return;
    _isTesting = true;

    try {
      await _internetSpeedTest.startTesting(
        onCompleted: (TestResult download, TestResult upload) async {
          downloadRate = download.transferRate;
          uploadRate = upload.transferRate;
          unit = download.unit.toString().split('.').last;

          speedDataNotifier.value = {
            'download': downloadRate,
            'upload': uploadRate,
            'unit': unit,
            'timestamp': DateTime.now().toIso8601String(),
          };

          // ✅ Save to Firebase
          await _saveToCloud(speedDataNotifier.value);

          _isTesting = false;
          debugPrint('✅ Speed test saved to cloud: $speedDataNotifier.value');
        },
        onProgress: (percent, data) {
          downloadRate = data.transferRate;
          unit = data.unit.name;
        },
        onError: (String errorMessage, String speedTestError) {
          debugPrint('⚠️ Speed test error: $errorMessage - $speedTestError');
          _isTesting = false;
        },
      );
    } catch (e) {
      debugPrint('⚠️ Unexpected error during speed test: $e');
      _isTesting = false;
    }
  }

  Future<void> _saveToCloud(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('speed_logs').add(data);
    } catch (e) {
      debugPrint('❌ Error saving to Firestore: $e');
    }
  }
}