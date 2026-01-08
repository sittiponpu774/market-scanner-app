import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';

class PriceChart extends StatelessWidget {
  final ChartData chartData;
  final Color color;
  final String marketType;

  const PriceChart({
    super.key,
    required this.chartData,
    this.color = Colors.blue,
    this.marketType = 'crypto',
  });

  @override
  Widget build(BuildContext context) {
    if (chartData.prices.isEmpty) {
      return const Center(
        child: Text('No chart data available'),
      );
    }

    final prices = chartData.prices;
    final spots = prices.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.close);
    }).toList();

    final minY = prices.map((p) => p.low).reduce((a, b) => a < b ? a : b);
    final maxY = prices.map((p) => p.high).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withAlpha(51),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatPrice(value),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (prices.length - 1).toDouble(),
          minY: minY - padding,
          maxY: maxY + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withAlpha(51),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    _formatPrice(spot.y),
                    TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
        duration: Duration.zero, // Disable animation
      ),
    );
  }

  String _formatPrice(double price) {
    final currencySymbol = marketType == 'crypto' ? '\$' : '฿';
    if (price >= 1000) {
      return '$currencySymbol${price.toStringAsFixed(2)}';
    } else if (price >= 1) {
      return '$currencySymbol${price.toStringAsFixed(3)}';
    } else {
      return '$currencySymbol${price.toStringAsFixed(6)}';
    }
  }
}
