import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

/// Real-time price update from Binance WebSocket
class BinancePriceUpdate {
  final String symbol;
  final double price;
  final double priceChange;
  final double priceChangePercent;
  final double high24h;
  final double low24h;
  final double volume;
  final DateTime timestamp;

  BinancePriceUpdate({
    required this.symbol,
    required this.price,
    required this.priceChange,
    required this.priceChangePercent,
    required this.high24h,
    required this.low24h,
    required this.volume,
    required this.timestamp,
  });

  factory BinancePriceUpdate.fromTicker(Map<String, dynamic> data) {
    return BinancePriceUpdate(
      symbol: (data['s'] as String?)?.replaceAll('USDT', '') ?? '',
      price: double.tryParse(data['c']?.toString() ?? '0') ?? 0,
      priceChange: double.tryParse(data['p']?.toString() ?? '0') ?? 0,
      priceChangePercent: double.tryParse(data['P']?.toString() ?? '0') ?? 0,
      high24h: double.tryParse(data['h']?.toString() ?? '0') ?? 0,
      low24h: double.tryParse(data['l']?.toString() ?? '0') ?? 0,
      volume: double.tryParse(data['v']?.toString() ?? '0') ?? 0,
      timestamp: DateTime.now(),
    );
  }
}

/// Binance WebSocket connection status
enum BinanceConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Binance WebSocket Service for real-time crypto prices
class BinanceWebSocketService {
  static final BinanceWebSocketService _instance = BinanceWebSocketService._internal();
  factory BinanceWebSocketService() => _instance;
  BinanceWebSocketService._internal();

  // WebSocket connections (multiple for many symbols)
  final List<WebSocketChannel> _channels = [];
  final List<StreamSubscription> _subscriptions = [];
  
  // Reconnection
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxSymbolsPerConnection = 50; // Binance recommends max 200, we use 50 for safety
  
  // State
  BinanceConnectionStatus _status = BinanceConnectionStatus.disconnected;
  final Set<String> _subscribedSymbols = {};
  
  // Stream controllers
  final _priceStreamController = StreamController<BinancePriceUpdate>.broadcast();
  final _statusStreamController = StreamController<BinanceConnectionStatus>.broadcast();
  
  // Getters
  Stream<BinancePriceUpdate> get priceStream => _priceStreamController.stream;
  Stream<BinanceConnectionStatus> get statusStream => _statusStreamController.stream;
  BinanceConnectionStatus get status => _status;
  bool get isConnected => _status == BinanceConnectionStatus.connected;
  Set<String> get subscribedSymbols => Set.unmodifiable(_subscribedSymbols);

  /// Connect to Binance WebSocket with multiple symbols
  Future<void> connect(List<String> symbols) async {
    if (symbols.isEmpty) return;
    
    // Close existing connections
    await disconnect();
    
    _updateStatus(BinanceConnectionStatus.connecting);
    _subscribedSymbols.clear();
    _subscribedSymbols.addAll(symbols.map((s) => s.toUpperCase()));
    
    try {
      // Split symbols into chunks to avoid URL length limits
      final symbolList = symbols.toList();
      final chunks = <List<String>>[];
      
      for (var i = 0; i < symbolList.length; i += _maxSymbolsPerConnection) {
        final end = (i + _maxSymbolsPerConnection < symbolList.length) 
            ? i + _maxSymbolsPerConnection 
            : symbolList.length;
        chunks.add(symbolList.sublist(i, end));
      }
      
      print('[BinanceWS] 🔌 Connecting with ${chunks.length} connection(s) for ${symbols.length} symbols');
      
      // Create connection for each chunk
      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final streams = chunk
            .map((s) => '${s.toLowerCase()}usdt@ticker')
            .join('/');
        
        final wsUrl = 'wss://stream.binance.com:9443/stream?streams=$streams';
        
        print('[BinanceWS] Connection ${i + 1}: ${chunk.length} symbols -> $wsUrl');
        
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
        _channels.add(channel);
        
        final subscription = channel.stream.listen(
          _handleMessage,
          onError: (error) {
            print('[BinanceWS] ❌ Stream error: $error');
            _handleError(error);
          },
          onDone: () {
            print('[BinanceWS] ⚠️ Stream closed for connection ${i + 1}');
            _handleDone(i);
          },
        );
        _subscriptions.add(subscription);
      }
      
      _updateStatus(BinanceConnectionStatus.connected);
      _reconnectAttempts = 0;
      
      // Start ping timer to keep connection alive
      _startPingTimer();
      
      print('[BinanceWS] ✅ Connected successfully! Total symbols: ${symbols.length}');
    } catch (e) {
      print('[BinanceWS] ❌ Connection error: $e');
      _updateStatus(BinanceConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  /// Connect with default crypto list
  Future<void> connectDefault() async {
    // Top 30 cryptos by market cap
    final defaultSymbols = [
      'BTC', 'ETH', 'BNB', 'XRP', 'ADA', 'DOGE', 'SOL', 'TRX', 'DOT', 'MATIC',
      'LTC', 'SHIB', 'AVAX', 'LINK', 'ATOM', 'UNI', 'XMR', 'ETC', 'XLM', 'BCH',
      'FIL', 'APT', 'NEAR', 'VET', 'ALGO', 'ICP', 'GRT', 'FTM', 'SAND', 'MANA',
    ];
    await connect(defaultSymbols);
  }

  /// Add more symbols to subscription
  Future<void> addSymbols(List<String> newSymbols) async {
    final allSymbols = {..._subscribedSymbols, ...newSymbols.map((s) => s.toUpperCase())};
    await connect(allSymbols.toList());
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    
    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    
    // Close all channels
    for (final channel in _channels) {
      await channel.sink.close();
    }
    _channels.clear();
    
    _updateStatus(BinanceConnectionStatus.disconnected);
    debugPrint('[BinanceWS] Disconnected');
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      
      // Binance stream format: { "stream": "btcusdt@ticker", "data": {...} }
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        final tickerData = data['data'] as Map<String, dynamic>;
        final update = BinancePriceUpdate.fromTicker(tickerData);
        
        if (update.symbol.isNotEmpty) {
          _priceStreamController.add(update);
        }
      }
    } catch (e) {
      debugPrint('[BinanceWS] Parse error: $e');
    }
  }

