import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'websocket_service.dart' show SignalUpdate;

enum ConnectionMode {
  websocket,
  polling,
}

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Service that supports both WebSocket (FastAPI) and Polling (CI3/PHP)
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // Connection mode
  ConnectionMode _mode = ConnectionMode.polling; // Default to polling for CI3
  
  // WebSocket related
  WebSocketChannel? _channel;
  String _wsUrl = 'ws://localhost:8000/ws/signals';
  
  // Polling related
  String _pollUrl = 'http://localhost:8000/api/poll/signals';
  Timer? _pollTimer;
  Duration _pollInterval = const Duration(seconds: 10);
  
  // Common
  WebSocketStatus _status = WebSocketStatus.disconnected;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  
  // Stream controllers
  final _signalStreamController = StreamController<SignalUpdate>.broadcast();
  final _statusStreamController = StreamController<WebSocketStatus>.broadcast();
  
  // Getters
  Stream<SignalUpdate> get signalStream => _signalStreamController.stream;
  Stream<WebSocketStatus> get statusStream => _statusStreamController.stream;
  WebSocketStatus get status => _status;
  bool get isConnected => _status == WebSocketStatus.connected;
  ConnectionMode get mode => _mode;

  /// Set connection mode
  void setConnectionMode(ConnectionMode mode) {
    _mode = mode;
    debugPrint('[WebSocket] Mode set to: ${mode.name}');
  }

  /// Set base URL - automatically detects and sets appropriate URLs
  void setBaseUrl(String httpUrl) {
    // Clean up URL
    String cleanUrl = httpUrl.endsWith('/') 
        ? httpUrl.substring(0, httpUrl.length - 1) 
        : httpUrl;
    
    // Set polling URL
    _pollUrl = '$cleanUrl/api/poll/signals';
    
    // Set WebSocket URL
    String wsUrl = cleanUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    _wsUrl = '$wsUrl/ws/signals';
    
    debugPrint('[WebSocket] Poll URL: $_pollUrl');
    debugPrint('[WebSocket] WS URL: $_wsUrl');
  }

  /// Set polling interval
  void setPollInterval(Duration interval) {
    _pollInterval = interval;
    if (_mode == ConnectionMode.polling && _status == WebSocketStatus.connected) {
      _startPolling();
    }
  }

  /// Connect using the configured mode
  Future<void> connect() async {
    if (_status == WebSocketStatus.connected || 
        _status == WebSocketStatus.connecting) {
      return;
    }

    if (_mode == ConnectionMode.websocket) {
      await _connectWebSocket();
    } else {
      await _connectPolling();
    }
  }

  /// Connect via WebSocket
  Future<void> _connectWebSocket() async {
    _setStatus(WebSocketStatus.connecting);
    
    try {
      debugPrint('[WebSocket] Connecting to $_wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      
      await _channel!.ready;
      
      _setStatus(WebSocketStatus.connected);
      debugPrint('[WebSocket] Connected successfully');
      
      _channel!.stream.listen(
        _onWebSocketMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      
      _startPingTimer();
      
    } catch (e) {
      debugPrint('[WebSocket] Connection error: $e');
      _setStatus(WebSocketStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// Connect via Polling
  Future<void> _connectPolling() async {
    _setStatus(WebSocketStatus.connecting);
    
    try {
      debugPrint('[Polling] Starting polling from $_pollUrl');
      
      // Test connection first
      final response = await http.get(
        Uri.parse(_pollUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        _setStatus(WebSocketStatus.connected);
        debugPrint('[Polling] Connected successfully');
        
        // Process initial data
        _onPollingMessage(response.body);
        
        // Start polling
        _startPolling();
      } else {
        throw Exception('Failed to connect: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[Polling] Connection error: $e');
      _setStatus(WebSocketStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// Start polling timer
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (timer) async {
      if (_status == WebSocketStatus.connected) {
        await _poll();
      }
    });
  }

  /// Single poll request
  Future<void> _poll() async {
    try {
      final response = await http.get(
        Uri.parse(_pollUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        _onPollingMessage(response.body);
      }
    } catch (e) {
      debugPrint('[Polling] Error: $e');
      // Don't disconnect on single failure
    }
  }

  /// Handle WebSocket message
  void _onWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      debugPrint('[WebSocket] Received: ${data['type']}');
      
      if (data['type'] == 'signal_update' || data['type'] == 'initial_data') {
        final update = SignalUpdate.fromJson(data);
        _signalStreamController.add(update);
      } else if (data['type'] == 'pong') {
        debugPrint('[WebSocket] Pong received');
      }
    } catch (e) {
      debugPrint('[WebSocket] Error parsing message: $e');
    }
  }

  /// Handle Polling message
  void _onPollingMessage(String message) {
    try {
      final data = json.decode(message);
      debugPrint('[Polling] Received update');
      
      if (data['type'] == 'signal_update' || data['type'] == 'no_change') {
        final update = SignalUpdate.fromJson(data);
        _signalStreamController.add(update);
      }
    } catch (e) {
      debugPrint('[Polling] Error parsing message: $e');
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
      if (_status == WebSocketStatus.connected && _mode == ConnectionMode.websocket) {
        sendPing();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _pollTimer?.cancel();
    
    if (_status != WebSocketStatus.reconnecting) {
      _setStatus(WebSocketStatus.reconnecting);
    }
    
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('[Service] Attempting to reconnect...');
      connect();
    });
  }

  void sendPing() {
    if (_channel != null && _status == WebSocketStatus.connected && _mode == ConnectionMode.websocket) {
      try {
        _channel!.sink.add(json.encode({'type': 'ping'}));
      } catch (e) {
        debugPrint('[WebSocket] Error sending ping: $e');
      }
    }
  }

  void subscribe(String market) {
    if (_mode == ConnectionMode.websocket && _channel != null && _status == WebSocketStatus.connected) {
      try {
        _channel!.sink.add(json.encode({
          'type': 'subscribe',
          'market': market,
        }));
        debugPrint('[WebSocket] Subscribed to: $market');
      } catch (e) {
        debugPrint('[WebSocket] Error subscribing: $e');
      }
    }
    // For polling, market filter is handled server-side
  }

  void unsubscribe(String market) {
    if (_mode == ConnectionMode.websocket && _channel != null && _status == WebSocketStatus.connected) {
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
    debugPrint('[Service] Disconnecting...');
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _pollTimer?.cancel();
    
    if (_mode == ConnectionMode.websocket) {
      try {
        await _channel?.sink.close();
      } catch (e) {
        debugPrint('[WebSocket] Error closing: $e');
      }
      _channel = null;
    }
    
    _setStatus(WebSocketStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _signalStreamController.close();
    _statusStreamController.close();
  }
}
