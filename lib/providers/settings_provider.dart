import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Notification mode options
enum NotificationMode {
  all,        // Notify for all signals
  favourites, // Notify only for favourite symbols
  off,        // No notifications
}

class SettingsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  // GitHub Pages API URL for production
  static const String _defaultApiUrl = 'https://sittiponpu774.github.io/market-scanner-api/data';
  
  String _apiUrl = _defaultApiUrl;
  bool _isDarkMode = true;
  NotificationMode _notificationMode = NotificationMode.all;
  bool _isConnected = false;
  int _displayLimit = 50;  // Default to 50

  String get apiUrl => _apiUrl;
  bool get isDarkMode => _isDarkMode;
  NotificationMode get notificationMode => _notificationMode;
  // For backward compatibility
  bool get notificationsEnabled => _notificationMode != NotificationMode.off;
  bool get isConnected => _isConnected;
  int get displayLimit => _displayLimit;

  // Available limit options (1-100)
  static const List<int> limitOptions = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Force reset to GitHub Pages URL if old Manus URL is saved
    String? savedUrl = prefs.getString('api_url');
    if (savedUrl != null && savedUrl.contains('manus.space')) {
      await prefs.setString('api_url', _defaultApiUrl);
      savedUrl = _defaultApiUrl;
    }
    
    _apiUrl = savedUrl ?? _defaultApiUrl;
    _isDarkMode = prefs.getBool('dark_mode') ?? true;
    
    // Load notification mode
    final modeIndex = prefs.getInt('notification_mode') ?? 0;
    _notificationMode = NotificationMode.values[modeIndex.clamp(0, NotificationMode.values.length - 1)];
    
    // Ensure displayLimit is in limitOptions
    int savedLimit = prefs.getInt('display_limit') ?? 50;
    if (!limitOptions.contains(savedLimit)) {
      savedLimit = 50;
    }
    _displayLimit = savedLimit;
    
    _apiService.setBaseUrl(_apiUrl);
    await checkConnection();
    
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    _apiUrl = url;
    _apiService.setBaseUrl(url);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', url);
    
    await checkConnection();
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    
    notifyListeners();
  }

  Future<void> setNotificationMode(NotificationMode mode) async {
    _notificationMode = mode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_mode', mode.index);
    
    notifyListeners();
  }

  // Legacy method for backward compatibility
  Future<void> setNotifications(bool value) async {
    await setNotificationMode(value ? NotificationMode.all : NotificationMode.off);
  }

  Future<void> setDisplayLimit(int value) async {
    _displayLimit = value;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('display_limit', value);
    
    notifyListeners();
  }

  Future<void> checkConnection() async {
    _isConnected = await _apiService.checkConnection();
    notifyListeners();
  }
}
