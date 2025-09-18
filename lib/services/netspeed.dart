import 'dart:async';
import 'dart:math';

/// A simple simulated NetSpeed stream.
/// Replace with EventChannel/native integration later if needed.
class NetSpeed {
  static final StreamController<Map<String, double>> _controller =
  StreamController.broadcast();

  static Stream<Map<String, double>> get speedStream => _controller.stream;

  static Timer? _timer;

  /// Start emitting fake speeds (simulates real-time updates)
  static void start() {
    _timer?.cancel();
    final rnd = Random();

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final dl = rnd.nextDouble() * 500; // KB/s
      final ul = rnd.nextDouble() * 200; // KB/s

      _controller.add({"download": dl, "upload": ul});
    });
  }

  /// Stop emitting
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
