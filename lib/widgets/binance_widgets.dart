import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/binance_provider.dart';
import '../services/binance_websocket_service.dart';

/// Widget to show Binance WebSocket connection status
class BinanceStatusIndicator extends StatelessWidget {
  const BinanceStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BinanceProvider>(
      builder: (context, provider, _) {
        final status = provider.status;
        final Color color;
        final IconData icon;
        final String text;

        switch (status) {
          case BinanceConnectionStatus.connected:
            color = Colors.green;
            icon = Icons.wifi;
            text = 'Real-time';
            break;
          case BinanceConnectionStatus.connecting:
          case BinanceConnectionStatus.reconnecting:
            color = Colors.orange;
            icon = Icons.wifi_find;
            text = 'Connecting...';
            break;
          case BinanceConnectionStatus.error:
            color = Colors.red;
            icon = Icons.wifi_off;
            text = 'Error';
            break;
          default:
            color = Colors.grey;
            icon = Icons.wifi_off;
            text = 'Offline';
        }

        return Tooltip(
          message: 'Binance WebSocket: ${status.name}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(128)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget to show real-time price with animation
class RealTimePriceWidget extends StatelessWidget {
  final String symbol;
  final double? fallbackPrice;
  final String marketType;
  final TextStyle? style;

  const RealTimePriceWidget({
    super.key,
    required this.symbol,
    this.fallbackPrice,
    this.marketType = 'crypto',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    // Only show real-time for crypto
    if (marketType != 'crypto') {
      return Text(
        _formatPrice(fallbackPrice ?? 0, marketType),
        style: style,
      );
    }

    return Consumer<BinanceProvider>(
      builder: (context, provider, _) {
        final update = provider.getPrice(symbol);
        final price = update?.price ?? fallbackPrice ?? 0;
        final isRealTime = update != null;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatPrice(price, marketType),
              style: style,
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
        );
      },
    );
  }

  String _formatPrice(double price, String marketType) {
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

/// Widget to show real-time change percent
class RealTimeChangeWidget extends StatefulWidget {
  final String symbol;
  final double? fallbackChangePercent;
  final String marketType;
  final TextStyle? style;

  const RealTimeChangeWidget({
    super.key,
    required this.symbol,
    this.fallbackChangePercent,
    this.marketType = 'crypto',
    this.style,
  });

  @override
  State<RealTimeChangeWidget> createState() => _RealTimeChangeWidgetState();
}

class _RealTimeChangeWidgetState extends State<RealTimeChangeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double? _previousChange;
  Color _flashColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.marketType != 'crypto') {
      return _buildChangeText(widget.fallbackChangePercent ?? 0);
    }

    return Consumer<BinanceProvider>(
      builder: (context, provider, _) {
        final update = provider.getPrice(widget.symbol);
        final changePercent = update?.priceChangePercent ?? widget.fallbackChangePercent ?? 0;

        // Flash animation on change
        if (_previousChange != null && _previousChange != changePercent) {
          _flashColor = changePercent > _previousChange! ? Colors.green : Colors.red;
          _animationController.forward(from: 0);
        }
        _previousChange = changePercent;

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final flashOpacity = (1 - _animationController.value) * 0.3;
            return Container(
              decoration: BoxDecoration(
                color: _flashColor.withOpacity(flashOpacity),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: _buildChangeText(changePercent),
            );
          },
        );
      },
    );
  }

  Widget _buildChangeText(double changePercent) {
    final color = changePercent >= 0 ? Colors.green : Colors.red;
    final prefix = changePercent >= 0 ? '+' : '';
    
    return Text(
      '$prefix${changePercent.toStringAsFixed(2)}%',
      style: widget.style?.copyWith(color: color) ?? TextStyle(color: color),
    );
  }
}
