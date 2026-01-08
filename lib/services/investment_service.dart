import 'dart:math';
import '../models/investment_goal.dart';
import '../models/signal.dart';
import 'api_service_github.dart';

/// Investment Strategy Service
/// 
/// Provides:
/// - Goal-based tracking calculations
/// - Limit Entry Alert monitoring
/// - 5x Potential Filter scoring
/// - Patience Meter analysis
class InvestmentService {
  final ApiService _apiService = ApiService();
  
  // Cache for real-time prices
  final Map<String, double> _priceCache = {};
  DateTime? _lastPriceUpdate;
  static const Duration _priceCacheDuration = Duration(seconds: 30);
  
  // ===========================================
  // GOAL-BASED TRACKING
  // ===========================================
  
  /// Calculate required entry price to reach profit target
  /// 
  /// [predictedPrice] - ราคาทำนายในอนาคต (3-5 ปี)
  /// [initialCapital] - เงินต้น (THB)
  /// [targetProfit] - เป้าหมายกำไร (THB)
  /// 
  /// Returns: Entry price ที่ต้องซื้อเพื่อบรรลุเป้าหมาย
  double calculateRequiredEntryPrice({
    required double predictedPrice,
    required double initialCapital,
    required double targetProfit,
  }) {
    final totalTarget = initialCapital + targetProfit;
    final requiredMultiplier = totalTarget / initialCapital;
    
    // Entry Price = Predicted Price / Required Multiplier
    return predictedPrice / requiredMultiplier;
  }
  
  /// Calculate profit potential from entry price to predicted price
  double calculateProfitPotential({
    required double entryPrice,
    required double predictedPrice,
    required double capitalInvested,
  }) {
    if (entryPrice <= 0) return 0;
    final shares = capitalInvested / entryPrice;
    final futureValue = shares * predictedPrice;
    return futureValue - capitalInvested;
  }
  
  /// Calculate percentage return
  double calculatePercentReturn({
    required double entryPrice,
    required double exitPrice,
  }) {
    if (entryPrice <= 0) return 0;
    return ((exitPrice - entryPrice) / entryPrice) * 100;
  }
  
  /// Generate Investment Roadmap comparing buy today vs buy at target
  Future<InvestmentRoadmap> generateRoadmap({
    required InvestmentGoal goal,
    required double currentPrice,
    required double predictedPrice,
  }) async {
    final targetEntry = goal.targetEntryPrice ?? 
        calculateRequiredEntryPrice(
          predictedPrice: predictedPrice,
          initialCapital: goal.initialCapital,
          targetProfit: goal.targetProfit,
        );
    
    // Scenario 1: Buy today
    final profitToday = calculateProfitPotential(
      entryPrice: currentPrice,
      predictedPrice: predictedPrice,
      capitalInvested: goal.initialCapital,
    );
    final percentToday = calculatePercentReturn(
      entryPrice: currentPrice,
      exitPrice: predictedPrice,
    );
    
    // Scenario 2: Buy at target entry
    final profitAtTarget = calculateProfitPotential(
      entryPrice: targetEntry,
      predictedPrice: predictedPrice,
      capitalInvested: goal.initialCapital,
    );
    final percentAtTarget = calculatePercentReturn(
      entryPrice: targetEntry,
      exitPrice: predictedPrice,
    );
    
    return InvestmentRoadmap(
      symbol: goal.symbol,
      currentPrice: currentPrice,
      targetEntryPrice: targetEntry,
      predictedPrice: predictedPrice,
      initialCapital: goal.initialCapital,
      profitIfBuyToday: profitToday,
      percentIfBuyToday: percentToday,
      reachesGoalIfBuyToday: profitToday >= goal.targetProfit,
      profitIfBuyAtTarget: profitAtTarget,
      percentIfBuyAtTarget: percentAtTarget,
      reachesGoalIfBuyAtTarget: profitAtTarget >= goal.targetProfit,
      targetProfit: goal.targetProfit,
    );
  }
  
  // ===========================================
  // LIMIT ENTRY ALERT (เบ็ด)
  // ===========================================
  
