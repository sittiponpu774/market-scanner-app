import '../models/signal.dart';

/// Stub implementation for non-web platforms
class WebNotificationService {
  static final WebNotificationService _instance = WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  bool get isWeb => false;
  bool get isSupported => false;

  Future<bool> requestPermission() async => false;

  void showSignalNotification(Signal signal) {
    // No-op on non-web platforms
  }

  void showTestNotification() {
    // No-op on non-web platforms
  }
}
