import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/binance_websocket_service.dart';
import '../models/models.dart';

/// Provider for Binance WebSocket real-time prices
class BinanceProvider extends ChangeNotifier {
  final BinanceWebSocketService _wsService = BinanceWebSocketService();
  
  // State
  BinanceConnectionStatus _status = BinanceConnectionStatus.disconnected;
  final Map<String, BinancePriceUpdate> _prices = {};
  bool _isEnabled = true;
  final Set<String> _allSubscribedSymbols = {};
  
  // Stream subscriptions
  StreamSubscription? _priceSubscription;
  StreamSubscription? _statusSubscription;
  
  // Getters
  BinanceConnectionStatus get status => _status;
  bool get isConnected => _status == BinanceConnectionStatus.connected;
  bool get isEnabled => _isEnabled;
  Map<String, BinancePriceUpdate> get prices => Map.unmodifiable(_prices);
  int get subscribedCount => _allSubscribedSymbols.length;
  
  /// Get price for a specific symbol
  /// Accepts formats: BTC, BTC/USDT, BTCUSDT
  BinancePriceUpdate? getPrice(String symbol) {
    // Normalize symbol: remove /USDT and USDT suffix
    final normalized = symbol.toUpperCase()
        .replaceAll('/USDT', '')
        .replaceAll('USDT', '');
    return _prices[normalized];
  }
  
  /// Get current price value for a symbol
  double? getCurrentPrice(String symbol) {
    return getPrice(symbol)?.price;
  }
  
  /// Get 24h change percent for a symbol
  double? getChangePercent(String symbol) {
    return _prices[symbol.toUpperCase()]?.priceChangePercent;
  }

  /// Initialize and connect
  Future<void> initialize() async {
    if (!_isEnabled) return;
    
    // Listen to status changes
    _statusSubscription = _wsService.statusStream.listen((status) {
      _status = status;
      notifyListeners();
    });
    
    // Listen to price updates
    _priceSubscription = _wsService.priceStream.listen((update) {
      _prices[update.symbol] = update;
      notifyListeners();
    });
    
    // Connect with default symbols (will be expanded when signals load)
    await _wsService.connectDefault();
    _allSubscribedSymbols.addAll(_wsService.subscribedSymbols);
  }

  /// Connect with specific symbols
  Future<void> connect(List<String> symbols) async {
    if (!_isEnabled) return;
    await _wsService.connect(symbols);
    _allSubscribedSymbols.clear();
    _allSubscribedSymbols.addAll(symbols.map((s) => s.toUpperCase()));
  }

  /// Add more symbols to watch (from signals or search)
  Future<void> addSymbols(List<String> symbols) async {
    if (!_isEnabled) return;
    
    // Filter only new symbols
    final newSymbols = symbols
        .map((s) => s.toUpperCase().replaceAll('/USDT', '').replaceAll('USDT', ''))
        .where((s) => !_allSubscribedSymbols.contains(s) && s.isNotEmpty)
        .toList();
    
    if (newSymbols.isEmpty) return;
    
    debugPrint('[BinanceProvider] Adding ${newSymbols.length} new symbols: ${newSymbols.take(10).join(", ")}...');
    
    _allSubscribedSymbols.addAll(newSymbols);
    await _wsService.addSymbols(newSymbols);
  }

  /// Subscribe to all symbols from crypto signals list
  Future<void> subscribeFromSignals(List<Signal> signals) async {
    if (!_isEnabled) return;
    
    final cryptoSymbols = signals
        .where((s) => s.marketType == 'crypto')
        .map((s) => s.symbol.toUpperCase().replaceAll('/USDT', '').replaceAll('USDT', ''))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    
    if (cryptoSymbols.isEmpty) return;
    
    debugPrint('[BinanceProvider] Subscribing to ${cryptoSymbols.length} crypto symbols from signals');
    
    await addSymbols(cryptoSymbols);
  }

  /// Add a single symbol (for search results)
  Future<void> addSymbol(String symbol) async {
    await addSymbols([symbol]);
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _wsService.disconnect();
    _prices.clear();
    notifyListeners();
  }

  /// Enable/disable real-time updates
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      initialize();
    } else {
      disconnect();
    }
    notifyListeners();
  }

  /// Update a signal with real-time price
  Signal? updateSignalWithRealTime(Signal signal) {
    if (signal.marketType != 'crypto') return null;
    
    final update = _prices[signal.symbol.toUpperCase()];
    if (update == null) return null;
    
    return signal.withRealTimePrice(update);
  }

  /// Update list of signals with real-time prices
  List<Signal> updateSignalsWithRealTime(List<Signal> signals) {
    return signals.map((signal) {
      if (signal.marketType != 'crypto') return signal;
      return updateSignalWithRealTime(signal) ?? signal;
    }).toList();
  }

  @override
  void dispose() {
    _priceSubscription?.cancel();
    _statusSubscription?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}
