import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'websocket_service.dart';
import 'notification_service.dart';

/// Real-time notification service that combines WebSocket and Push Notifications
/// Automatically detects new BUY/SELL signals and sends notifications
class RealtimeNotificationService {
  static final RealtimeNotificationService _instance = 
      RealtimeNotificationService._internal();
  factory RealtimeNotificationService() => _instance;
  RealtimeNotificationService._internal();

  final WebSocketService _wsService = WebSocketService();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription? _signalSubscription;
  StreamSubscription? _statusSubscription;

  bool _isEnabled = false;
  bool _isInitialized = false;
  
  // Store previous signals for comparison
  final Map<String, Signal> _previousCryptoSignals = {};
  final Map<String, Signal> _previousThaiSignals = {};

  // Callback for signal updates (to update UI)
  Function(SignalUpdate)? onSignalUpdate;
  Function(WebSocketStatus)? onStatusChange;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isConnected => _wsService.isConnected;
  WebSocketStatus get status => _wsService.status;
  Stream<WebSocketStatus> get statusStream => _wsService.statusStream;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _notificationService.initialize();
    _isInitialized = true;
    debugPrint('[RealtimeNotification] Service initialized');
  }

  /// Set WebSocket URL
  void setWebSocketUrl(String httpUrl) {
    _wsService.setBaseUrl(httpUrl);
  }

  /// Enable/disable realtime notifications
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    
    if (enabled) {
      await _connect();
    } else {
      await _disconnect();
    }
  }

  /// Connect to WebSocket and start listening
  Future<void> _connect() async {
    debugPrint('[RealtimeNotification] Connecting...');
    
    // Subscribe to signal updates
    _signalSubscription?.cancel();
    _signalSubscription = _wsService.signalStream.listen(_onSignalUpdate);

    // Subscribe to status changes
    _statusSubscription?.cancel();
    _statusSubscription = _wsService.statusStream.listen((status) {
      debugPrint('[RealtimeNotification] Status: $status');
      onStatusChange?.call(status);
    });

    await _wsService.connect();
    
    // Subscribe to all markets
    await Future.delayed(const Duration(milliseconds: 500));
    _wsService.subscribe('all');
  }

  /// Disconnect from WebSocket
  Future<void> _disconnect() async {
    debugPrint('[RealtimeNotification] Disconnecting...');
    _signalSubscription?.cancel();
    _statusSubscription?.cancel();
    await _wsService.disconnect();
  }

  /// Handle incoming signal updates
  void _onSignalUpdate(SignalUpdate update) {
    debugPrint('[RealtimeNotification] Received update: ${update.type}');
    
    // Notify listeners
    onSignalUpdate?.call(update);

    // Check for signal changes and send notifications
    if (_isEnabled) {
      _checkAndNotify(update);
    }
  }

  /// Check for changed signals and send notifications
  void _checkAndNotify(SignalUpdate update) {
    // If changed_signals is provided from server, use that
    if (update.changedSignals != null && update.changedSignals!.isNotEmpty) {
      for (final signal in update.changedSignals!) {
        if (_shouldNotify(signal)) {
          _sendNotification(signal);
        }
      }
      return;
    }

    // Otherwise, detect changes locally
    for (final signal in update.signals) {
      final previousMap = signal.marketType == 'crypto' 
          ? _previousCryptoSignals 
          : _previousThaiSignals;
      
      final previous = previousMap[signal.symbol];
      
      // New signal or signal type changed
      if (previous == null || 
          previous.signalType.toUpperCase() != signal.signalType.toUpperCase()) {
        if (_shouldNotify(signal)) {
          _sendNotification(signal);
        }
      }
    }

    // Update previous signals
    for (final signal in update.signals) {
      if (signal.marketType == 'crypto') {
        _previousCryptoSignals[signal.symbol] = signal;
      } else {
        _previousThaiSignals[signal.symbol] = signal;
      }
    }
  }

  /// Check if we should notify for this signal
  bool _shouldNotify(Signal signal) {
    // Only notify for BUY or SELL signals
    final signalType = signal.signalType.toUpperCase();
    return signalType == 'BUY' || signalType == 'SELL';
  }

  /// Send push notification for a signal
  Future<void> _sendNotification(Signal signal) async {
    debugPrint('[RealtimeNotification] 🔔 Sending notification for ${signal.symbol} - ${signal.signalType}');
    await _notificationService.showSignalNotification(signal);
  }

  /// Manually refresh - useful after reconnection
  void refresh() {
    if (_isEnabled && _wsService.isConnected) {
      _wsService.subscribe('all');
    }
  }

  /// Clear stored signal history
  void clearHistory() {
    _previousCryptoSignals.clear();
    _previousThaiSignals.clear();
  }

  /// Dispose resources
  void dispose() {
    _disconnect();
    _signalSubscription?.cancel();
    _statusSubscription?.cancel();
  }
}
