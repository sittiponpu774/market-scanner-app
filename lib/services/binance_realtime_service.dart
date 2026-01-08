import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to fetch realtime prices directly from Binance API
class BinanceRealtimeService {
  static const String _baseUrl = 'https://api.binance.com/api/v3';
  
  final http.Client _client = http.Client();
  
  /// Cache for prices (valid for 5 seconds)
  final Map<String, _PriceCache> _priceCache = {};
  static const Duration _cacheDuration = Duration(seconds: 5);
  
  /// Get realtime price for a single symbol
  Future<double?> getPrice(String symbol) async {
    // Convert ZIL/USDT -> ZILUSDT
    final binanceSymbol = symbol.replaceAll('/', '').toUpperCase();
    
    // Check cache
    final cached = _priceCache[binanceSymbol];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      return cached.price;
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/ticker/price?symbol=$binanceSymbol'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final price = double.parse(data['price']);
        
        // Cache it
        _priceCache[binanceSymbol] = _PriceCache(price: price, timestamp: DateTime.now());
        
        return price;
      }
    } catch (e) {
      print('⚠️ Error fetching price for $symbol: $e');
    }
    return null;
  }
  
  /// Get realtime prices for multiple symbols at once
  Future<Map<String, double>> getPrices(List<String> symbols) async {
    final result = <String, double>{};
    
    if (symbols.isEmpty) return result;
    
    try {
      // Fetch all tickers at once (more efficient)
      final response = await _client.get(
        Uri.parse('$_baseUrl/ticker/price'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final priceMap = <String, double>{};
        
        for (final item in data) {
          priceMap[item['symbol']] = double.parse(item['price']);
        }
        
        // Map requested symbols
        for (final symbol in symbols) {
          final binanceSymbol = symbol.replaceAll('/', '').toUpperCase();
          if (priceMap.containsKey(binanceSymbol)) {
            result[symbol] = priceMap[binanceSymbol]!;
            
            // Cache it
            _priceCache[binanceSymbol] = _PriceCache(
              price: priceMap[binanceSymbol]!,
              timestamp: DateTime.now(),
            );
          }
        }
      }
    } catch (e) {
      print('⚠️ Error fetching prices: $e');
      
      // Fallback: fetch individually
      for (final symbol in symbols) {
        final price = await getPrice(symbol);
        if (price != null) {
          result[symbol] = price;
        }
      }
    }
    
    return result;
  }
  
  /// Get 24hr ticker data (price + change %)
  Future<Map<String, dynamic>?> get24hrTicker(String symbol) async {
    final binanceSymbol = symbol.replaceAll('/', '').toUpperCase();
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/ticker/24hr?symbol=$binanceSymbol'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'price': double.parse(data['lastPrice']),
          'change': double.parse(data['priceChange']),
          'changePercent': double.parse(data['priceChangePercent']),
          'high': double.parse(data['highPrice']),
          'low': double.parse(data['lowPrice']),
          'volume': double.parse(data['volume']),
        };
      }
    } catch (e) {
      print('⚠️ Error fetching 24hr ticker for $symbol: $e');
    }
    return null;
  }
  
  void dispose() {
    _client.close();
    _priceCache.clear();
  }
}

class _PriceCache {
  final double price;
  final DateTime timestamp;
  
  _PriceCache({required this.price, required this.timestamp});
}
