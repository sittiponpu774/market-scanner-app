import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // GitHub Pages URL - Static JSON API
  String _baseUrl = 'https://sittiponpu774.github.io/market-scanner-api/data';
  
  // CORS proxy for web (Yahoo Finance blocks CORS)
  static const String _corsProxy = 'https://corsproxy.io/?';
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String get baseUrl => _baseUrl;
  
  // Check if using GitHub Pages (static JSON)
  bool get _isGitHubPages => _baseUrl.contains('github.io');
  
  // Helper: wrap URL with CORS proxy for web
  String _wrapCors(String url) {
    if (kIsWeb) {
      return '$_corsProxy${Uri.encodeComponent(url)}';
    }
    return url;
  }

  // Get all crypto signals
  Future<List<Signal>> getCryptoSignals({int? limit}) async {
    try {
      String url;
      if (_isGitHubPages) {
        url = '$_baseUrl/crypto_signals.json';
      } else {
        url = '$_baseUrl/api/crypto/signals';
        if (limit != null) {
          url += '?limit=$limit';
        }
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Signal> signals = data.map((json) => Signal.fromJson({...json, 'market_type': 'crypto'})).toList();
        if (limit != null && signals.length > limit) {
          signals = signals.take(limit).toList();
        }
        
        // Update prices with real-time data from Binance
        signals = await _updateCryptoPricesRealtime(signals);
        
        return signals;
      } else {
        throw Exception('Failed to load crypto signals: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // Update crypto prices and indicators with real-time data from Binance
  Future<List<Signal>> _updateCryptoPricesRealtime(List<Signal> signals) async {
    if (signals.isEmpty) return signals;
    
    try {
      // Fetch all tickers at once from Binance
      final tickerResponse = await http.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/24hr'),
      ).timeout(const Duration(seconds: 15));
      
      if (tickerResponse.statusCode != 200) return signals;
      
      final List<dynamic> tickers = json.decode(tickerResponse.body);
      
      // Create a map for quick lookup
      final tickerMap = <String, Map<String, dynamic>>{};
      for (var ticker in tickers) {
        tickerMap[ticker['symbol']] = ticker;
      }
      
      // Fetch klines for all signals in parallel (for indicator calculation)
      final List<Future<Signal>> futures = signals.map((signal) async {
        final pairSymbol = signal.symbol.toUpperCase().replaceAll('/', '');
        final pair = pairSymbol.endsWith('USDT') ? pairSymbol : '${pairSymbol}USDT';
        
        final ticker = tickerMap[pair];
        if (ticker == null) return signal;
        
        try {
          // Fetch klines for indicator calculation
          final klinesResponse = await http.get(
            Uri.parse('https://api.binance.com/api/v3/klines?symbol=$pair&interval=1h&limit=100'),
          ).timeout(const Duration(seconds: 10));
          
          if (klinesResponse.statusCode == 200) {
            final List<dynamic> klines = json.decode(klinesResponse.body);
            
            // Extract close prices for indicator calculation
            final closePrices = klines.map((k) => double.parse(k[4] as String)).toList();
            
            // Calculate technical indicators
            final rsi = _calculateRSI(closePrices, period: 14);
            final macdResult = _calculateMACD(closePrices);
            final macd = macdResult['macd'] ?? 0.0;
            final macdSignalVal = macdResult['signal'] ?? 0.0;
            final histogram = macdResult['histogram'] ?? 0.0;
            
            // Generate trading signal based on indicators
            final signalResult = _generateSignal(rsi, macd, macdSignalVal, histogram);
            
            return Signal(
              symbol: signal.symbol,
              price: double.tryParse(ticker['lastPrice'] ?? '0') ?? signal.price,
              changePercent: double.tryParse(ticker['priceChangePercent'] ?? '0') ?? signal.changePercent,
              volume: double.tryParse(ticker['volume'] ?? '0') ?? signal.volume,
              rsi: rsi,
              macd: macd,
              macdSignal: macdSignalVal,
              signalType: signalResult['signal'],
              confidence: signalResult['confidence'],
              marketType: signal.marketType,
              timestamp: DateTime.now(),
              additionalData: {
                'high24h': double.tryParse(ticker['highPrice'] ?? '0') ?? 0,
                'low24h': double.tryParse(ticker['lowPrice'] ?? '0') ?? 0,
                'histogram': histogram,
              },
            );
          }
        } catch (e) {
          // If klines fetch fails, just update price
        }
        
        // Fallback: just update price without recalculating indicators
        return Signal(
          symbol: signal.symbol,
          price: double.tryParse(ticker['lastPrice'] ?? '0') ?? signal.price,
          changePercent: double.tryParse(ticker['priceChangePercent'] ?? '0') ?? signal.changePercent,
          volume: double.tryParse(ticker['volume'] ?? '0') ?? signal.volume,
          rsi: signal.rsi,
          macd: signal.macd,
          macdSignal: signal.macdSignal,
          signalType: signal.signalType,
          confidence: signal.confidence,
          marketType: signal.marketType,
          timestamp: DateTime.now(),
          additionalData: {
            ...signal.additionalData ?? {},
            'high24h': double.tryParse(ticker['highPrice'] ?? '0') ?? 0,
            'low24h': double.tryParse(ticker['lowPrice'] ?? '0') ?? 0,
          },
        );
      }).toList();
      
      // Wait for all futures with concurrency limit
      final updatedSignals = await Future.wait(futures);
      return updatedSignals;
      
    } catch (e) {
      // If real-time update fails, return original signals
      print('Error updating real-time prices: $e');
    }
    
    return signals;
  }

  // Get all Thai stock signals
  Future<List<Signal>> getThaiStockSignals({int? limit}) async {
    try {
      String url;
      if (_isGitHubPages) {
        url = '$_baseUrl/thai_signals.json';
      } else {
        url = '$_baseUrl/api/thai/signals';
        if (limit != null) {
          url += '?limit=$limit';
        }
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Signal> signals = data.map((json) => Signal.fromJson({...json, 'market_type': 'thai_stock'})).toList();
        if (limit != null && signals.length > limit) {
          signals = signals.take(limit).toList();
        }
        return signals;
      } else {
        throw Exception('Failed to load Thai stock signals: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get chart data for a symbol (direct from Binance/Yahoo for GitHub Pages)
  Future<ChartData> getChartData(String symbol, String marketType) async {
    try {
      if (_isGitHubPages) {
        // For GitHub Pages, fetch chart data directly from source
        if (marketType == 'crypto') {
          return await _getCryptoChartDirect(symbol);
        } else {
          return await _getThaiChartDirect(symbol);
        }
      }
      
      // Original API call for non-GitHub Pages
      final encodedSymbol = Uri.encodeComponent(symbol);
      final endpoint = marketType == 'crypto' 
          ? '/api/crypto/chart/$encodedSymbol'
          : '/api/thai/chart/$encodedSymbol';
      
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return ChartData.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load chart data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // Direct Binance chart data
  Future<ChartData> _getCryptoChartDirect(String symbol) async {
    final pair = symbol.toUpperCase().replaceAll('/', '');
    final pairWithUsdt = pair.endsWith('USDT') ? pair : '${pair}USDT';
    final url = 'https://api.binance.com/api/v3/klines?symbol=$pairWithUsdt&interval=1h&limit=168';
    
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    
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
    throw Exception('Failed to load chart');
  }
  
  // Direct Yahoo Finance chart data
  Future<ChartData> _getThaiChartDirect(String symbol) async {
    final yahooSymbol = symbol.toUpperCase().endsWith('.BK') 
        ? symbol.toUpperCase() 
        : '${symbol.toUpperCase()}.BK';
    final rawUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=1h&range=7d';
    final url = _wrapCors(rawUrl);
    
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    
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
    throw Exception('Failed to load chart');
  }

  // Get signal detail for a symbol
  Future<Signal> getSignalDetail(String symbol, String marketType) async {
    try {
      if (_isGitHubPages) {
        // For GitHub Pages, find signal from the list
        final signals = marketType == 'crypto' 
            ? await getCryptoSignals() 
            : await getThaiStockSignals();
        final found = signals.where((s) => 
          s.symbol.toLowerCase() == symbol.toLowerCase() ||
          s.symbol.toLowerCase() == symbol.replaceAll('/USDT', '').toLowerCase()
        ).toList();
        if (found.isNotEmpty) return found.first;
        throw Exception('Symbol not found: $symbol');
      }
      
      final endpoint = marketType == 'crypto' 
          ? '/api/crypto/signal/$symbol'
          : '/api/thai/signal/$symbol';
      
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return Signal.fromJson({
          ...json.decode(response.body),
          'market_type': marketType,
        });
      } else {
        throw Exception('Failed to load signal detail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Search crypto from Binance (real data) with technical indicators
  Future<Signal> searchCryptoReal(String symbol) async {
    try {
      final pair = symbol.toUpperCase().endsWith('USDT') 
          ? symbol.toUpperCase() 
          : '${symbol.toUpperCase()}USDT';
      
      // Fetch both ticker and klines in parallel for real-time data
      final tickerFuture = http.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=$pair'),
      ).timeout(const Duration(seconds: 15));
      
      final klinesFuture = http.get(
        Uri.parse('https://api.binance.com/api/v3/klines?symbol=$pair&interval=1h&limit=100'),
      ).timeout(const Duration(seconds: 15));
      
      final responses = await Future.wait([tickerFuture, klinesFuture]);
      final tickerResponse = responses[0];
      final klinesResponse = responses[1];

      if (tickerResponse.statusCode == 200 && klinesResponse.statusCode == 200) {
        final tickerData = json.decode(tickerResponse.body);
        final List<dynamic> klines = json.decode(klinesResponse.body);
        
        // Extract close prices from klines for indicator calculation
        final closePrices = klines.map((k) => double.parse(k[4] as String)).toList();
        
        // Calculate technical indicators
        final rsi = _calculateRSI(closePrices, period: 14);
        final macdResult = _calculateMACD(closePrices);
        final macd = macdResult['macd'] ?? 0.0;
        final macdSignal = macdResult['signal'] ?? 0.0;
        final histogram = macdResult['histogram'] ?? 0.0;
        
        // Generate trading signal based on indicators
        final signalResult = _generateSignal(rsi, macd, macdSignal, histogram);
        
        return Signal.fromJson({
          'symbol': symbol.toUpperCase(),
          'price': double.parse(tickerData['lastPrice']),
          'change_percent': double.parse(tickerData['priceChangePercent']),
          'volume': double.parse(tickerData['volume']),
          'rsi': rsi,
          'macd': macd,
          'macd_signal': macdSignal,
          'signal': signalResult['signal'],
          'confidence': signalResult['confidence'],
          'market_type': 'crypto',
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        throw Exception('Symbol not found: $symbol');
      }
    } catch (e) {
      throw Exception('Search error: $e');
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
    
    // Calculate initial average gain and loss
    double avgGain = 0;
    double avgLoss = 0;
    for (int i = 0; i < period; i++) {
      avgGain += gains[i];
      avgLoss += losses[i];
    }
    avgGain /= period;
    avgLoss /= period;
    
    // Smooth the averages
    for (int i = period; i < gains.length; i++) {
      avgGain = (avgGain * (period - 1) + gains[i]) / period;
      avgLoss = (avgLoss * (period - 1) + losses[i]) / period;
    }
    
    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
  
  // Calculate MACD (Moving Average Convergence Divergence)
  Map<String, double> _calculateMACD(List<double> prices, {int fast = 12, int slow = 26, int signal = 9}) {
    if (prices.length < slow + signal) {
      return {'macd': 0.0, 'signal': 0.0, 'histogram': 0.0};
    }
    
    // Calculate EMAs
    final emaFast = _calculateEMA(prices, fast);
    final emaSlow = _calculateEMA(prices, slow);
    
    // Calculate MACD line
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
    
    // Calculate Signal line (EMA of MACD)
    final signalLine = _calculateEMA(macdLine, signal);
    
    final currentMacd = macdLine.last;
    final currentSignal = signalLine.isNotEmpty ? signalLine.last : 0.0;
    final histogram = currentMacd - currentSignal;
    
    return {
      'macd': currentMacd,
      'signal': currentSignal,
      'histogram': histogram,
    };
  }
  
  // Calculate Exponential Moving Average
  List<double> _calculateEMA(List<double> prices, int period) {
    if (prices.isEmpty || prices.length < period) return [];
    
    final multiplier = 2.0 / (period + 1);
    List<double> ema = [];
    
    // First EMA is SMA
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += prices[i];
    }
    ema.add(sum / period);
    
    // Calculate rest of EMA
    for (int i = period; i < prices.length; i++) {
      final newEma = (prices[i] - ema.last) * multiplier + ema.last;
      ema.add(newEma);
    }
    
    return ema;
  }
  
  // Generate trading signal based on indicators
  Map<String, dynamic> _generateSignal(double rsi, double macd, double macdSignal, double histogram) {
    int buyScore = 0;
    int sellScore = 0;
    
    // RSI Analysis
    if (rsi < 30) {
      buyScore += 2; // Oversold - strong buy signal
    } else if (rsi < 40) {
      buyScore += 1;
    } else if (rsi > 70) {
      sellScore += 2; // Overbought - strong sell signal
    } else if (rsi > 60) {
      sellScore += 1;
    }
    
    // MACD Analysis
    if (macd > macdSignal && histogram > 0) {
      buyScore += 2; // Bullish crossover
    } else if (macd > macdSignal) {
      buyScore += 1;
    } else if (macd < macdSignal && histogram < 0) {
      sellScore += 2; // Bearish crossover
    } else if (macd < macdSignal) {
      sellScore += 1;
    }
    
    // Histogram momentum
    if (histogram > 0) {
      buyScore += 1;
    } else if (histogram < 0) {
      sellScore += 1;
    }
    
    // Determine signal
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

  // Search Thai stock from Yahoo Finance (real data) with technical indicators
  Future<Signal> searchThaiReal(String symbol) async {
    try {
      final yahooSymbol = symbol.toUpperCase().endsWith('.BK') 
          ? symbol.toUpperCase() 
          : '${symbol.toUpperCase()}.BK';
      
      // Fetch chart data with enough history for indicator calculation
      final rawUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=1h&range=1mo';
      final response = await http.get(
        Uri.parse(_wrapCors(rawUrl)),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']['result']?[0];
        if (result == null) throw Exception('Symbol not found');
        
        final meta = result['meta'];
        final price = (meta['regularMarketPrice'] ?? 0).toDouble();
        final prevClose = (meta['previousClose'] ?? price).toDouble();
        final change = prevClose > 0 ? ((price - prevClose) / prevClose * 100) : 0.0;
        
        // Extract close prices for indicator calculation
        final quotes = result['indicators']['quote']?[0] ?? {};
        final closesList = (quotes['close'] as List?) ?? [];
        final volumes = (quotes['volume'] as List?) ?? [];
        
        // Filter out null values and convert to doubles
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
        double macd = 0.0;
        double macdSignal = 0.0;
        double histogram = 0.0;
        String signalType = 'HOLD';
        double confidence = 0.5;
        
        if (closePrices.length >= 30) {
          rsi = _calculateRSI(closePrices, period: 14);
          final macdResult = _calculateMACD(closePrices);
          macd = macdResult['macd'] ?? 0.0;
          macdSignal = macdResult['signal'] ?? 0.0;
          histogram = macdResult['histogram'] ?? 0.0;
          
          final signalResult = _generateSignal(rsi, macd, macdSignal, histogram);
          signalType = signalResult['signal'];
          confidence = signalResult['confidence'];
        }
        
        return Signal.fromJson({
          'symbol': symbol.toUpperCase().replaceAll('.BK', ''),
          'price': price,
          'change_percent': change,
          'volume': totalVolume,
          'rsi': rsi,
          'macd': macd,
          'macd_signal': macdSignal,
          'signal': signalType,
          'confidence': confidence,
          'market_type': 'thai_stock',
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        throw Exception('Symbol not found: $symbol');
      }
    } catch (e) {
      throw Exception('Search error: $e');
    }
  }

  // Health check
  Future<bool> checkConnection() async {
    try {
      final url = _isGitHubPages ? '$_baseUrl/health.json' : '$_baseUrl/health';
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // Fear & Greed Index (Free API)
  // ============================================
  
  /// Get Fear & Greed Index from Alternative.me
  /// Free API, no key required
  Future<FearGreedIndex?> getFearGreedIndex() async {
    try {
      final rawUrl = 'https://api.alternative.me/fng/';
      final response = await http.get(
        Uri.parse(_wrapCors(rawUrl)),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FearGreedIndex.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Fear & Greed API error: $e');
      return null;
    }
  }
}
