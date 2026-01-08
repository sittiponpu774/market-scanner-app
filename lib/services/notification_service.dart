import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/models.dart';

/// Notification mode for NotificationService
enum LocalNotificationMode {
  all,        // Notify for all signals
  favourites, // Notify only for favourite symbols
  off,        // No notifications
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  bool _isInitialized = false;
  
  // Notification mode and favourites
  LocalNotificationMode _notificationMode = LocalNotificationMode.all;
  Set<String> _favouriteSymbols = {};
  
  /// Update notification mode
  void setNotificationMode(LocalNotificationMode mode) {
    _notificationMode = mode;
    debugPrint('NotificationService: mode set to $mode');
  }
  
  /// Update favourite symbols
  void updateFavourites(Set<String> symbols) {
    _favouriteSymbols = Set.from(symbols);
    debugPrint('NotificationService: favourites updated with ${symbols.length} symbols');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Skip on Web - not supported
    if (kIsWeb) {
      debugPrint('NotificationService: Skipped on Web');
      _isInitialized = true;
      return;
    }
    
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on Android 13+
    await _requestPermissions();

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  Future<void> _requestPermissions() async {
    if (_notificationsPlugin == null) return;
    
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin!.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - can navigate to specific screen
  }

  /// Show notification for a signal
  Future<void> showSignalNotification(Signal signal) async {
    if (!_isInitialized) await initialize();
    if (_notificationsPlugin == null) return; // Skip on Web

    final String title = _getNotificationTitle(signal);
    final String body = _getNotificationBody(signal);

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'signal_channel',
      'Signal Notifications',
      channelDescription: 'Notifications for buy/sell signals',
      importance: Importance.high,
      priority: Priority.high,
      color: _getSignalColor(signal.signalType),
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin!.show(
      signal.symbol.hashCode,
      title,
      body,
      details,
      payload: signal.symbol,
    );
  }

  /// Show notifications for new signals
  Future<void> checkAndNotifyNewSignals({
    required List<Signal> newSignals,
    required List<Signal> previousSignals,
    required bool notificationsEnabled,
  }) async {
    // Check notification mode
    if (_notificationMode == LocalNotificationMode.off) return;
    if (!notificationsEnabled) return;

    // Create a map of previous signals
    final Map<String, Signal> previousMap = {
      for (var s in previousSignals) s.symbol: s
    };

    for (final signal in newSignals) {
      // Only notify for BUY or SELL signals (not HOLD)
      if (signal.signalType.toUpperCase() == 'HOLD') continue;
      
      // Check favourites mode
      if (_notificationMode == LocalNotificationMode.favourites) {
        if (!_favouriteSymbols.contains(signal.symbol)) continue;
      }

      final previousSignal = previousMap[signal.symbol];

      // Notify if:
      // 1. Signal is new (not in previous list)
      // 2. Signal changed from HOLD to BUY/SELL
      // 3. Signal changed from BUY to SELL or vice versa
      if (previousSignal == null ||
          previousSignal.signalType.toUpperCase() != signal.signalType.toUpperCase()) {
        await showSignalNotification(signal);
      }
    }
  }

  String _getNotificationTitle(Signal signal) {
    final String action = signal.signalType.toUpperCase();
    final String emoji = action == 'BUY' ? '🟢' : '🔴';
    return '$emoji $action Signal: ${signal.symbol}';
  }

  String _getNotificationBody(Signal signal) {
    final String priceStr = signal.price >= 1
        ? signal.price.toStringAsFixed(2)
        : signal.price.toStringAsFixed(6);
    final String changeStr =
        '${signal.changePercent >= 0 ? '+' : ''}${signal.changePercent.toStringAsFixed(2)}%';
    final String confidenceStr = '${(signal.confidence * 100).toStringAsFixed(0)}%';
    final String marketType = signal.marketType == 'crypto' ? 'Crypto' : 'SET';

    return '[$marketType] Price: \$$priceStr ($changeStr) | Confidence: $confidenceStr | RSI: ${signal.rsi.toStringAsFixed(1)}';
  }

  Color _getSignalColor(String signalType) {
    switch (signalType.toUpperCase()) {
      case 'BUY':
        return Colors.green;
      case 'SELL':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (_notificationsPlugin == null) return;
    await _notificationsPlugin!.cancelAll();
  }

  /// Cancel notification by ID
  Future<void> cancel(int id) async {
    if (_notificationsPlugin == null) return;
    await _notificationsPlugin!.cancel(id);
  }
}