  /// Calculate probability of price reaching target within timeframe
  /// Uses volatility analysis and selling pressure
  Future<EntryAlert> analyzeEntryProbability({
    required String symbol,
    required double currentPrice,
    required double targetEntryPrice,
    List<double>? historicalPrices,
  }) async {
    // Calculate volatility from historical prices
    double volatility = 0.05; // Default 5%
    double sellingPressure = 0;
    
    if (historicalPrices != null && historicalPrices.length >= 14) {
      volatility = _calculateVolatility(historicalPrices);
      sellingPressure = _calculateSellingPressure(historicalPrices);
    }
    
    // Calculate probability using normal distribution approximation
    final priceDistance = (currentPrice - targetEntryPrice) / currentPrice;
    final daysToAnalyze = 14.0;
    final dailyVolatility = volatility / sqrt(252); // Annualized to daily
    final expectedMove = dailyVolatility * sqrt(daysToAnalyze);
    
    // Probability calculation using Z-score
    double probability = 0;
    if (priceDistance > 0) {
      // Target is below current price (waiting for dip)
      final zScore = priceDistance / expectedMove;
      probability = _normalCDF(-zScore); // Probability of going down
      
      // Adjust for selling pressure
      if (sellingPressure > 0) {
        probability *= (1 + sellingPressure * 0.3); // Increase if selling pressure
      }
    } else {
      // Already at or below target
      probability = 1.0;
    }
    
    probability = probability.clamp(0.0, 0.95);
    
    // Determine recommendation
    String recommendation;
    if (currentPrice <= targetEntryPrice) {
      recommendation = 'BUY_NOW';
    } else if (probability >= 0.6 && priceDistance <= 0.1) {
      recommendation = 'ALMOST_THERE';
    } else {
      recommendation = 'WAIT';
    }
    
    return EntryAlert(
      symbol: symbol,
      currentPrice: currentPrice,
      targetEntryPrice: targetEntryPrice,
      reachProbability: probability,
      volatility: volatility,
      sellingPressure: sellingPressure,
      recommendation: recommendation,
      timestamp: DateTime.now(),
    );
  }
  
  /// Calculate historical volatility (standard deviation of returns)
  double _calculateVolatility(List<double> prices) {
    if (prices.length < 2) return 0.05;
    
    List<double> returns = [];
    for (int i = 1; i < prices.length; i++) {
      if (prices[i - 1] > 0) {
        returns.add((prices[i] - prices[i - 1]) / prices[i - 1]);
      }
    }
    
    if (returns.isEmpty) return 0.05;
    
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final squaredDiffs = returns.map((r) => pow(r - mean, 2)).toList();
    final variance = squaredDiffs.reduce((a, b) => a + b) / returns.length;
    
    return sqrt(variance) * sqrt(252); // Annualized volatility
  }
  
  /// Calculate selling pressure based on price momentum
  double _calculateSellingPressure(List<double> prices) {
    if (prices.length < 7) return 0;
    
    // Compare recent prices to older prices
    final recentAvg = prices.sublist(prices.length - 3).reduce((a, b) => a + b) / 3;
    final olderAvg = prices.sublist(prices.length - 7, prices.length - 3).reduce((a, b) => a + b) / 4;
    
    if (olderAvg == 0) return 0;
    
    final momentum = (recentAvg - olderAvg) / olderAvg;
    
    // Negative momentum = selling pressure, clamped to -1 to 1
    return (-momentum * 10).clamp(-1.0, 1.0);
  }
  
  /// Standard normal CDF approximation
  double _normalCDF(double z) {
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p = 0.3275911;
    
    final sign = z < 0 ? -1 : 1;
    z = z.abs() / sqrt(2);
    
    final t = 1.0 / (1.0 + p * z);
    final y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-z * z);
    
