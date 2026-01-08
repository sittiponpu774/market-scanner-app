import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/web_notification.dart';

class SignalProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  final WebNotificationService _webNotificationService = WebNotificationService();
  
  List<Signal> _cryptoSignals = [];
  List<Signal> _thaiStockSignals = [];
  bool _isLoading = false;
  String? _error;
  Signal? _selectedSignal;
  ChartData? _chartData;
  bool _notificationsEnabled = true;
  LocalNotificationMode _notificationMode = LocalNotificationMode.all;
  
  // Store previous signals to detect changes
  final Map<String, String> _previousSignalTypes = {};

  // Getters
  List<Signal> get cryptoSignals => _cryptoSignals;
  List<Signal> get thaiStockSignals => _thaiStockSignals;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Signal? get selectedSignal => _selectedSignal;
  ChartData? get chartData => _chartData;

  // Initialize notifications (FCM handles push notifications now)
  Future<void> initNotifications() async {
    await _notificationService.initialize();
    
    // Request web notification permission
    if (kIsWeb) {
      await _webNotificationService.requestPermission();
    }
  }

  // Set notifications enabled
  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    _notificationMode = value ? LocalNotificationMode.all : LocalNotificationMode.off;
    _notificationService.setNotificationMode(_notificationMode);
  }
  
  // Set notification mode
  void setNotificationMode(LocalNotificationMode mode) {
    _notificationMode = mode;
    _notificationsEnabled = mode != LocalNotificationMode.off;
    _notificationService.setNotificationMode(mode);
  }
  
  // Update favourites for notification filtering
  void updateNotificationFavourites(Set<String> symbols) {
    _notificationService.updateFavourites(symbols);
  }
  
  // Check for signal changes and notify on web
  void _checkAndNotifySignalChanges(List<Signal> newSignals) {
    if (!kIsWeb || !_notificationsEnabled) return;
    
    for (final signal in newSignals) {
      final prevType = _previousSignalTypes[signal.symbol];
      final currentType = signal.signalType.toUpperCase();
      
      // Only notify BUY or SELL changes
      if (currentType != 'HOLD' && prevType != null && prevType != currentType) {
        _webNotificationService.showSignalNotification(signal);
      }
      
      _previousSignalTypes[signal.symbol] = currentType;
    }
  }

  // Filter signals
  List<Signal> getCryptoBySignal(String signalType) {
    if (signalType == 'ALL') return _cryptoSignals;
    return _cryptoSignals.where((s) => s.signalType.toUpperCase() == signalType).toList();
  }

  List<Signal> getThaiBySignal(String signalType) {
    if (signalType == 'ALL') return _thaiStockSignals;
    return _thaiStockSignals.where((s) => s.signalType.toUpperCase() == signalType).toList();
  }

  // Fetch crypto signals (fallback or manual refresh)
  Future<void> fetchCryptoSignals({int? limit}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _cryptoSignals = await _apiService.getCryptoSignals(limit: limit);
      _cryptoSignals.sort((a, b) => b.confidence.compareTo(a.confidence));
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fetch Thai stock signals
  Future<void> fetchThaiStockSignals({int? limit}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _thaiStockSignals = await _apiService.getThaiStockSignals(limit: limit);
      _thaiStockSignals.sort((a, b) => b.confidence.compareTo(a.confidence));
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fetch all signals
  Future<void> fetchAllSignals({int? limit}) async {
    // Store previous signals for comparison
    final List<Signal> previousCrypto = List.from(_cryptoSignals);
    final List<Signal> previousThai = List.from(_thaiStockSignals);
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getCryptoSignals(limit: limit),
        _apiService.getThaiStockSignals(limit: limit),
      ]);
      
      _cryptoSignals = results[0];
      _thaiStockSignals = results[1];
      
      _cryptoSignals.sort((a, b) => b.confidence.compareTo(a.confidence));
      _thaiStockSignals.sort((a, b) => b.confidence.compareTo(a.confidence));
      
      // Check for signal changes and notify on Web
      _checkAndNotifySignalChanges([..._cryptoSignals, ..._thaiStockSignals]);
      
      // Check for new signals and send notifications (mobile)
      if (_notificationsEnabled && !kIsWeb) {
        await _notificationService.checkAndNotifyNewSignals(
          newSignals: _cryptoSignals,
          previousSignals: previousCrypto,
          notificationsEnabled: _notificationsEnabled,
        );
        await _notificationService.checkAndNotifyNewSignals(
          newSignals: _thaiStockSignals,
          previousSignals: previousThai,
          notificationsEnabled: _notificationsEnabled,
        );
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Select signal and fetch details
  Future<void> selectSignal(Signal signal) async {
    _selectedSignal = signal;
    notifyListeners();

    try {
      _chartData = await _apiService.getChartData(
        signal.symbol, 
        signal.marketType,
      );
    } catch (e) {
      _chartData = null;
    }
    
    notifyListeners();
  }

  // Clear selection
  void clearSelection() {
    _selectedSignal = null;
    _chartData = null;
    notifyListeners();
  }

  // Count by signal type
  int countCryptoByType(String type) {
    if (type == 'ALL') return _cryptoSignals.length;
    return _cryptoSignals.where((s) => s.signalType.toUpperCase() == type).length;
  }

  int countThaiByType(String type) {
    if (type == 'ALL') return _thaiStockSignals.length;
    return _thaiStockSignals.where((s) => s.signalType.toUpperCase() == type).length;
  }

  // Search crypto from Binance (real data)
  Future<Signal?> searchCryptoReal(String symbol) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final signal = await _apiService.searchCryptoReal(symbol);
      _isLoading = false;
      notifyListeners();
      return signal;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Search Thai stock from Yahoo Finance (real data)
  Future<Signal?> searchThaiReal(String symbol) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final signal = await _apiService.searchThaiReal(symbol);
      _isLoading = false;
      notifyListeners();
      return signal;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

}
