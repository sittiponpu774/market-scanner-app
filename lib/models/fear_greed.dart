/// Fear & Greed Index model
/// Data from https://api.alternative.me/fng/
class FearGreedIndex {
  final int value;
  final String classification;
  final DateTime timestamp;
  final DateTime? nextUpdate;

  FearGreedIndex({
    required this.value,
    required this.classification,
    required this.timestamp,
    this.nextUpdate,
  });

  factory FearGreedIndex.fromJson(Map<String, dynamic> json) {
    final data = json['data']?[0] ?? json;
    return FearGreedIndex(
      value: int.tryParse(data['value']?.toString() ?? '50') ?? 50,
      classification: data['value_classification'] ?? 'Neutral',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (int.tryParse(data['timestamp']?.toString() ?? '0') ?? 0) * 1000,
      ),
      nextUpdate: data['time_until_update'] != null
          ? DateTime.now().add(Duration(
              seconds: int.tryParse(data['time_until_update'].toString()) ?? 0,
            ))
          : null,
    );
  }

  /// Get color based on value
  /// 0-25: Extreme Fear (Green - buy opportunity)
  /// 26-45: Fear (Light Green)
  /// 46-55: Neutral (Gray)
  /// 56-75: Greed (Orange)
  /// 76-100: Extreme Greed (Red - sell signal)
  String get colorHex {
    if (value <= 25) return '#00C853'; // Extreme Fear - Green
    if (value <= 45) return '#69F0AE'; // Fear - Light Green
    if (value <= 55) return '#9E9E9E'; // Neutral - Gray
    if (value <= 75) return '#FF9800'; // Greed - Orange
    return '#F44336'; // Extreme Greed - Red
  }

  /// Get emoji based on classification
  String get emoji {
    if (value <= 25) return '😱';
    if (value <= 45) return '😨';
    if (value <= 55) return '😐';
    if (value <= 75) return '😏';
    return '🤑';
  }

  /// Get trading suggestion
  String get suggestion {
    if (value <= 25) return 'Potential buying opportunity';
    if (value <= 45) return 'Market is fearful - watch for entries';
    if (value <= 55) return 'Neutral market sentiment';
    if (value <= 75) return 'Market getting greedy - be cautious';
    return 'Extreme greed - consider taking profits';
  }

  /// Check if value indicates potential buy zone
  bool get isBuyZone => value <= 35;

  /// Check if value indicates potential sell zone
  bool get isSellZone => value >= 75;
}
