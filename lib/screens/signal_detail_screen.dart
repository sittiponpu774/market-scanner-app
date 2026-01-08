import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/binance_websocket_service.dart';
import 'investment_roadmap_screen.dart';

class SignalDetailScreen extends StatefulWidget {
  const SignalDetailScreen({super.key});

  @override
  State<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends State<SignalDetailScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final signal = ModalRoute.of(context)?.settings.arguments as Signal?;
    if (signal != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SignalProvider>().selectSignal(signal);
      });
    }
  }

  Color _getSignalColor(String signalType) {
    switch (signalType.toUpperCase()) {
      case 'BUY':
        return Colors.green;
      case 'SELL':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final signal = ModalRoute.of(context)?.settings.arguments as Signal?;

    if (signal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Signal Detail')),
        body: const Center(child: Text('No signal data')),
      );
    }

    final signalColor = _getSignalColor(signal.signalType);

    return Scaffold(
      appBar: AppBar(
        title: Text(signal.symbol),
        centerTitle: true,
        actions: [
          // Favourite button in AppBar
          Consumer<FavouriteProvider>(
            builder: (context, favouriteProvider, child) {
              final isFav = favouriteProvider.isFavourite(signal.symbol);
              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null,
                ),
                onPressed: () {
                  favouriteProvider.toggleFavourite(
                    signal.symbol,
                    marketType: signal.marketType,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFav 
                            ? '${signal.symbol} removed from favourites'
                            : '${signal.symbol} added to favourites',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<SignalProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card with realtime price (only this rebuilds on price change)
                _RealtimePriceHeader(
                  signal: signal,
                  signalColor: signalColor,
                ),

                // Price Chart (does NOT rebuild on price change)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Price Chart',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (provider.chartData != null)
                        PriceChart(
                          chartData: provider.chartData!,
                          color: signalColor,
                          marketType: signal.marketType,
                        )
                      else
                        const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Technical Indicators
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technical Indicators',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildIndicatorRow(
                          context,
                          'RSI (14)',
                          signal.rsi.toStringAsFixed(2),
                          _getRsiInterpretation(signal.rsi),
                          _getRsiColor(signal.rsi),
                        ),
                        const Divider(),
                        _buildIndicatorRow(
                          context,
                          'MACD',
                          signal.macd.toStringAsFixed(4),
                          signal.macd > signal.macdSignal ? 'Bullish' : 'Bearish',
                          signal.macd > signal.macdSignal ? Colors.green : Colors.red,
                        ),
                        const Divider(),
                        _buildIndicatorRow(
                          context,
                          'MACD Signal',
                          signal.macdSignal.toStringAsFixed(4),
                          '',
                          Colors.grey,
                        ),
                        if (provider.chartData != null) ...[
                          const SizedBox(height: 16),
                          IndicatorChart(
                            data: provider.chartData!.rsiData,
                            title: 'RSI History',
                            color: Colors.purple,
                            upperThreshold: 70,
                            lowerThreshold: 30,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ML Prediction
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ML Prediction',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: signal.confidence,
                          backgroundColor: Colors.grey.withAlpha(51),
                          valueColor: AlwaysStoppedAnimation(signalColor),
                          minHeight: 20,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('0%'),
                            Text(
                              '${(signal.confidence * 100).toStringAsFixed(1)}% confidence',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: signalColor,
                              ),
                            ),
                            const Text('100%'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Investment Strategy Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvestmentRoadmapScreen(signal: signal),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.map_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Investment Roadmap',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'วางแผนเป้าหมาย, คำนวณจุดเข้า & 5x Potential',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value, Color? color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorRow(BuildContext context, String name, String value, String interpretation, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              interpretation,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price, {String marketType = 'crypto'}) {
    final symbol = marketType == 'thai_stock' ? '฿' : '\$';
    if (price >= 1000) {
      return '$symbol${price.toStringAsFixed(2)}';
    } else if (price >= 1) {
      return '$symbol${price.toStringAsFixed(marketType == 'thai_stock' ? 2 : 3)}';
    } else {
      return '$symbol${price.toStringAsFixed(6)}';
    }
  }

  String _getRsiInterpretation(double rsi) {
    if (rsi < 30) return 'Oversold';
    if (rsi > 70) return 'Overbought';
    return 'Neutral';
  }

  Color _getRsiColor(double rsi) {
    if (rsi < 30) return Colors.green;
    if (rsi > 70) return Colors.red;
    return Colors.grey;
  }
}

// Separate widget for realtime price to avoid rebuilding the entire screen
class _RealtimePriceHeader extends StatelessWidget {
  final Signal signal;
  final Color signalColor;

  const _RealtimePriceHeader({
    required this.signal,
    required this.signalColor,
  });

  @override
  Widget build(BuildContext context) {
    // Only this widget rebuilds when price changes
    final realTimeUpdate = signal.marketType == 'crypto'
        ? context.select<BinanceProvider, BinancePriceUpdate?>(
            (provider) => provider.getPrice(signal.symbol))
        : null;

    final displayPrice = realTimeUpdate?.price ?? signal.price;
    final displayChange = realTimeUpdate?.priceChangePercent ?? signal.changePercent;
    final changeColor = displayChange >= 0 ? Colors.green : Colors.red;
    final isRealTime = realTimeUpdate != null;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.symbol,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: signal.marketType == 'crypto'
                            ? Colors.blue.withAlpha(51)
                            : Colors.purple.withAlpha(51),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        signal.marketType == 'crypto' ? 'CRYPTO' : 'SET',
                        style: TextStyle(
                          fontSize: 12,
                          color: signal.marketType == 'crypto'
                              ? Colors.blue
                              : Colors.purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: signalColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    signal.signalType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoColumn(
                  context,
                  'Price',
                  _formatPrice(displayPrice, marketType: signal.marketType),
                  null,
                  isRealTime: isRealTime,
                ),
                _buildInfoColumn(
                  context,
                  'Change',
                  '${displayChange >= 0 ? '+' : ''}${displayChange.toStringAsFixed(2)}%',
                  changeColor,
                ),
                _buildInfoColumn(
                  context,
                  'Confidence',
                  '${(signal.confidence * 100).toStringAsFixed(1)}%',
                  signalColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value, Color? color, {bool isRealTime = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            if (isRealTime) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price, {String marketType = 'crypto'}) {
    final symbol = marketType == 'thai_stock' ? '฿' : '\$';
    if (price >= 1000) {
      return '$symbol${price.toStringAsFixed(2)}';
    } else if (price >= 1) {
      return '$symbol${price.toStringAsFixed(marketType == 'thai_stock' ? 2 : 3)}';
    } else {
      return '$symbol${price.toStringAsFixed(6)}';
    }
  }
}
