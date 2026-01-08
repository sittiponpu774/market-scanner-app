import 'dart:js_interop';
import 'package:web/web.dart';
import '../models/signal.dart';

/// Web Browser Notification Service
/// Only works on Web platform when browser tab is open
class WebNotificationService {
  static final WebNotificationService _instance = WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  bool _permissionGranted = false;
  
  /// Check if running on web
  bool get isWeb => true;
  
  /// Request notification permission
  Future<bool> requestPermission() async {
    try {
      final permission = await Notification.requestPermission().toDart;
      _permissionGranted = permission == 'granted';
      print('[WebNotification] Permission: $permission');
      return _permissionGranted;
    } catch (e) {
      print('[WebNotification] Error requesting permission: $e');
      return false;
    }
  }
  
  /// Check if notifications are supported
  bool get isSupported {
    try {
      return Notification.permission.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Show notification for a signal change
  void showSignalNotification(Signal signal) {
    if (!_permissionGranted) return;
    
    try {
      final emoji = signal.signalType.toUpperCase() == 'BUY' ? '🟢' : '🔴';
      final title = '$emoji ${signal.signalType.toUpperCase()}: ${signal.symbol}';
      final body = 'Price: \$${_formatPrice(signal.price)} | Change: ${signal.changePercent >= 0 ? '+' : ''}${signal.changePercent.toStringAsFixed(2)}%';
      
      final options = NotificationOptions(
        body: body,
        icon: '/icons/Icon-192.png',
        tag: signal.symbol, // Prevent duplicate notifications for same symbol
      );
      
      Notification(title, options);
      print('[WebNotification] Sent: $title');
    } catch (e) {
      print('[WebNotification] Error showing notification: $e');
    }
  }
  
  /// Show test notification
  void showTestNotification() {
    if (!_permissionGranted) return;
    
    try {
      final options = NotificationOptions(
        body: 'Browser notifications are working!',
        icon: '/icons/Icon-192.png',
      );
      
      Notification('🔔 Test Notification', options);
    } catch (e) {
      print('[WebNotification] Error: $e');
    }
  }
  
  String _formatPrice(double price) {
    if (price >= 1000) {
      return price.toStringAsFixed(2);
    } else if (price >= 1) {
      return price.toStringAsFixed(4);
    } else {
      return price.toStringAsFixed(6);
    }
  }
}
