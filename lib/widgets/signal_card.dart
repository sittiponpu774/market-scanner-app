import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/favourite_provider.dart';
import '../providers/binance_provider.dart';

class SignalCard extends StatelessWidget {
  final Signal signal;
  final VoidCallback onTap;

  const SignalCard({
    super.key,
    required this.signal,
    required this.onTap,
  });

  Color _getSignalColor() {
    switch (signal.signalType.toUpperCase()) {
      case 'BUY':
        return Colors.green;
      case 'SELL':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getSignalIcon() {
    switch (signal.signalType.toUpperCase()) {
      case 'BUY':
        return Icons.trending_up;
      case 'SELL':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalColor = _getSignalColor();
    
    // Get real-time price for crypto
    final binanceProvider = context.watch<BinanceProvider>();
    final realTimeUpdate = signal.marketType == 'crypto' 
        ? binanceProvider.getPrice(signal.symbol) 
        : null;
    
    final displayPrice = realTimeUpdate?.price ?? signal.price;
    final displayChange = realTimeUpdate?.priceChangePercent ?? signal.changePercent;
    final changeColor = displayChange >= 0 ? Colors.green : Colors.red;
    final isRealTime = realTimeUpdate != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: signalColor.withAlpha(76),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header row
              Row(
                children: [
                  // Symbol and market type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          signal.symbol,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: signal.marketType == 'crypto' 
                                ? Colors.blue.withAlpha(51)
                                : Colors.purple.withAlpha(51),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            signal.marketType == 'crypto' ? 'CRYPTO' : 'SET',
                            style: TextStyle(
                              fontSize: 10,
                              color: signal.marketType == 'crypto' 
                                  ? Colors.blue 
                                  : Colors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Signal badge
                  Consumer<FavouriteProvider>(
                    builder: (context, favouriteProvider, child) {
                      final isFav = favouriteProvider.isFavourite(signal.symbol);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.grey,
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: signalColor.withAlpha(51),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSignalIcon(),
                          color: signalColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          signal.signalType.toUpperCase(),
                          style: TextStyle(
                            color: signalColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price with real-time indicator
                  _buildStatWithRealTime(
                    context,
                    'Price',
                    _formatPrice(displayPrice),
                    null,
                    isRealTime,
                  ),
                  // Change
                  _buildStat(
                    context,
                    'Change',
                    '${displayChange >= 0 ? '+' : ''}${displayChange.toStringAsFixed(2)}%',
                    changeColor,
                  ),
                  // RSI
                  _buildStat(
                    context,
                    'RSI',
                    signal.rsi.toStringAsFixed(1),
                    _getRsiColor(signal.rsi),
                  ),
                  // Confidence
                  _buildStat(
                    context,
                    'Confidence',
                    '${(signal.confidence * 100).toStringAsFixed(0)}%',
                    signalColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, Color? valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatWithRealTime(BuildContext context, String label, String value, Color? valueColor, bool isRealTime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(128),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    final currencySymbol = signal.marketType == 'crypto' ? '\$' : '฿';
    if (price >= 1000) {
      return '$currencySymbol${price.toStringAsFixed(2)}';
    } else if (price >= 1) {
      return '$currencySymbol${price.toStringAsFixed(3)}';
    } else {
      return '$currencySymbol${price.toStringAsFixed(6)}';
    }
  }

  Color _getRsiColor(double rsi) {
    if (rsi < 30) return Colors.green;
    if (rsi > 70) return Colors.red;
    return Colors.grey;
  }
}
