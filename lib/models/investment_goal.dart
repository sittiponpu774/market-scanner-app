/// Investment Goal Model for Goal-Based Tracking System
/// 
/// Features:
/// - Goal-based calculation (Entry Price for target profit)
/// - Limit Entry Alert with probability
/// - 5x Potential Filter scoring
library;

class InvestmentGoal {
  final String id;
  final String symbol;
  final String marketType; // crypto, thai_stock
  final double initialCapital; // เงินต้น (THB)
  final double targetProfit; // เป้าหมายกำไร (THB)
  final int timeframeYears; // กรอบเวลา (3-5 ปี)
  final double? targetEntryPrice; // ราคาเบ็ดที่ตั้งไว้
  final DateTime createdAt;
  final DateTime? updatedAt;

  InvestmentGoal({
    required this.id,
    required this.symbol,
    required this.marketType,
    required this.initialCapital,
    required this.targetProfit,
    required this.timeframeYears,
    this.targetEntryPrice,
    required this.createdAt,
    this.updatedAt,
  });

  /// Total target amount (เงินต้น + กำไรเป้าหมาย)
  double get totalTarget => initialCapital + targetProfit;

  /// Required return multiplier (เช่น 5x = 500%)
  double get requiredMultiplier => totalTarget / initialCapital;

  /// Required return percentage
  double get requiredReturnPercent => (requiredMultiplier - 1) * 100;

