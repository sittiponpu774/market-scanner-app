import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../providers/settings_provider.dart';

/// Normalize symbol for comparison (FET/USDT -> FET, FETUSDT -> FET)
String _normalizeSymbolStatic(String symbol) {
  String normalized = symbol.toUpperCase();
  if (normalized.endsWith('/USDT')) {
    normalized = normalized.replaceAll('/USDT', '');
  } else if (normalized.endsWith('USDT')) {
    normalized = normalized.replaceAll('USDT', '');
  } else if (normalized.endsWith('/BUSD')) {
    normalized = normalized.replaceAll('/BUSD', '');
  } else if (normalized.endsWith('BUSD')) {
    normalized = normalized.replaceAll('BUSD', '');
  }
  return normalized;
}

/// Handle background messages with filtering
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase with options (required for background)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('📨 Background message received');
  print('📦 Data: ${message.data}');
  
  final prefs = await SharedPreferences.getInstance();
  
  // Check notification mode
  final modeStr = prefs.getString('notification_mode') ?? 'all';
  print('🔔 Notification mode: $modeStr');
  
  if (modeStr == 'off') {
    print('🔕 Notifications disabled - skipping');
    return;
  }
  
  // Get title and body from data
  final title = message.data['title'] as String? ?? 'Signal Alert';
  final body = message.data['body'] as String? ?? '';
  final symbol = message.data['symbol'] as String?;
  
  // If favourites mode, check symbol
  if (modeStr == 'favourites') {
    // Load favourites from SharedPreferences
    final favouritesJson = prefs.getString('favourite_items_v2');
    Set<String> favouriteSymbols = {};
    
    if (favouritesJson != null) {
      try {
        final List<dynamic> decoded = json.decode(favouritesJson);
        favouriteSymbols = decoded
            .map((item) => (item as Map<String, dynamic>)['symbol'] as String)
            .toSet();
      } catch (e) {
        print('❌ Error parsing favourites: $e');
      }
    }
    
    print('⭐ Favourites: $favouriteSymbols');
    print('🔍 Checking symbol: $symbol');
    
    if (symbol == null) {
      print('🔕 No symbol in message - skipping');
      return;
    }
    
    // Normalize and check
    final normalizedIncoming = _normalizeSymbolStatic(symbol);
    bool isFavourite = false;
    for (final fav in favouriteSymbols) {
      if (_normalizeSymbolStatic(fav) == normalizedIncoming) {
        isFavourite = true;
        break;
      }
    }
    
    if (!isFavourite) {
      print('🔕 Symbol $symbol ($normalizedIncoming) not in favourites - skipping');
      return;
    }
    print('✅ Symbol $symbol is favourite - showing notification');
  }
  
  // Show notification
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await localNotifications.initialize(initSettings);
  
  const androidDetails = AndroidNotificationDetails(
    'signal_alerts',
    'Signal Alerts',
    channelDescription: 'Trading signal notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );
  
  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(android: androidDetails),
  );
  
  print('✅ Background notification shown');
}

/// Notification mode for FCM
enum FcmNotificationMode {
  all,        // Notify for all signals
  favourites, // Notify only for favourite symbols
  off,        // No notifications
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  FcmNotificationMode _notificationMode = FcmNotificationMode.all;
  FcmNotificationMode get notificationMode => _notificationMode;
  bool get notificationsEnabled => _notificationMode != FcmNotificationMode.off;
  
  // Favourite symbols list (synced from FavouriteProvider)
  Set<String> _favouriteSymbols = {};
  
  /// Update favourite symbols list
  void updateFavourites(Set<String> symbols) {
    _favouriteSymbols = symbols;
  }

  /// Initialize FCM
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load saved notification mode FIRST
    final savedMode = prefs.getString('notification_mode') ?? 'all';
    switch (savedMode) {
      case 'favourites':
        _notificationMode = FcmNotificationMode.favourites;
        break;
      case 'off':
        _notificationMode = FcmNotificationMode.off;
        break;
      default:
        _notificationMode = FcmNotificationMode.all;
    }
    print('📋 Loaded notification mode: $_notificationMode');
    
    // Skip FCM on Web (has compatibility issues)
    if (kIsWeb) {
      print('⚠️ FCM not supported on Web - use Android/iOS');
      await prefs.setString('fcm_error', 'FCM not supported on Web');
      return;
    }
    
    try {
      // Firebase should already be initialized in main()
      // But ensure it's ready (safe to call multiple times)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('✅ Firebase initialized in FcmService');
      } else {
        print('✅ Firebase already initialized');
      }
      await prefs.setString('fcm_error', '');
      
      // Initialize instances AFTER Firebase is ready
      _messaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Background handler is registered in main() now

