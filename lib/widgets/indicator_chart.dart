import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class IndicatorChart extends StatelessWidget {
  final List<double> data;
  final String title;
  final Color color;
  final double? upperThreshold;
  final double? lowerThreshold;

  const IndicatorChart({
    super.key,
    required this.data,
    required this.title,
    required this.color,
    this.upperThreshold,
    this.lowerThreshold,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    final validData = data.where((d) => !d.isNaN && !d.isInfinite).toList();
    if (validData.isEmpty) return const SizedBox.shrink();

    final minY = validData.reduce((a, b) => a < b ? a : b);
    final maxY = validData.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: minY - padding,
                maxY: maxY + padding,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (upperThreshold != null)
                      HorizontalLine(
                        y: upperThreshold!,
                        color: Colors.red.withAlpha(128),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    if (lowerThreshold != null)
                      HorizontalLine(
                        y: lowerThreshold!,
                        color: Colors.green.withAlpha(128),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                  ],
                ),
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
                      color: color.withAlpha(38),
                    ),
                  ),
                ],
              ),
              duration: Duration.zero, // Disable animation
            ),
          ),
        ],
      ),
    );
  }
}
