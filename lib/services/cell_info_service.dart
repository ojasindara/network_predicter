import 'dart:async';
import 'package:flutter/services.dart';

class CellInfoService {
  static const MethodChannel _channel = MethodChannel('cell_info_channel');

  /// Returns a Map with keys: cid, tac, mcc, mnc, signalDbm, type
  static Future<Map<String, dynamic>?> getCellInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getCellInfo');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print("Error fetching cell info: $e");
      return null;
    }
  }
}