  /// Handle WebSocket error
  void _handleError(dynamic error) {
    debugPrint('[BinanceWS] Error: $error');
    _updateStatus(BinanceConnectionStatus.error);
    _scheduleReconnect();
  }

  /// Handle WebSocket connection closed
  void _handleDone(int connectionIndex) {
    debugPrint('[BinanceWS] Connection $connectionIndex closed');
    if (_status != BinanceConnectionStatus.disconnected) {
      // Only reconnect if this was unexpected
      if (_channels.isNotEmpty) {
        _updateStatus(BinanceConnectionStatus.disconnected);
        _scheduleReconnect();
      }
    }
  }

  /// Schedule reconnection
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[BinanceWS] Max reconnect attempts reached');
      _updateStatus(BinanceConnectionStatus.error);
      return;
    }
    
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    final delay = _reconnectDelay * _reconnectAttempts;
    debugPrint('[BinanceWS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    
    _updateStatus(BinanceConnectionStatus.reconnecting);
    
    _reconnectTimer = Timer(delay, () {
      if (_subscribedSymbols.isNotEmpty) {
        connect(_subscribedSymbols.toList());
      }
    });
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    // Binance WebSocket sends ping every 3 minutes, we respond with pong automatically
    // But we can send our own ping to check connection health
    _pingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_channels.isNotEmpty && isConnected) {
        try {
          // WebSocket ping is handled automatically by the library
          debugPrint('[BinanceWS] Connection alive check (${_channels.length} connections, ${_subscribedSymbols.length} symbols)');
        } catch (e) {
          debugPrint('[BinanceWS] Ping failed: $e');
          _scheduleReconnect();
        }
      }
    });
  }

  /// Update connection status
  void _updateStatus(BinanceConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusStreamController.add(newStatus);
      debugPrint('[BinanceWS] Status: ${newStatus.name}');
    }
  }

  /// Get latest price for a symbol (from cache or stream)
  final Map<String, BinancePriceUpdate> _priceCache = {};
  
  /// Listen and cache prices
  void startCaching() {
    priceStream.listen((update) {
      _priceCache[update.symbol] = update;
    });
  }
  
  /// Get cached price
  BinancePriceUpdate? getCachedPrice(String symbol) {
    return _priceCache[symbol.toUpperCase()];
  }
  
  /// Get all cached prices
  Map<String, BinancePriceUpdate> get allCachedPrices => Map.unmodifiable(_priceCache);

  /// Dispose service
  void dispose() {
    disconnect();
    _priceStreamController.close();
    _statusStreamController.close();
  }
}

/// Extension to update Signal with real-time price
extension SignalRealTimeUpdate on Signal {
  /// Create updated signal with new price
  Signal withRealTimePrice(BinancePriceUpdate update) {
    return Signal(
      symbol: symbol,
      price: update.price,
      changePercent: update.priceChangePercent,
      volume: update.volume,
      signalType: signalType,
      confidence: confidence,
      rsi: rsi,
      macd: macd,
      macdSignal: macdSignal,
      timestamp: update.timestamp,
      marketType: marketType,
    );
  }
}
