import 'package:flutter/material.dart';
import '../models/investment_goal.dart';

/// Patience Meter Widget
/// Shows whether to WAIT or BUY based on AI analysis
class PatienceMeterWidget extends StatelessWidget {
  final PatienceMeter meter;
  final VoidCallback? onRefresh;

  const PatienceMeterWidget({
    super.key,
    required this.meter,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWait = meter.shouldWait;
    final primaryColor = isWait ? Colors.orange : Colors.green;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isWait ? Icons.hourglass_top : Icons.check_circle,
                      color: primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Patience Meter',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefresh,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withAlpha(77),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWait ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      meter.action,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Patience Score Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ความอดทน'),
                    Text(
                      '${meter.patienceScore.toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: meter.patienceScore / 100,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ซื้อเลย', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    Text('รออีกหน่อย', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meter.reason,
                      style: TextStyle(color: primaryColor.withAlpha(230)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // FOMO Risk
            if (meter.fomoRisk > 0.3)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ความเสี่ยง FOMO: ${(meter.fomoRisk * 100).toInt()}%',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Factors
            ExpansionTile(
              title: const Text('ปัจจัยที่วิเคราะห์'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: meter.factors.map((factor) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_right,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(factor, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Investment Roadmap Comparison Widget
/// Shows profit comparison: Buy Today vs Buy at Target
class RoadmapComparisonWidget extends StatelessWidget {
  final InvestmentRoadmap roadmap;
  final String marketType;

  const RoadmapComparisonWidget({
    super.key,
    required this.roadmap,
    this.marketType = 'crypto',
  });

  /// Get currency symbol based on market type
  String get _currencySymbol => marketType == 'thai_stock' ? '฿' : '\$';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxProfit = [roadmap.profitIfBuyToday, roadmap.profitIfBuyAtTarget]
        .reduce((a, b) => a.abs() > b.abs() ? a : b)
        .abs();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.compare_arrows, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Investment Roadmap',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${roadmap.symbol} • เงินต้น ฿${_formatNumber(roadmap.initialCapital)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            // Target Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoColumn('ราคาปัจจุบัน', '$_currencySymbol${_formatPrice(roadmap.currentPrice)}'),
                  Container(width: 1, height: 40, color: Colors.blue.withAlpha(77)),
                  _buildInfoColumn('ราคาเบ็ด', '$_currencySymbol${_formatPrice(roadmap.targetEntryPrice)}'),
                  Container(width: 1, height: 40, color: Colors.blue.withAlpha(77)),
                  _buildInfoColumn('ราคาทำนาย', '$_currencySymbol${_formatPrice(roadmap.predictedPrice)}'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Comparison Bars
            Text(
              'เปรียบเทียบกำไร',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Buy Today Bar
            _buildProfitBar(
              label: 'ซื้อวันนี้',
              profit: roadmap.profitIfBuyToday,
              percent: roadmap.percentIfBuyToday,
              maxValue: maxProfit,
              color: roadmap.reachesGoalIfBuyToday ? Colors.green : Colors.orange,
              reachesGoal: roadmap.reachesGoalIfBuyToday,
            ),
            const SizedBox(height: 16),

            // Buy at Target Bar
            _buildProfitBar(
              label: 'ซื้อที่ราคาเบ็ด',
              profit: roadmap.profitIfBuyAtTarget,
              percent: roadmap.percentIfBuyAtTarget,
              maxValue: maxProfit,
              color: roadmap.reachesGoalIfBuyAtTarget ? Colors.green : Colors.orange,
              reachesGoal: roadmap.reachesGoalIfBuyAtTarget,
            ),
            const SizedBox(height: 20),

            // Difference
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: roadmap.profitDifference > 0
                      ? [Colors.green.withAlpha(51), Colors.green.withAlpha(26)]
                      : [Colors.orange.withAlpha(51), Colors.orange.withAlpha(26)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'ส่วนต่างกำไร',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '฿${_formatNumber(roadmap.profitDifference.abs())}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: roadmap.profitDifference > 0 ? Colors.green : Colors.orange,
                    ),
                  ),
                  Text(
                    roadmap.profitDifference > 0
                        ? 'ได้มากกว่าถ้ารอซื้อที่ราคาเบ็ด'
                        : 'ได้น้อยกว่าถ้าซื้อวันนี้',
                    style: TextStyle(
                      color: roadmap.profitDifference > 0 ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Goal Status
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  roadmap.reachesGoalIfBuyAtTarget ? Icons.check_circle : Icons.pending,
                  color: roadmap.reachesGoalIfBuyAtTarget ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    roadmap.reachesGoalIfBuyAtTarget
                        ? 'ถึงเป้าหมาย ฿${_formatNumber(roadmap.targetProfit)} ได้!'
                        : 'ยังไม่ถึงเป้าหมาย ฿${_formatNumber(roadmap.targetProfit)}',
                    style: TextStyle(
                      color: roadmap.reachesGoalIfBuyAtTarget ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProfitBar({
    required String label,
    required double profit,
    required double percent,
    required double maxValue,
    required Color color,
    required bool reachesGoal,
  }) {
    final barWidth = maxValue > 0 ? (profit.abs() / maxValue).clamp(0.1, 1.0) : 0.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Row(
              children: [
                if (reachesGoal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '✓ ถึงเป้า',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  '+${percent.toStringAsFixed(1)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            FractionallySizedBox(
              widthFactor: barWidth,
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withAlpha(179)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '฿${_formatNumber(profit)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatPrice(double price) {
    if (price >= 1) {
      return price.toStringAsFixed(2);
    } else if (price >= 0.01) {
      return price.toStringAsFixed(4);
    }
    return price.toStringAsFixed(6);
  }
}

/// Entry Alert Widget
/// Shows probability of reaching target entry price
class EntryAlertWidget extends StatelessWidget {
  final EntryAlert alert;
  final VoidCallback? onSetAlert;
  final String marketType;

  const EntryAlertWidget({
    super.key,
    required this.alert,
    this.onSetAlert,
    this.marketType = 'crypto',
  });

  /// Get currency symbol based on market type
  String get _currencySymbol => marketType == 'thai_stock' ? '฿' : '\$';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color statusColor;
    final IconData statusIcon;

    switch (alert.recommendation) {
      case 'BUY_NOW':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ALMOST_THERE':
        statusColor = Colors.orange;
        statusIcon = Icons.timer;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phishing, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'เบ็ดราคา ${alert.symbol}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        alert.recommendation.replaceAll('_', ' '),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Price Comparison
            Row(
              children: [
                Expanded(
                  child: _buildPriceBox(
                    label: 'ราคาปัจจุบัน',
                    price: alert.currentPrice,
                    color: Colors.blue,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Colors.grey),
                ),
                Expanded(
                  child: _buildPriceBox(
                    label: 'ราคาเบ็ด',
                    price: alert.targetEntryPrice,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Distance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: alert.isAtTarget
                    ? Colors.green.withAlpha(26)
                    : Colors.grey.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    alert.isAtTarget
                        ? '🎯 ถึงราคาเบ็ดแล้ว!'
                        : 'ห่างจากเบ็ด ${alert.distancePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: alert.isAtTarget ? Colors.green.shade700 : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Probability
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('โอกาสถึงเบ็ดใน 7-14 วัน'),
                    Text(
                      '${(alert.reachProbability * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: alert.reachProbability >= 0.6
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: alert.reachProbability,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      alert.reachProbability >= 0.6
                          ? Colors.green
                          : alert.reachProbability >= 0.4
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Market Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    'ความผันผวน',
                    '${(alert.volatility * 100).toStringAsFixed(1)}%',
                    Icons.show_chart,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatChip(
                    'แรงขาย',
                    '${(alert.sellingPressure * 100).toStringAsFixed(0)}%',
                    alert.sellingPressure > 0
                        ? Icons.trending_down
                        : Icons.trending_up,
                  ),
                ),
              ],
            ),

            // Set Alert Button
            if (onSetAlert != null && !alert.isAtTarget) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSetAlert,
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('ตั้งแจ้งเตือนเมื่อถึงเบ็ด'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBox({
    required String label,
    required double price,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(128)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            '$_currencySymbol${_formatPrice(price)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1) {
      return price.toStringAsFixed(2);
    } else if (price >= 0.01) {
      return price.toStringAsFixed(4);
    }
    return price.toStringAsFixed(6);
  }
}

/// 5x Potential Score Card
class PotentialScoreCard extends StatelessWidget {
  final PotentialScore score;
  final VoidCallback? onTap;
  final String marketType;

  const PotentialScoreCard({
    super.key,
    required this.score,
    this.onTap,
    this.marketType = 'crypto',
  });

  /// Get currency symbol based on market type
  String get _currencySymbol => marketType == 'thai_stock' ? '฿' : '\$';

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor(score.tier);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tierColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          score.tier,
                          style: TextStyle(
                            color: tierColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.symbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            score.category,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_currencySymbol${_formatPrice(score.currentPrice)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (score.has5xPotential)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${score.potentialMultiplier.toStringAsFixed(0)}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Score Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Potential Score'),
                      Text(
                        '${score.potentialScore.toInt()}/100',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: tierColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: score.potentialScore / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Growth Rate', '+${score.growthRate.toStringAsFixed(0)}%/yr'),
                  _buildMiniStat('5Y Target', '$_currencySymbol${_formatPrice(score.fiveYearPrediction)}'),
                  _buildMiniStat('Market Cap', _formatMarketCap(score.marketCap)),
                ],
              ),
              const SizedBox(height: 12),

              // Reason
              Text(
                score.reason,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'S':
        return Colors.purple;
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(1)}K';
    } else if (price >= 1) {
      return price.toStringAsFixed(2);
    } else if (price >= 0.01) {
      return price.toStringAsFixed(4);
    }
    return price.toStringAsFixed(6);
  }

  String _formatMarketCap(double cap) {
    if (cap >= 1e12) {
      return '${(cap / 1e12).toStringAsFixed(1)}T';
    } else if (cap >= 1e9) {
      return '${(cap / 1e9).toStringAsFixed(1)}B';
    } else if (cap >= 1e6) {
      return '${(cap / 1e6).toStringAsFixed(0)}M';
    }
    return cap.toStringAsFixed(0);
  }
}
