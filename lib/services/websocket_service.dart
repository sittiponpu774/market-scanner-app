import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String _wsUrl = 'ws://localhost:8000/ws/signals';
  
  // Stream controllers for broadcasting data
  final _signalStreamController = StreamController<SignalUpdate>.broadcast();
  final _statusStreamController = StreamController<WebSocketStatus>.broadcast();
  
  // Getters
  Stream<SignalUpdate> get signalStream => _signalStreamController.stream;
  Stream<WebSocketStatus> get statusStream => _statusStreamController.stream;
  WebSocketStatus get status => _status;
  bool get isConnected => _status == WebSocketStatus.connected;

  void setBaseUrl(String httpUrl) {
    // Convert http URL to ws URL
    String wsUrl = httpUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    
    if (!wsUrl.endsWith('/')) {
      wsUrl += '/';
    }
    _wsUrl = '${wsUrl}ws/signals';
    debugPrint('[WebSocket] URL set to: $_wsUrl');
  }

  Future<void> connect() async {
    if (_status == WebSocketStatus.connected || 
        _status == WebSocketStatus.connecting) {
      return;
    }

    _setStatus(WebSocketStatus.connecting);
    
    try {
      debugPrint('[WebSocket] Connecting to $_wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      
      // Wait for connection
      await _channel!.ready;
      
      _setStatus(WebSocketStatus.connected);
      debugPrint('[WebSocket] Connected successfully');
      
      // Start listening to messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      
      // Start ping timer to keep connection alive
      _startPingTimer();
      
    } catch (e) {
      debugPrint('[WebSocket] Connection error: $e');
      _setStatus(WebSocketStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      debugPrint('[WebSocket] Received: ${data['type']}');
      
      if (data['type'] == 'signal_update') {
        final update = SignalUpdate.fromJson(data);
        _signalStreamController.add(update);
      } else if (data['type'] == 'pong') {
        // Server responded to ping
        debugPrint('[WebSocket] Pong received');
      } else if (data['type'] == 'initial_data') {
        // Initial data after connection
        final update = SignalUpdate.fromJson(data);
        _signalStreamController.add(update);
      }
    } catch (e) {
      debugPrint('[WebSocket] Error parsing message: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[WebSocket] Error: $error');
    _setStatus(WebSocketStatus.disconnected);
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WebSocket] Connection closed');
    _setStatus(WebSocketStatus.disconnected);
    _scheduleReconnect();
  }

  void _setStatus(WebSocketStatus newStatus) {
    _status = newStatus;
    _statusStreamController.add(newStatus);
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_status == WebSocketStatus.connected) {
        sendPing();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    
    if (_status != WebSocketStatus.reconnecting) {
      _setStatus(WebSocketStatus.reconnecting);
    }
    
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('[WebSocket] Attempting to reconnect...');
      connect();
    });
  }

  void sendPing() {
    if (_channel != null && _status == WebSocketStatus.connected) {
      try {
        _channel!.sink.add(json.encode({'type': 'ping'}));
      } catch (e) {
        debugPrint('[WebSocket] Error sending ping: $e');
      }
    }
  }

  void subscribe(String market) {
    if (_channel != null && _status == WebSocketStatus.connected) {
      try {
        _channel!.sink.add(json.encode({
          'type': 'subscribe',
          'market': market, // 'crypto', 'thai_stock', or 'all'
        }));
        debugPrint('[WebSocket] Subscribed to: $market');
      } catch (e) {
        debugPrint('[WebSocket] Error subscribing: $e');
      }
    }
  }

  void unsubscribe(String market) {
    if (_channel != null && _status == WebSocketStatus.connected) {
      try {
        _channel!.sink.add(json.encode({
          'type': 'unsubscribe',
          'market': market,
        }));
      } catch (e) {
        debugPrint('[WebSocket] Error unsubscribing: $e');
      }
    }
  }

  Future<void> disconnect() async {
    debugPrint('[WebSocket] Disconnecting...');
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    
    try {
      await _channel?.sink.close();
    } catch (e) {
      debugPrint('[WebSocket] Error closing: $e');
    }
    
    _channel = null;
    _setStatus(WebSocketStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _signalStreamController.close();
    _statusStreamController.close();
  }
}

/// Model for signal updates from WebSocket
class SignalUpdate {
  final String type;
  final String market;
  final List<Signal> signals;
  final List<Signal>? changedSignals;
  final DateTime timestamp;

  SignalUpdate({
    required this.type,
    required this.market,
    required this.signals,
    this.changedSignals,
    required this.timestamp,
  });

  factory SignalUpdate.fromJson(Map<String, dynamic> json) {
    final signalsList = (json['signals'] as List?)
        ?.map((s) => Signal.fromJson({
              ...s as Map<String, dynamic>,
              'market_type': json['market'] ?? 'crypto',
            }))
        .toList() ?? [];

    final changedList = (json['changed_signals'] as List?)
        ?.map((s) => Signal.fromJson({
              ...s as Map<String, dynamic>,
              'market_type': json['market'] ?? 'crypto',
            }))
        .toList();

    return SignalUpdate(
      type: json['type'] as String? ?? 'unknown',
      market: json['market'] as String? ?? 'all',
      signals: signalsList,
      changedSignals: changedList,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? 
                 DateTime.now(),
    );
  }
}
