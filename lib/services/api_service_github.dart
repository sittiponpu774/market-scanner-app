import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/signal.dart';
import '../models/chart_data.dart';

/// API Service for GitHub Pages Static JSON API
/// Data is updated every 5 minutes via GitHub Actions
class ApiService {
  // ===========================================
  // CONFIGURATION - Update with your GitHub username
  // ===========================================
  
  /// GitHub Pages base URL - CHANGE THIS!
  /// Format: https://<username>.github.io/<repo-name>/data
  static const String baseUrl = 'https://sittiponpu774.github.io/market-scanner-api/data';
  
  /// Fallback to local API for development
  static const String localUrl = 'http://localhost:8000';
  
  /// Use GitHub Pages (true) or local API (false)
  /// Set to true for production
  static const bool useGitHubPages = true;
  
  // ===========================================
  // INTERNAL
  // ===========================================
  
  String get _baseUrl => useGitHubPages ? baseUrl : localUrl;
  
  final http.Client _client = http.Client();
  
  /// Cache for reducing API calls
  Map<String, dynamic>? _cryptoCache;
  Map<String, dynamic>? _thaiCache;
  DateTime? _lastFetch;
  
  /// Cache duration (30 seconds)
  static const Duration _cacheDuration = Duration(seconds: 30);
  
  // ===========================================
  // PUBLIC METHODS
  // ===========================================
  