    return 0.5 * (1.0 + sign * y);
  }
  
  // ===========================================
  // PATIENCE METER
  // ===========================================
  
  /// Analyze whether to WAIT or BUY based on market conditions
  Future<PatienceMeter> analyzePatienceMeter({
    required Signal signal,
    required double targetEntryPrice,
  }) async {
    List<String> factors = [];
    double patienceScore = 50; // Start neutral
    
    // Factor 1: RSI Analysis
    if (signal.rsi > 70) {
      patienceScore += 25;
      factors.add('RSI Overbought (${signal.rsi.toStringAsFixed(1)}) - ควรรอ');
    } else if (signal.rsi < 30) {
      patienceScore -= 25;
      factors.add('RSI Oversold (${signal.rsi.toStringAsFixed(1)}) - น่าซื้อ');
    } else if (signal.rsi > 60) {
      patienceScore += 10;
      factors.add('RSI สูง (${signal.rsi.toStringAsFixed(1)})');
    } else if (signal.rsi < 40) {
      patienceScore -= 10;
      factors.add('RSI ต่ำ (${signal.rsi.toStringAsFixed(1)})');
    }
    
    // Factor 2: Price vs Target
    final priceDistance = (signal.price - targetEntryPrice) / targetEntryPrice * 100;
    if (priceDistance > 20) {
      patienceScore += 20;
      factors.add('ราคาสูงกว่าเป้า ${priceDistance.toStringAsFixed(1)}% - ควรรอ');
    } else if (priceDistance > 10) {
      patienceScore += 10;
      factors.add('ราคาสูงกว่าเป้า ${priceDistance.toStringAsFixed(1)}%');
    } else if (priceDistance <= 0) {
      patienceScore -= 30;
      factors.add('ราคาถึงเป้าแล้ว! 🎯');
    } else if (priceDistance <= 5) {
      patienceScore -= 15;
      factors.add('ราคาใกล้เป้า ${priceDistance.toStringAsFixed(1)}%');
    }
    
    // Factor 3: MACD Analysis
    if (signal.macd < signal.macdSignal) {
      patienceScore += 10;
      factors.add('MACD Bearish - อาจลงต่อ');
    } else {
      patienceScore -= 5;
      factors.add('MACD Bullish');
    }
    
    // Factor 4: 24h Change
    if (signal.changePercent > 10) {
      patienceScore += 15;
      factors.add('พุ่งขึ้น ${signal.changePercent.toStringAsFixed(1)}% - ระวัง FOMO');
    } else if (signal.changePercent < -10) {
      patienceScore -= 10;
      factors.add('ร่วง ${signal.changePercent.toStringAsFixed(1)}% - อาจเป็นโอกาส');
    }
    
    patienceScore = patienceScore.clamp(0, 100);
    
    // Calculate FOMO risk
    double fomoRisk = 0;
    if (signal.changePercent > 5) {
      fomoRisk = (signal.changePercent / 20).clamp(0, 1);
    }
    if (signal.rsi > 60) {
      fomoRisk += ((signal.rsi - 60) / 40).clamp(0, 0.5);
    }
    fomoRisk = fomoRisk.clamp(0, 1);
    
    // Determine action
    String action = patienceScore >= 50 ? 'WAIT' : 'BUY';
    
    // Calculate optimal entry time (estimate)
    int daysToWait = (patienceScore / 10).round();
    final optimalTime = DateTime.now().add(Duration(days: daysToWait));
    
    // Generate reason
    String reason;
    if (patienceScore >= 70) {
      reason = 'ตลาด Overbought - ความเสี่ยงสูงที่จะซื้อตอนนี้';
    } else if (patienceScore >= 50) {
      reason = 'ยังไม่ใช่จังหวะที่ดีที่สุด - รอโอกาสที่ดีกว่า';
    } else if (patienceScore >= 30) {
      reason = 'เริ่มน่าสนใจ - พิจารณาทยอยซื้อได้';
    } else {
      reason = 'จังหวะดี! - ราคาน่าดึงดูดเมื่อเทียบกับเป้าหมาย';
    }
    
    return PatienceMeter(
      symbol: signal.symbol,
      action: action,
      patienceScore: patienceScore,
      reason: reason,
      factors: factors,
      fomoRisk: fomoRisk,
      optimalEntryTime: optimalTime,
    );
  }
  
  // ===========================================
  // 5X POTENTIAL FILTER
  // ===========================================
  
  /// Coin categories for AI analysis
  static const Map<String, String> coinCategories = {
    // AI & Machine Learning
    'FET': 'AI', 'AGIX': 'AI', 'OCEAN': 'AI', 'RNDR': 'AI', 'TAO': 'AI',
    'AKT': 'AI', 'RLC': 'AI',
    
    // DeFi
    'AAVE': 'DeFi', 'UNI': 'DeFi', 'MKR': 'DeFi', 'SNX': 'DeFi', 
    'CRV': 'DeFi', 'COMP': 'DeFi', 'SUSHI': 'DeFi', 'YFI': 'DeFi',
    '1INCH': 'DeFi', 'BAL': 'DeFi', 'LDO': 'DeFi',
    
    // Layer 1
    'ETH': 'Layer1', 'SOL': 'Layer1', 'ADA': 'Layer1', 'AVAX': 'Layer1',
    'DOT': 'Layer1', 'ATOM': 'Layer1', 'NEAR': 'Layer1', 'APT': 'Layer1',
    'SUI': 'Layer1', 'SEI': 'Layer1', 'ICP': 'Layer1',
    
    // Layer 2
    'MATIC': 'Layer2', 'ARB': 'Layer2', 'OP': 'Layer2', 'IMX': 'Layer2',
    'STX': 'Layer2', 'LRC': 'Layer2', 'SKL': 'Layer2',
    
    // Gaming & Metaverse
    'AXS': 'Gaming', 'SAND': 'Gaming', 'MANA': 'Gaming', 'GALA': 'Gaming',
    'ENJ': 'Gaming', 'APE': 'Gaming', 'GMT': 'Gaming',
    
    // Meme (High Risk)
    'DOGE': 'Meme', 'SHIB': 'Meme', 'PEPE': 'Meme', 'FLOKI': 'Meme',
    'BONK': 'Meme', 'WIF': 'Meme',
    
    // Infrastructure
    'LINK': 'Oracle', 'GRT': 'Indexing', 'FIL': 'Storage', 'AR': 'Storage',
    'THETA': 'Streaming', 'HBAR': 'Enterprise',
  };
  
  /// Market cap tiers (approximate in billions USD)
  static const Map<String, double> estimatedMarketCaps = {
    'BTC': 1000, 'ETH': 300, 'BNB': 50, 'SOL': 40, 'XRP': 30,
    'ADA': 15, 'DOGE': 12, 'AVAX': 10, 'DOT': 8, 'LINK': 8,
    'MATIC': 7, 'SHIB': 5, 'UNI': 5, 'ATOM': 4, 'LTC': 6,
    'NEAR': 3, 'APT': 3, 'ARB': 2, 'OP': 2, 'FET': 1.5,
    'RNDR': 1.5, 'INJ': 1.5, 'SUI': 1.2, 'SEI': 0.8, 'TIA': 1,
    // Lower caps have more potential
    'AGIX': 0.5, 'OCEAN': 0.3, 'TAO': 0.4, 'AKT': 0.2, 'RLC': 0.15,
    'PEPE': 1, 'WIF': 0.8, 'BONK': 0.6, 'FLOKI': 0.5,
  };
  
  /// Score a coin for 5x potential
  Future<PotentialScore> calculate5xPotential({
    required Signal signal,
    double? growthRateOverride,
  }) async {
    final symbol = signal.symbol.toUpperCase().replaceAll('USDT', '');
    final category = coinCategories[symbol] ?? 'Unknown';
    final marketCap = estimatedMarketCaps[symbol] ?? 1.0;
    
    double score = 0;
    List<String> reasons = [];
    
    // Factor 1: Market Cap (smaller = more potential)
    if (marketCap < 0.5) {
      score += 30;
      reasons.add('Low cap (under \$500M) - ศักยภาพสูง');
    } else if (marketCap < 2) {
      score += 25;
      reasons.add('Mid-low cap (under \$2B) - โอกาสเติบโตดี');
    } else if (marketCap < 10) {
      score += 15;
      reasons.add('Mid cap - เติบโตได้แต่ไม่หวือหวา');
    } else {
      score += 5;
      reasons.add('Large cap - เสถียรแต่ upside จำกัด');
    }
    
    // Factor 2: Category (AI, DeFi, L2 trending)
    switch (category) {
      case 'AI':
        score += 25;
        reasons.add('AI Sector - กลุ่มร้อนแรง 2024-2026');
        break;
      case 'Layer2':
        score += 20;
        reasons.add('Layer 2 - Scaling solution demand');
        break;
      case 'DeFi':
        score += 18;
        reasons.add('DeFi - ยังมี growth potential');
        break;
      case 'Layer1':
        score += 12;
        reasons.add('Layer 1 - แข่งขันสูง');
        break;
      case 'Gaming':
        score += 15;
        reasons.add('Gaming/Metaverse - รอ adoption');
        break;
      case 'Meme':
        score += 8;
        reasons.add('Meme - High risk/reward');
        break;
      default:
        score += 10;
    }
    
    // Factor 3: RSI (oversold = opportunity)
    if (signal.rsi < 30) {
      score += 15;
      reasons.add('RSI Oversold - จุดเข้าที่ดี');
    } else if (signal.rsi < 40) {
      score += 10;
      reasons.add('RSI ต่ำ - ยังไม่ร้อน');
    } else if (signal.rsi > 70) {
      score -= 10;
      reasons.add('RSI Overbought - ควรรอ correction');
    }
    
    // Factor 4: Recent performance (contrarian)
    if (signal.changePercent < -15) {
      score += 12;
      reasons.add('ร่วงหนัก - อาจเป็นโอกาส DCA');
    } else if (signal.changePercent < -5) {
      score += 5;
    } else if (signal.changePercent > 20) {
      score -= 8;
      reasons.add('พุ่งแรง - ระวัง FOMO');
    }
    
    // Calculate growth rate based on category
    double growthRate = growthRateOverride ?? _estimateGrowthRate(category, marketCap);
    
    // Calculate 5-year prediction using compound growth
    final fiveYearPrice = signal.price * pow(1 + growthRate, 5);
    final potentialMultiplier = fiveYearPrice / signal.price;
    
    // Adjust score based on potential multiplier
    if (potentialMultiplier >= 10) {
      score += 15;
    } else if (potentialMultiplier >= 5) {
      score += 10;
    } else if (potentialMultiplier >= 3) {
      score += 5;
    }
    
    score = score.clamp(0, 100);
    
    // Determine tier
    String tier;
    if (score >= 80) {
      tier = 'S';
    } else if (score >= 60) {
      tier = 'A';
    } else if (score >= 40) {
      tier = 'B';
    } else {
      tier = 'C';
    }
    
    return PotentialScore(
      symbol: symbol,
      name: signal.additionalData?['name'] ?? symbol,
      category: category,
      currentPrice: signal.price,
      marketCap: marketCap * 1e9, // Convert to actual value
      potentialScore: score,
      growthRate: growthRate * 100, // As percentage
      fiveYearPrediction: fiveYearPrice,
      potentialMultiplier: potentialMultiplier,
      tier: tier,
      reason: reasons.join(', '),
    );
  }
  
  /// Estimate annual growth rate based on category and market cap
  double _estimateGrowthRate(String category, double marketCapBillions) {
    double baseRate = 0.15; // 15% default
    
    // Category adjustment
    switch (category) {
      case 'AI':
        baseRate = 0.50; // AI sector high growth
        break;
      case 'Layer2':
        baseRate = 0.40;
        break;
      case 'DeFi':
        baseRate = 0.30;
        break;
      case 'Gaming':
        baseRate = 0.35;
        break;
      case 'Layer1':
        baseRate = 0.25;
        break;
      case 'Meme':
        baseRate = 0.20; // High variance but lower expected value
        break;
    }
    
    // Market cap adjustment (smaller = higher potential growth)
    if (marketCapBillions < 0.5) {
      baseRate *= 1.5;
    } else if (marketCapBillions < 2) {
      baseRate *= 1.2;
    } else if (marketCapBillions > 50) {
      baseRate *= 0.6;
    }
    
    return baseRate;
  }
  
  /// Scan all coins and return top 5x potential candidates
  Future<List<PotentialScore>> scan5xPotentialCoins({
    required List<Signal> signals,
    int topN = 10,
  }) async {
    List<PotentialScore> scores = [];
    
    for (final signal in signals) {
      try {
        final score = await calculate5xPotential(signal: signal);
        if (score.has5xPotential) {
          scores.add(score);
        }
      } catch (e) {
        print('Error scoring ${signal.symbol}: $e');
      }
    }
    
    // Sort by potential score descending
    scores.sort((a, b) => b.potentialScore.compareTo(a.potentialScore));
    
    return scores.take(topN).toList();
  }
  
  // ===========================================
  // HELPER METHODS
  // ===========================================
  
  /// Get current price for a symbol
  Future<double?> getCurrentPrice(String symbol, String marketType) async {
    // Check cache
    if (_lastPriceUpdate != null &&
        DateTime.now().difference(_lastPriceUpdate!) < _priceCacheDuration &&
        _priceCache.containsKey(symbol)) {
      return _priceCache[symbol];
    }
    
    try {
      final signal = marketType == 'crypto'
          ? await _apiService.searchCrypto(symbol)
          : await _apiService.searchThai(symbol);
      
      if (signal != null) {
        _priceCache[symbol] = signal.price;
        _lastPriceUpdate = DateTime.now();
        return signal.price;
      }
    } catch (e) {
      print('Error fetching price for $symbol: $e');
    }
    
    return null;
  }
  
  /// Check if any entry alerts are triggered
  Future<List<EntryAlert>> checkEntryAlerts(List<InvestmentGoal> goals) async {
    List<EntryAlert> triggeredAlerts = [];
    
    for (final goal in goals) {
      if (goal.targetEntryPrice == null) continue;
      
      final currentPrice = await getCurrentPrice(goal.symbol, goal.marketType);
      if (currentPrice == null) continue;
      
      final alert = await analyzeEntryProbability(
        symbol: goal.symbol,
        currentPrice: currentPrice,
        targetEntryPrice: goal.targetEntryPrice!,
      );
      
      if (alert.recommendation != 'WAIT') {
        triggeredAlerts.add(alert);
      }
    }
    
    return triggeredAlerts;
  }
}
