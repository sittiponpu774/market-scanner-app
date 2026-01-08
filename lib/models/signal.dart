class Signal {
  final String symbol;
  final double price;
  final double changePercent;
  final String signalType; // BUY, SELL, HOLD
  final double confidence;
  final double rsi;
  final double macd;
  final double macdSignal;
  final double volume;
  final String marketType; // crypto, thai_stock
  final DateTime timestamp;
  final Map<String, dynamic>? additionalData;

  Signal({
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.signalType,
    required this.confidence,
    required this.rsi,
    required this.macd,
    required this.macdSignal,
    required this.volume,
    required this.marketType,
    required this.timestamp,
    this.additionalData,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    // Handle MACD - can be object or number
    double macdValue = 0;
    double macdSignalValue = 0;
    if (json['macd'] != null) {
      if (json['macd'] is Map) {
        macdValue = (json['macd']['macd'] ?? 0).toDouble();
        macdSignalValue = (json['macd']['signal'] ?? 0).toDouble();
      } else {
        macdValue = (json['macd'] ?? 0).toDouble();
        macdSignalValue = (json['macd_signal'] ?? json['macdSignal'] ?? 0).toDouble();
      }
    }
    
    return Signal(
      symbol: json['symbol'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      changePercent: (json['change_24h'] ?? json['change_percent'] ?? json['changePercent'] ?? 0).toDouble(),
      signalType: json['signal'] ?? json['signalType'] ?? 'HOLD',
      confidence: (json['strength'] ?? json['confidence'] ?? json['up_probability'] ?? 0.5).toDouble(),
      rsi: (json['rsi'] ?? 50).toDouble(),
      macd: macdValue,
      macdSignal: macdSignalValue,
      volume: (json['volume_24h'] ?? json['volume'] ?? 0).toDouble(),
      marketType: json['market_type'] ?? json['marketType'] ?? 'crypto',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      additionalData: json['additional_data'] ?? json['additionalData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'price': price,
      'change_percent': changePercent,
      'signal': signalType,
      'confidence': confidence,
      'rsi': rsi,
      'macd': macd,
      'macd_signal': macdSignal,
      'volume': volume,
      'market_type': marketType,
      'timestamp': timestamp.toIso8601String(),
      'additional_data': additionalData,
    };
  }

  // Get signal color
  String get signalColor {
    switch (signalType.toUpperCase()) {
      case 'BUY':
        return 'green';
      case 'SELL':
        return 'red';
      default:
        return 'orange';
    }
  }

  // Check if bullish
  bool get isBullish => signalType.toUpperCase() == 'BUY';
  
  // Check if bearish
  bool get isBearish => signalType.toUpperCase() == 'SELL';
}
