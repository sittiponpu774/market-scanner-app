class PriceData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  PriceData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory PriceData.fromJson(Map<String, dynamic> json) {
    return PriceData(
      time: json['time'] != null 
          ? DateTime.parse(json['time']) 
          : DateTime.now(),
      open: (json['open'] ?? 0).toDouble(),
      high: (json['high'] ?? 0).toDouble(),
      low: (json['low'] ?? 0).toDouble(),
      close: (json['close'] ?? 0).toDouble(),
      volume: (json['volume'] ?? 0).toDouble(),
    );
  }
}

class ChartData {
  final List<PriceData> prices;
  final List<double> rsiData;
  final List<double> macdData;
  final List<double> macdSignalData;

  ChartData({
    required this.prices,
    required this.rsiData,
    required this.macdData,
    required this.macdSignalData,
  });

  factory ChartData.fromJson(Map<String, dynamic> json) {
    List<PriceData> prices = [];
    if (json['prices'] != null) {
      prices = (json['prices'] as List)
          .map((p) => PriceData.fromJson(p))
          .toList();
    }

    List<double> parseDoubleList(dynamic data) {
      if (data == null) return <double>[];
      return (data as List).map<double>((v) => (v ?? 0).toDouble()).toList();
    }

    return ChartData(
      prices: prices,
      rsiData: parseDoubleList(json['rsi']),
      macdData: parseDoubleList(json['macd']),
      macdSignalData: parseDoubleList(json['macd_signal']),
    );
  }
}
