import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/investment_goal.dart';
import '../providers/investment_provider.dart';
import '../providers/signal_provider.dart';
import '../widgets/investment_widgets.dart';

/// 5x Potential Scanner Screen
/// Shows coins with high potential for long-term investment
class PotentialScannerScreen extends StatefulWidget {
  const PotentialScannerScreen({super.key});

  @override
  State<PotentialScannerScreen> createState() => _PotentialScannerScreenState();
}

class _PotentialScannerScreenState extends State<PotentialScannerScreen> {
  bool _isLoading = true;
  String _selectedTier = 'ALL';
  String _selectedCategory = 'ALL';

  final List<String> _tiers = ['ALL', 'S', 'A', 'B', 'C'];
  final List<String> _categories = [
    'ALL', 'AI', 'Layer1', 'Layer2', 'DeFi', 'Gaming', 'Meme', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPotentials();
    });
  }

  Future<void> _loadPotentials() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final investmentProvider = context.read<InvestmentProvider>();
    final signalProvider = context.read<SignalProvider>();

    // Get all crypto signals
    final signals = signalProvider.cryptoSignals;
    
    if (signals.isNotEmpty) {
      await investmentProvider.scan5xPotentials(signals, topN: 50);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('5x Potential Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPotentials,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Tier Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Tier: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      ..._tiers.map((tier) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tier == 'ALL' ? 'All' : 'Tier $tier'),
                          selected: _selectedTier == tier,
                          onSelected: (selected) {
                            setState(() => _selectedTier = tier);
                          },
                          selectedColor: _getTierColor(tier).withAlpha(51),
                          checkmarkColor: _getTierColor(tier),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Category Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Category: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      ..._categories.map((category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category == 'ALL' ? 'All' : category),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            setState(() => _selectedCategory = category);
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Scanning for 5x potential coins...'),
                      ],
                    ),
                  )
                : Consumer<InvestmentProvider>(
                    builder: (context, provider, _) {
                      var potentials = provider.topPotentials;

                      // Apply filters
                      if (_selectedTier != 'ALL') {
                        potentials = potentials
                            .where((p) => p.tier == _selectedTier)
                            .toList();
                      }
                      if (_selectedCategory != 'ALL') {
                        potentials = potentials
                            .where((p) => p.category == _selectedCategory ||
                                (_selectedCategory == 'Other' && 
                                 !_categories.contains(p.category)))
                            .toList();
                      }

                      if (potentials.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No coins found with current filters',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTier = 'ALL';
                                    _selectedCategory = 'ALL';
                                  });
                                },
                                child: const Text('Reset Filters'),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _loadPotentials,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: potentials.length,
                          itemBuilder: (context, index) {
                            final score = potentials[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PotentialScoreCard(
                                score: score,
                                onTap: () => _showDetails(score),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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
      case 'C':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showDetails(PotentialScore score) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTierColor(score.tier).withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      score.tier,
                      style: TextStyle(
                        color: _getTierColor(score.tier),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          score.symbol,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(26),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                score.category,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (score.has5xPotential) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${score.potentialMultiplier.toStringAsFixed(0)}x Potential',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Score Details
              _buildDetailCard(
                title: 'Potential Analysis',
                children: [
                  _buildDetailRow('Current Price', '${_getCurrencySymbol(null)}${score.currentPrice.toStringAsFixed(4)}'),
                  _buildDetailRow('5Y Target', '${_getCurrencySymbol(null)}${score.fiveYearPrediction.toStringAsFixed(4)}'),
                  _buildDetailRow('Potential Score', '${score.potentialScore.toInt()}/100'),
                  _buildDetailRow('Annual Growth Est.', '+${score.growthRate.toStringAsFixed(0)}%'),
                  _buildDetailRow('Market Cap', _formatMarketCap(score.marketCap)),
                ],
              ),
              const SizedBox(height: 16),

              // Reasons
              _buildDetailCard(
                title: 'Why This Coin?',
                children: [
                  Text(
                    score.reason,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to signal detail
                        final signalProvider = context.read<SignalProvider>();
                        final signal = signalProvider.cryptoSignals.firstWhere(
                          (s) => s.symbol.toUpperCase() == score.symbol.toUpperCase(),
                          orElse: () => signalProvider.cryptoSignals.first,
                        );
                        Navigator.pushNamed(context, '/signal-detail', arguments: signal);
                      },
                      icon: const Icon(Icons.analytics),
                      label: const Text('View Signal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to investment roadmap
                        final signalProvider = context.read<SignalProvider>();
                        final signal = signalProvider.cryptoSignals.firstWhere(
                          (s) => s.symbol.toUpperCase() == score.symbol.toUpperCase(),
                          orElse: () => signalProvider.cryptoSignals.first,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              body: Center(
                                child: Text('Investment Roadmap for ${signal.symbol}'),
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Plan Investment'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatMarketCap(double cap) {
    if (cap >= 1e12) {
      return '${(cap / 1e12).toStringAsFixed(2)}T';
    } else if (cap >= 1e9) {
      return '${(cap / 1e9).toStringAsFixed(2)}B';
    } else if (cap >= 1e6) {
      return '${(cap / 1e6).toStringAsFixed(0)}M';
    }
    return cap.toStringAsFixed(0);
  }

  /// Get currency symbol - Crypto uses $, Thai stocks use ฿
  String _getCurrencySymbol(String? marketType) {
    return marketType == 'thai_stock' ? '฿' : '\$';
  }
}
