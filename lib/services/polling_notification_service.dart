import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Polling-based notification service for GitHub Pages API
/// Since GitHub Pages is static hosting, we use HTTP polling instead of WebSocket
class PollingNotificationService {
  static final PollingNotificationService _instance = 
      PollingNotificationService._internal();
  factory PollingNotificationService() => _instance;
  PollingNotificationService._internal();

  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  Timer? _pollingTimer;
  bool _isEnabled = false;
  bool _isInitialized = false;
  bool _isPolling = false;
  
  // Polling interval (GitHub Actions updates every 5 minutes)
  Duration _pollingInterval = const Duration(minutes: 1);
  
  // Store previous signals for comparison
  Map<String, Signal> _previousCryptoSignals = {};
  Map<String, Signal> _previousThaiSignals = {};

  // Callback for signal updates (to update UI)
  Function(List<Signal> crypto, List<Signal> thai)? onSignalsUpdate;
  Function(List<Signal> changedSignals)? onNewSignals;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isPolling => _isPolling;
  Duration get pollingInterval => _pollingInterval;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _notificationService.initialize();
    _isInitialized = true;
    debugPrint('[PollingNotification] Service initialized');
  }

  /// Set polling interval
  void setPollingInterval(Duration interval) {
    _pollingInterval = interval;
    if (_isEnabled) {
      // Restart timer with new interval
      _stopPolling();
      _startPolling();
    }
  }

  /// Enable/disable polling notifications
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    
    if (enabled) {
      _startPolling();
      // Fetch immediately when enabled
      await _fetchAndCompare();
    } else {
      _stopPolling();
    }
  }

  /// Start polling timer
  void _startPolling() {
    _stopPolling(); // Clear existing timer
    
    debugPrint('[PollingNotification] Starting polling every ${_pollingInterval.inSeconds}s');
    
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      _fetchAndCompare();
    });
  }

  /// Stop polling timer
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('[PollingNotification] Polling stopped');
  }

  /// Fetch signals and compare for changes
  Future<void> _fetchAndCompare() async {
    if (_isPolling) return; // Prevent concurrent fetches
    
    _isPolling = true;
    debugPrint('[PollingNotification] Fetching signals...');

    try {
      // Fetch latest signals
      final cryptoSignals = await _apiService.getCryptoSignals();
      final thaiSignals = await _apiService.getThaiStockSignals();

      // Detect changed signals
      final changedSignals = <Signal>[];
      
      // Check crypto signals
      for (final signal in cryptoSignals) {
        final previous = _previousCryptoSignals[signal.symbol];
        if (_hasSignalChanged(previous, signal)) {
          changedSignals.add(signal);
        }
      }
      
      // Check thai signals
      for (final signal in thaiSignals) {
        final previous = _previousThaiSignals[signal.symbol];
        if (_hasSignalChanged(previous, signal)) {
          changedSignals.add(signal);
        }
      }

      // Send notifications for changed signals
      if (changedSignals.isNotEmpty && _isEnabled) {
        debugPrint('[PollingNotification] 🔔 ${changedSignals.length} signals changed!');
        
        for (final signal in changedSignals) {
          if (_shouldNotify(signal)) {
            await _sendNotification(signal);
          }
        }
        
        // Notify callback
        onNewSignals?.call(changedSignals);
      }

      // Update stored signals
      _previousCryptoSignals = {for (var s in cryptoSignals) s.symbol: s};
      _previousThaiSignals = {for (var s in thaiSignals) s.symbol: s};

      // Notify UI callback
      onSignalsUpdate?.call(cryptoSignals, thaiSignals);

      debugPrint('[PollingNotification] Fetch complete. Crypto: ${cryptoSignals.length}, Thai: ${thaiSignals.length}');
      
    } catch (e) {
      debugPrint('[PollingNotification] Error fetching: $e');
    } finally {
      _isPolling = false;
    }
  }

  /// Check if signal has changed (new or signal type changed)
  bool _hasSignalChanged(Signal? previous, Signal current) {
    if (previous == null) {
      // New signal - only notify if it's BUY or SELL
      return current.signalType.toUpperCase() != 'HOLD';
    }
    
    // Signal type changed
    return previous.signalType.toUpperCase() != current.signalType.toUpperCase();
  }

  /// Check if we should notify for this signal
  bool _shouldNotify(Signal signal) {
    // Only notify for BUY or SELL signals
    final signalType = signal.signalType.toUpperCase();
    return signalType == 'BUY' || signalType == 'SELL';
  }

  /// Send push notification for a signal
  Future<void> _sendNotification(Signal signal) async {
    debugPrint('[PollingNotification] 🔔 Sending notification for ${signal.symbol} - ${signal.signalType}');
    await _notificationService.showSignalNotification(signal);
  }

  /// Force refresh - fetch immediately
  Future<void> refresh() async {
    await _fetchAndCompare();
  }

  /// Clear stored signal history
  void clearHistory() {
    _previousCryptoSignals.clear();
    _previousThaiSignals.clear();
  }

  /// Dispose resources
  void dispose() {
    _stopPolling();
  }
}