  /// Health check
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/health.json'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Health check failed: ${response.statusCode}');
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }
  
  /// Get all crypto signals
  Future<List<Signal>> getCryptoSignals() async {
    try {
      // Check cache
      if (_isCacheValid() && _cryptoCache != null) {
        return _parseSignals(_cryptoCache!['data'], 'crypto');
      }
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/crypto_signals.json'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cryptoCache = {'data': data};
        _lastFetch = DateTime.now();
        return _parseSignals(data, 'crypto');
      }
      throw Exception('Failed to load crypto signals: ${response.statusCode}');
    } catch (e) {
      print('Error fetching crypto signals: $e');
      return [];
    }
  }
  
  /// Get all Thai stock signals
  Future<List<Signal>> getThaiSignals() async {
    try {
      // Check cache
      if (_isCacheValid() && _thaiCache != null) {
        return _parseSignals(_thaiCache!['data'], 'thai');
      }
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/thai_signals.json'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _thaiCache = {'data': data};
        _lastFetch = DateTime.now();
        return _parseSignals(data, 'thai');
      }
      throw Exception('Failed to load Thai signals: ${response.statusCode}');
    } catch (e) {
      print('Error fetching Thai signals: $e');
      return [];
    }
  }
  
  /// Get all signals (both crypto and Thai)
  Future<Map<String, List<Signal>>> getAllSignals() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/all_signals.json'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {
          'crypto': _parseSignals(data['crypto'] ?? [], 'crypto'),
          'thai': _parseSignals(data['thai'] ?? [], 'thai'),
        };
      }
      throw Exception('Failed to load all signals');
    } catch (e) {
      print('Error fetching all signals: $e');
      // Fallback to individual fetches
      return {
        'crypto': await getCryptoSignals(),
        'thai': await getThaiSignals(),
      };
    }
  }
  
  /// Get signal by symbol
  Future<Signal?> getSignal(String symbol, String market) async {
    final signals = market == 'crypto' 
        ? await getCryptoSignals() 
        : await getThaiSignals();
    
    try {
      return signals.firstWhere(
        (s) => s.symbol.toLowerCase() == symbol.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Search crypto by symbol (uses Binance API directly with real indicators)
  Future<Signal?> searchCrypto(String symbol) async {
    try {
      final pair = symbol.toUpperCase().endsWith('USDT') 
          ? symbol.toUpperCase() 
          : '${symbol.toUpperCase()}USDT';
      
      // Fetch both ticker and klines for real-time data with indicators
      final tickerFuture = _client.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=$pair'),
      ).timeout(const Duration(seconds: 10));
      
      final klinesFuture = _client.get(
        Uri.parse('https://api.binance.com/api/v3/klines?symbol=$pair&interval=1h&limit=100'),
      ).timeout(const Duration(seconds: 10));
      
      final responses = await Future.wait([tickerFuture, klinesFuture]);
      final tickerResponse = responses[0];
      final klinesResponse = responses[1];
      
      if (tickerResponse.statusCode == 200 && klinesResponse.statusCode == 200) {
        final data = json.decode(tickerResponse.body);
        final List<dynamic> klines = json.decode(klinesResponse.body);
        
        // Extract close prices for indicator calculation
        final closePrices = klines.map((k) => double.parse(k[4] as String)).toList();
        
        // Calculate technical indicators
        final rsi = _calculateRSI(closePrices, period: 14);
        final macdResult = _calculateMACD(closePrices);
        final macdValue = macdResult['macd'] ?? 0.0;
        final macdSignalValue = macdResult['signal'] ?? 0.0;
        final histogram = macdResult['histogram'] ?? 0.0;
        
        // Generate trading signal
        final signalResult = _generateSignal(rsi, macdValue, macdSignalValue, histogram);
        
        return Signal(
          symbol: symbol.toUpperCase(),
          price: double.parse(data['lastPrice']),
          changePercent: double.parse(data['priceChangePercent']),
          volume: double.parse(data['volume']),
          rsi: rsi,
          macd: macdValue,
          macdSignal: macdSignalValue,
          signalType: signalResult['signal'],
          confidence: signalResult['confidence'],
          marketType: 'crypto',
          timestamp: DateTime.now(),
          additionalData: {
            'high24h': double.parse(data['highPrice']),
            'low24h': double.parse(data['lowPrice']),
            'histogram': histogram,
          },
        );
      }
      return null;
    } catch (e) {
      print('Error searching crypto: $e');
      return null;
    }
  }
  
  // Calculate RSI (Relative Strength Index)
  double _calculateRSI(List<double> prices, {int period = 14}) {
    if (prices.length < period + 1) return 50.0;
    
    List<double> gains = [];
    List<double> losses = [];
    
    for (int i = 1; i < prices.length; i++) {
      final change = prices[i] - prices[i - 1];
      if (change > 0) {
        gains.add(change);
        losses.add(0);
      } else {
        gains.add(0);
        losses.add(change.abs());
      }
    }
    
    double avgGain = 0;
    double avgLoss = 0;
    for (int i = 0; i < period; i++) {
      avgGain += gains[i];
      avgLoss += losses[i];
    }
    avgGain /= period;
    avgLoss /= period;
    
    for (int i = period; i < gains.length; i++) {
      avgGain = (avgGain * (period - 1) + gains[i]) / period;
      avgLoss = (avgLoss * (period - 1) + losses[i]) / period;
    }
    
    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
  
  // Calculate MACD
  Map<String, double> _calculateMACD(List<double> prices, {int fast = 12, int slow = 26, int signalPeriod = 9}) {
    if (prices.length < slow + signalPeriod) {
      return {'macd': 0.0, 'signal': 0.0, 'histogram': 0.0};
    }
    
    final emaFast = _calculateEMA(prices, fast);
    final emaSlow = _calculateEMA(prices, slow);
    
    List<double> macdLine = [];
    final startIdx = slow - 1;
    for (int i = startIdx; i < prices.length; i++) {
      final fastIdx = i - (slow - fast);
      if (fastIdx >= 0 && fastIdx < emaFast.length && (i - startIdx) < emaSlow.length) {
        macdLine.add(emaFast[fastIdx] - emaSlow[i - startIdx]);
      }
    }
    
    if (macdLine.isEmpty) {
      return {'macd': 0.0, 'signal': 0.0, 'histogram': 0.0};
    }
    
    final signalLine = _calculateEMA(macdLine, signalPeriod);
    
    final currentMacd = macdLine.last;
    final currentSignal = signalLine.isNotEmpty ? signalLine.last : 0.0;
    final histogram = currentMacd - currentSignal;
    
    return {'macd': currentMacd, 'signal': currentSignal, 'histogram': histogram};
  }
  
  // Calculate EMA
  List<double> _calculateEMA(List<double> prices, int period) {
    if (prices.isEmpty || prices.length < period) return [];
    
    final multiplier = 2.0 / (period + 1);
    List<double> ema = [];
    
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += prices[i];
    }
    ema.add(sum / period);
    
    for (int i = period; i < prices.length; i++) {
      final newEma = (prices[i] - ema.last) * multiplier + ema.last;
      ema.add(newEma);
    }
    
    return ema;
  }
  
  // Generate trading signal
  Map<String, dynamic> _generateSignal(double rsi, double macd, double macdSignal, double histogram) {
    int buyScore = 0;
    int sellScore = 0;
    
    if (rsi < 30) {
      buyScore += 2;
    } else if (rsi < 40) {
      buyScore += 1;
    } else if (rsi > 70) {
      sellScore += 2;
    } else if (rsi > 60) {
      sellScore += 1;
    }
    
    if (macd > macdSignal && histogram > 0) {
      buyScore += 2;
    } else if (macd > macdSignal) {
      buyScore += 1;
    } else if (macd < macdSignal && histogram < 0) {
      sellScore += 2;
    } else if (macd < macdSignal) {
      sellScore += 1;
    }
    
    if (histogram > 0) {
      buyScore += 1;
    } else if (histogram < 0) {
      sellScore += 1;
    }
    
    String signal;
    double confidence;
    final totalScore = buyScore + sellScore;
    
    if (buyScore > sellScore + 1) {
      signal = 'BUY';
      confidence = totalScore > 0 ? (buyScore / totalScore).clamp(0.5, 0.95) : 0.5;
    } else if (sellScore > buyScore + 1) {
      signal = 'SELL';
      confidence = totalScore > 0 ? (sellScore / totalScore).clamp(0.5, 0.95) : 0.5;
    } else {
      signal = 'HOLD';
      confidence = 0.5;
    }
    
    return {'signal': signal, 'confidence': confidence};
  }
  
  /// Search Thai stock by symbol (uses Yahoo Finance with real indicators)
  Future<Signal?> searchThai(String symbol) async {
    try {
      final yahooSymbol = symbol.toUpperCase().endsWith('.BK') 
          ? symbol.toUpperCase() 
          : '${symbol.toUpperCase()}.BK';
      
      // Fetch chart data with enough history for indicators
      final response = await _client.get(
        Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=1h&range=1mo'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']['result']?[0];
        if (result == null) return null;
        
        final meta = result['meta'];
        final price = meta['regularMarketPrice']?.toDouble() ?? 0.0;
        final prevClose = meta['previousClose']?.toDouble() ?? price;
        final change = prevClose > 0 ? ((price - prevClose) / prevClose * 100) : 0.0;
        
        // Extract close prices for indicator calculation
        final quotes = result['indicators']['quote']?[0] ?? {};
        final closesList = (quotes['close'] as List?) ?? [];
        final volumes = (quotes['volume'] as List?) ?? [];
        
        final closePrices = closesList
            .where((c) => c != null)
            .map((c) => (c as num).toDouble())
            .toList();
        
        // Calculate volume
        double totalVolume = 0;
        for (var v in volumes) {
          if (v != null) totalVolume += (v as num).toDouble();
        }
        
        // Calculate technical indicators
        double rsi = 50.0;
        double macdValue = 0.0;
        double macdSignalValue = 0.0;
        double histogram = 0.0;
        String signalType = 'HOLD';
        double confidence = 0.5;
        
        if (closePrices.length >= 30) {
          rsi = _calculateRSI(closePrices, period: 14);
          final macdResult = _calculateMACD(closePrices);
          macdValue = macdResult['macd'] ?? 0.0;
          macdSignalValue = macdResult['signal'] ?? 0.0;
          histogram = macdResult['histogram'] ?? 0.0;
          
          final signalResult = _generateSignal(rsi, macdValue, macdSignalValue, histogram);
          signalType = signalResult['signal'];
          confidence = signalResult['confidence'];
        }
        
        // Get high/low from prices
        double high24h = price;
        double low24h = price;
        if (closePrices.isNotEmpty) {
          high24h = closePrices.reduce((a, b) => a > b ? a : b);
          low24h = closePrices.reduce((a, b) => a < b ? a : b);
        }
        
        return Signal(
          symbol: symbol.toUpperCase().replaceAll('.BK', ''),
          price: price,
          changePercent: change,
          volume: totalVolume,
          rsi: rsi,
          macd: macdValue,
          macdSignal: macdSignalValue,
          signalType: signalType,
          confidence: confidence,
          marketType: 'thai_stock',
          timestamp: DateTime.now(),
          additionalData: {
            'high24h': high24h,
            'low24h': low24h,
            'histogram': histogram,
          },
        );
      }
      return null;
    } catch (e) {
      print('Error searching Thai stock: $e');
      return null;
    }
  }
  
  /// Get chart data for crypto (from Binance)
  Future<ChartData?> getCryptoChart(String symbol) async {
    try {
      final pair = symbol.toUpperCase().endsWith('USDT') 
          ? symbol.toUpperCase() 
          : '${symbol.toUpperCase()}USDT';
      
      final response = await _client.get(
        Uri.parse('https://api.binance.com/api/v3/klines?symbol=$pair&interval=1h&limit=168'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> klines = json.decode(response.body);
        final prices = klines.map((k) {
          final time = DateTime.fromMillisecondsSinceEpoch(k[0] as int);
          return PriceData(
            time: time,
            open: double.parse(k[1] as String),
            high: double.parse(k[2] as String),
            low: double.parse(k[3] as String),
            close: double.parse(k[4] as String),
            volume: double.parse(k[5] as String),
          );
        }).toList();
        
        return ChartData(
          prices: prices,
          rsiData: [],
          macdData: [],
          macdSignalData: [],
        );
      }
      return null;
    } catch (e) {
      print('Error fetching crypto chart: $e');
      return null;
    }
  }
  
  /// Get chart data for Thai stock (from Yahoo)
  Future<ChartData?> getThaiChart(String symbol) async {
    try {
      final yahooSymbol = symbol.toUpperCase().endsWith('.BK') 
          ? symbol.toUpperCase() 
          : '${symbol.toUpperCase()}.BK';
      
      final response = await _client.get(
        Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=1h&range=7d'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']['result']?[0];
        if (result != null) {
          final timestamps = (result['timestamp'] as List?) ?? [];
          final quotes = result['indicators']['quote']?[0] ?? {};
          final opens = (quotes['open'] as List?) ?? [];
          final highs = (quotes['high'] as List?) ?? [];
          final lows = (quotes['low'] as List?) ?? [];
          final closes = (quotes['close'] as List?) ?? [];
          final volumes = (quotes['volume'] as List?) ?? [];
          
          final prices = <PriceData>[];
          for (int i = 0; i < timestamps.length; i++) {
            if (timestamps[i] != null && closes[i] != null) {
              prices.add(PriceData(
                time: DateTime.fromMillisecondsSinceEpoch((timestamps[i] as int) * 1000),
                open: (opens.length > i ? opens[i] ?? 0 : 0).toDouble(),
                high: (highs.length > i ? highs[i] ?? 0 : 0).toDouble(),
                low: (lows.length > i ? lows[i] ?? 0 : 0).toDouble(),
                close: (closes[i] ?? 0).toDouble(),
                volume: (volumes.length > i ? volumes[i] ?? 0 : 0).toDouble(),
              ));
            }
          }
          
          return ChartData(
            prices: prices,
            rsiData: [],
            macdData: [],
            macdSignalData: [],
          );
        }
      }
      return null;
    } catch (e) {
      print('Error fetching Thai chart: $e');
      return null;
    }
  }
  
  /// Clear cache
  void clearCache() {
    _cryptoCache = null;
    _thaiCache = null;
    _lastFetch = null;
  }
  
  /// Dispose client
  void dispose() {
    _client.close();
  }
  
  // ===========================================
  // PRIVATE METHODS
  // ===========================================
  
  bool _isCacheValid() {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!) < _cacheDuration;
  }
  
  List<Signal> _parseSignals(List<dynamic> data, String market) {
    return data.map((item) {
      try {
        // Handle MACD - can be object or number
        double macdValue = 0;
        double macdSignalValue = 0;
        if (item['macd'] != null) {
          if (item['macd'] is Map) {
            macdValue = (item['macd']['macd'] ?? 0).toDouble();
            macdSignalValue = (item['macd']['signal'] ?? 0).toDouble();
          } else {
            macdValue = (item['macd'] ?? 0).toDouble();
            macdSignalValue = (item['macd_signal'] ?? 0).toDouble();
          }
        }
        
        return Signal(
          symbol: item['symbol'] ?? '',
          price: (item['price'] ?? 0).toDouble(),
          changePercent: (item['change_24h'] ?? item['change_percent'] ?? 0).toDouble(),
          volume: (item['volume_24h'] ?? item['volume'] ?? 0).toDouble(),
          rsi: (item['rsi'] ?? 50).toDouble(),
          macd: macdValue,
          macdSignal: macdSignalValue,
          signalType: item['signal'] ?? item['signalType'] ?? 'HOLD',
          confidence: (item['strength'] ?? item['confidence'] ?? 0.5).toDouble(),
          marketType: market == 'crypto' ? 'crypto' : 'thai_stock',
          timestamp: DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime.now(),
          additionalData: {
            'name': item['name'] ?? item['symbol'] ?? '',
            'high24h': (item['high_24h'] ?? 0).toDouble(),
            'low24h': (item['low_24h'] ?? 0).toDouble(),
          },
        );
      } catch (e) {
        print('Error parsing signal: $e');
        return null;
      }
    }).whereType<Signal>().toList();
  }
}