  factory InvestmentGoal.fromJson(Map<String, dynamic> json) {
    return InvestmentGoal(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      marketType: json['market_type'] ?? json['marketType'] ?? 'crypto',
      initialCapital: (json['initial_capital'] ?? json['initialCapital'] ?? 0).toDouble(),
      targetProfit: (json['target_profit'] ?? json['targetProfit'] ?? 0).toDouble(),
      timeframeYears: json['timeframe_years'] ?? json['timeframeYears'] ?? 3,
      targetEntryPrice: json['target_entry_price'] != null 
          ? (json['target_entry_price']).toDouble() 
          : json['targetEntryPrice']?.toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'market_type': marketType,
      'initial_capital': initialCapital,
      'target_profit': targetProfit,
      'timeframe_years': timeframeYears,
      'target_entry_price': targetEntryPrice,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  InvestmentGoal copyWith({
    String? id,
    String? symbol,
    String? marketType,
    double? initialCapital,
    double? targetProfit,
    int? timeframeYears,
    double? targetEntryPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvestmentGoal(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      marketType: marketType ?? this.marketType,
      initialCapital: initialCapital ?? this.initialCapital,
      targetProfit: targetProfit ?? this.targetProfit,
      timeframeYears: timeframeYears ?? this.timeframeYears,
      targetEntryPrice: targetEntryPrice ?? this.targetEntryPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Entry Alert for Limit Entry Monitoring
class EntryAlert {
  final String symbol;
  final double currentPrice;
  final double targetEntryPrice;
  final double reachProbability; // 0-1 ความน่าจะเป็นที่จะถึงราคาเบ็ดใน 7-14 วัน
  final double volatility; // ความผันผวน
  final double sellingPressure; // แรงขาย (-1 to 1)
  final String recommendation; // WAIT, BUY_NOW, ALMOST_THERE
  final DateTime timestamp;

  EntryAlert({
    required this.symbol,
    required this.currentPrice,
    required this.targetEntryPrice,
    required this.reachProbability,
    required this.volatility,
    required this.sellingPressure,
    required this.recommendation,
    required this.timestamp,
  });

  /// Distance from target (percentage)
  double get distancePercent => 
      ((currentPrice - targetEntryPrice) / targetEntryPrice) * 100;

  /// Is price at or below target?
  bool get isAtTarget => currentPrice <= targetEntryPrice;

  /// Color for UI based on recommendation
  String get recommendationColor {
    switch (recommendation) {
      case 'BUY_NOW':
        return 'green';
      case 'ALMOST_THERE':
        return 'orange';
      default:
        return 'grey';
    }
  }

  factory EntryAlert.fromJson(Map<String, dynamic> json) {
    return EntryAlert(
      symbol: json['symbol'] ?? '',
      currentPrice: (json['current_price'] ?? json['currentPrice'] ?? 0).toDouble(),
      targetEntryPrice: (json['target_entry_price'] ?? json['targetEntryPrice'] ?? 0).toDouble(),
      reachProbability: (json['reach_probability'] ?? json['reachProbability'] ?? 0).toDouble(),
      volatility: (json['volatility'] ?? 0).toDouble(),
      sellingPressure: (json['selling_pressure'] ?? json['sellingPressure'] ?? 0).toDouble(),
      recommendation: json['recommendation'] ?? 'WAIT',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'current_price': currentPrice,
      'target_entry_price': targetEntryPrice,
      'reach_probability': reachProbability,
      'volatility': volatility,
      'selling_pressure': sellingPressure,
      'recommendation': recommendation,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Investment Roadmap Calculation Result
class InvestmentRoadmap {
  final String symbol;
  final double currentPrice;
  final double targetEntryPrice;
  final double predictedPrice; // ราคาทำนาย 3-5 ปี
  final double initialCapital;
  
  // If buy today
  final double profitIfBuyToday;
  final double percentIfBuyToday;
  final bool reachesGoalIfBuyToday;
  
  // If buy at target entry
  final double profitIfBuyAtTarget;
  final double percentIfBuyAtTarget;
  final bool reachesGoalIfBuyAtTarget;
  
  final double targetProfit;

  InvestmentRoadmap({
    required this.symbol,
    required this.currentPrice,
    required this.targetEntryPrice,
    required this.predictedPrice,
    required this.initialCapital,
    required this.profitIfBuyToday,
    required this.percentIfBuyToday,
    required this.reachesGoalIfBuyToday,
    required this.profitIfBuyAtTarget,
    required this.percentIfBuyAtTarget,
    required this.reachesGoalIfBuyAtTarget,
    required this.targetProfit,
  });

  /// Difference in profit between two scenarios
  double get profitDifference => profitIfBuyAtTarget - profitIfBuyToday;

  /// Percentage difference
  double get percentDifference => percentIfBuyAtTarget - percentIfBuyToday;

  factory InvestmentRoadmap.fromJson(Map<String, dynamic> json) {
    return InvestmentRoadmap(
      symbol: json['symbol'] ?? '',
      currentPrice: (json['current_price'] ?? 0).toDouble(),
      targetEntryPrice: (json['target_entry_price'] ?? 0).toDouble(),
      predictedPrice: (json['predicted_price'] ?? 0).toDouble(),
      initialCapital: (json['initial_capital'] ?? 0).toDouble(),
      profitIfBuyToday: (json['profit_if_buy_today'] ?? 0).toDouble(),
      percentIfBuyToday: (json['percent_if_buy_today'] ?? 0).toDouble(),
      reachesGoalIfBuyToday: json['reaches_goal_if_buy_today'] ?? false,
      profitIfBuyAtTarget: (json['profit_if_buy_at_target'] ?? 0).toDouble(),
      percentIfBuyAtTarget: (json['percent_if_buy_at_target'] ?? 0).toDouble(),
      reachesGoalIfBuyAtTarget: json['reaches_goal_if_buy_at_target'] ?? false,
      targetProfit: (json['target_profit'] ?? 0).toDouble(),
    );
  }
}

/// 5x Potential Filter Score
class PotentialScore {
  final String symbol;
  final String name;
  final String category; // AI, DeFi, Gaming, Layer1, etc.
  final double currentPrice;
  final double marketCap;
  final double potentialScore; // 0-100 คะแนนศักยภาพ 5x
  final double growthRate; // อัตราเติบโตโปรเจกต์
  final double fiveYearPrediction; // ราคาทำนาย 5 ปี
  final double potentialMultiplier; // 5x, 10x, etc.
  final String tier; // S, A, B, C
  final String reason;

  PotentialScore({
    required this.symbol,
    required this.name,
    required this.category,
    required this.currentPrice,
    required this.marketCap,
    required this.potentialScore,
    required this.growthRate,
    required this.fiveYearPrediction,
    required this.potentialMultiplier,
    required this.tier,
    required this.reason,
  });

  /// Is this a 5x potential coin?
  bool get has5xPotential => potentialMultiplier >= 5.0;

  /// Tier color for UI
  String get tierColor {
    switch (tier) {
      case 'S':
        return 'purple';
      case 'A':
        return 'green';
      case 'B':
        return 'blue';
      default:
        return 'grey';
    }
  }

  factory PotentialScore.fromJson(Map<String, dynamic> json) {
    return PotentialScore(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'Unknown',
      currentPrice: (json['current_price'] ?? 0).toDouble(),
      marketCap: (json['market_cap'] ?? 0).toDouble(),
      potentialScore: (json['potential_score'] ?? 0).toDouble(),
      growthRate: (json['growth_rate'] ?? 0).toDouble(),
      fiveYearPrediction: (json['five_year_prediction'] ?? 0).toDouble(),
      potentialMultiplier: (json['potential_multiplier'] ?? 1).toDouble(),
      tier: json['tier'] ?? 'C',
      reason: json['reason'] ?? '',
    );
  }
}

/// Patience Meter State
class PatienceMeter {
  final String symbol;
  final String action; // WAIT, BUY
  final double patienceScore; // 0-100 (100 = ควรรอ)
  final String reason;
  final List<String> factors; // ปัจจัยที่ใช้วิเคราะห์
  final double fomoRisk; // 0-1 ความเสี่ยง FOMO
  final DateTime optimalEntryTime; // เวลาที่ควรเข้าซื้อ (ประมาณการ)

  PatienceMeter({
    required this.symbol,
    required this.action,
    required this.patienceScore,
    required this.reason,
    required this.factors,
    required this.fomoRisk,
    required this.optimalEntryTime,
  });

  /// Should wait?
  bool get shouldWait => action == 'WAIT';

  /// Action color
  String get actionColor => action == 'BUY' ? 'green' : 'orange';

  factory PatienceMeter.fromJson(Map<String, dynamic> json) {
    return PatienceMeter(
      symbol: json['symbol'] ?? '',
      action: json['action'] ?? 'WAIT',
      patienceScore: (json['patience_score'] ?? 50).toDouble(),
      reason: json['reason'] ?? '',
      factors: List<String>.from(json['factors'] ?? []),
      fomoRisk: (json['fomo_risk'] ?? 0).toDouble(),
      optimalEntryTime: json['optimal_entry_time'] != null 
          ? DateTime.parse(json['optimal_entry_time']) 
          : DateTime.now().add(const Duration(days: 7)),
    );
  }
}