      // Request notification permissions
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('📋 Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notification permission granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ Provisional notification permission');
      } else {
        print('❌ Notification permission denied');
        await prefs.setString('fcm_error', 'Permission denied');
        return;
      }

      // Get FCM Token
      try {
        _fcmToken = await _messaging!.getToken();
        print('📱 FCM Token: $_fcmToken');
      } catch (tokenError) {
        print('❌ Failed to get FCM token: $tokenError');
        await prefs.setString('fcm_error', 'Token error: $tokenError');
        return;
      }

      // Save token to SharedPreferences for backend to use
      if (_fcmToken != null) {
        await prefs.setString('fcm_token', _fcmToken!);
        print('💾 FCM Token saved to preferences');
      } else {
        print('⚠️ FCM Token is null!');
        await prefs.setString('fcm_error', 'Token is null - check Google Play Services');
        return;
      }

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', newToken);
        print('🔄 FCM Token refreshed');
      });

      // Initialize local notifications for foreground
      await _initLocalNotifications();
      print('✅ Local notifications initialized');

      // Subscribe to topic based on saved notification mode
      if (_notificationMode == FcmNotificationMode.all) {
        await _messaging!.subscribeToTopic('signal_alerts');
        print('✅ Subscribed to topic: signal_alerts (mode: ALL)');
      } else if (_notificationMode == FcmNotificationMode.off) {
        await _messaging!.unsubscribeFromTopic('signal_alerts');
        print('🔕 Unsubscribed from signal_alerts (mode: OFF)');
      } else {
        // Favourites mode - don't subscribe to main topic
        // FavouriteProvider will handle per-symbol topics
        await _messaging!.unsubscribeFromTopic('signal_alerts');
        print('⭐ Not subscribing to signal_alerts (mode: FAVOURITES)');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from notification
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      print('✅ FCM Service initialized successfully');
    } catch (e, stackTrace) {
      print('❌ FCM initialization error: $e');
      print('📍 Stack trace: $stackTrace');
      await prefs.setString('fcm_error', 'Init error: $e');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        print('📌 Notification tapped: ${response.payload}');
      },
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'signal_alerts',
      'Signal Alerts',
      description: 'Trading signal notifications',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  /// Check if symbol is in favourites (with normalization)
  bool _isSymbolFavourite(String symbol) {
    final normalizedIncoming = _normalizeSymbolStatic(symbol);
    for (final fav in _favouriteSymbols) {
      if (_normalizeSymbolStatic(fav) == normalizedIncoming) {
        return true;
      }
    }
    return false;
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Foreground message received');
    print('📦 Data: ${message.data}');

    // Check notification mode
    if (_notificationMode == FcmNotificationMode.off) {
      print('🔕 Notifications disabled - skipping');
      return;
    }

    // Get title and body from data (data-only message)
    final title = message.data['title'] as String? ?? message.notification?.title ?? 'Signal Alert';
    final body = message.data['body'] as String? ?? message.notification?.body ?? '';
    
    // If favourites only mode, check if symbol is in favourites
    if (_notificationMode == FcmNotificationMode.favourites) {
      final symbol = message.data['symbol'] as String?;
      print('🔍 Checking symbol: $symbol, Favourites: $_favouriteSymbols');
      if (symbol == null || !_isSymbolFavourite(symbol)) {
        print('🔕 Symbol $symbol not in favourites - skipping');
        return;
      }
      print('✅ Symbol $symbol is favourite - showing notification');
    }

    _showLocalNotification(
      title: title,
      body: body,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('📌 Notification opened: ${message.data}');
    // TODO: Navigate to specific screen based on message data
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'signal_alerts',
      'Signal Alerts',
      channelDescription: 'Trading signal notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications!.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.subscribeToTopic(topic);
    print('✅ Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.unsubscribeFromTopic(topic);
    print('✅ Unsubscribed from topic: $topic');
  }

  /// Set notification mode with callback to update FavouriteProvider
  Future<void> setNotificationMode(NotificationMode mode, {Function(bool)? onFavouritesModeChanged}) async {
    // Convert from SettingsProvider enum to local enum
    switch (mode) {
      case NotificationMode.all:
        _notificationMode = FcmNotificationMode.all;
        break;
      case NotificationMode.favourites:
        _notificationMode = FcmNotificationMode.favourites;
        break;
      case NotificationMode.off:
        _notificationMode = FcmNotificationMode.off;
        break;
    }
    
    // Save mode to SharedPreferences for background handler
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_mode', _notificationMode.name);
    
    if (_messaging == null) return;
    
    if (_notificationMode == FcmNotificationMode.off) {
      // Unsubscribe from all topics
      await _messaging!.unsubscribeFromTopic('signal_alerts');
      onFavouritesModeChanged?.call(false);
      print('🔕 Notifications OFF - unsubscribed from signal_alerts');
    } else if (_notificationMode == FcmNotificationMode.all) {
      // Subscribe to main topic for all signals
      await _messaging!.subscribeToTopic('signal_alerts');
      onFavouritesModeChanged?.call(false);
      print('🔔 Notifications ALL - subscribed to signal_alerts');
    } else if (_notificationMode == FcmNotificationMode.favourites) {
      // Unsubscribe from main topic, let FavouriteProvider handle per-symbol topics
      await _messaging!.unsubscribeFromTopic('signal_alerts');
      onFavouritesModeChanged?.call(true);
      print('🔔 Notifications FAVOURITES - using per-symbol topics');
    }
  }

  /// Legacy method for backward compatibility
  Future<void> setNotificationsEnabled(bool enabled) async {
    await setNotificationMode(enabled ? NotificationMode.all : NotificationMode.off);
  }

  /// Get FCM token for backend registration
  Future<String?> getToken() async {
    if (_messaging == null) return null;
    _fcmToken ??= await _messaging!.getToken();
    return _fcmToken;
  }
}
