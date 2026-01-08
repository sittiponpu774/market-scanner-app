import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/investment_goal.dart';
import '../models/signal.dart';
import '../providers/investment_provider.dart';
import '../widgets/investment_widgets.dart';

/// Investment Roadmap Screen
/// Shows goal tracking, roadmap comparison, and patience meter
class InvestmentRoadmapScreen extends StatefulWidget {
  final Signal signal;

  const InvestmentRoadmapScreen({
    super.key,
    required this.signal,
  });

  @override
  State<InvestmentRoadmapScreen> createState() => _InvestmentRoadmapScreenState();
}

class _InvestmentRoadmapScreenState extends State<InvestmentRoadmapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Goal form controllers
  final _initialCapitalController = TextEditingController(text: '100000');
  final _targetProfitController = TextEditingController(text: '500000');
  final _targetEntryController = TextEditingController();
  int _selectedTimeframe = 5;

  // Analysis results
  InvestmentRoadmap? _roadmap;
  EntryAlert? _entryAlert;
  PatienceMeter? _patienceMeter;
  PotentialScore? _potentialScore;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _initialCapitalController.dispose();
    _targetProfitController.dispose();
    _targetEntryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final investmentProvider = context.read<InvestmentProvider>();
    
    try {
      // Calculate potential score
      _potentialScore = await investmentProvider.getPotentialScore(widget.signal);

      // Set default target entry based on current price
      if (_targetEntryController.text.isEmpty) {
        _targetEntryController.text =
            (widget.signal.price * 0.85).toStringAsFixed(6);
      }

      // Generate initial analysis
      await _generateAnalysis();
    } catch (e) {
      print('Error loading data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _generateAnalysis() async {
    final investmentProvider = context.read<InvestmentProvider>();

    final initialCapital = double.tryParse(_initialCapitalController.text) ?? 100000;
    final targetProfit = double.tryParse(_targetProfitController.text) ?? 500000;
    final targetEntry = double.tryParse(_targetEntryController.text) ??
        widget.signal.price * 0.85;

    // Create temporary goal for analysis
    final goal = InvestmentGoal(
      id: 'temp',
      symbol: widget.signal.symbol,
      marketType: widget.signal.marketType,
      initialCapital: initialCapital,
      targetProfit: targetProfit,
      timeframeYears: _selectedTimeframe,
      targetEntryPrice: targetEntry,
      createdAt: DateTime.now(),
    );

    // Estimate predicted price (simplified - should come from ML model)
    double predictedPrice = widget.signal.price;
    if (_potentialScore != null) {
      predictedPrice = _potentialScore!.fiveYearPrediction;
    } else {
      // Default estimate: 3x in 5 years for crypto
      predictedPrice = widget.signal.price * 3;
    }

    // Generate roadmap
    _roadmap = await investmentProvider.generateRoadmap(
      goal: goal,
      currentPrice: widget.signal.price,
      predictedPrice: predictedPrice,
    );

    // Analyze entry probability
    _entryAlert = await investmentProvider.investmentService.analyzeEntryProbability(
      symbol: widget.signal.symbol,
      currentPrice: widget.signal.price,
      targetEntryPrice: targetEntry,
    );

    // Analyze patience meter
    _patienceMeter = await investmentProvider.investmentService.analyzePatienceMeter(
      signal: widget.signal,
      targetEntryPrice: targetEntry,
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.signal.symbol} Investment'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Roadmap'),
            Tab(icon: Icon(Icons.phishing), text: 'Entry Alert'),
            Tab(icon: Icon(Icons.psychology), text: 'AI Analysis'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRoadmapTab(),
                _buildEntryAlertTab(),
                _buildAIAnalysisTab(),
              ],
            ),
    );
  }

  Widget _buildRoadmapTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goal Input Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ตั้งเป้าหมายการลงทุน',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Initial Capital
                  TextField(
                    controller: _initialCapitalController,
                    decoration: const InputDecoration(
                      labelText: 'เงินต้น (THB)',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Target Profit
                  TextField(
                    controller: _targetProfitController,
                    decoration: const InputDecoration(
                      labelText: 'เป้าหมายกำไร (THB)',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Timeframe
                  Row(
                    children: [
                      const Text('กรอบเวลา: '),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('3 ปี'),
                        selected: _selectedTimeframe == 3,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedTimeframe = 3);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('5 ปี'),
                        selected: _selectedTimeframe == 5,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedTimeframe = 5);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Target Entry Price
                  TextField(
                    controller: _targetEntryController,
                    decoration: InputDecoration(
                      labelText: 'ราคาเบ็ด (Target Entry)',
                      prefixText: '${widget.signal.marketType == 'thai_stock' ? '฿' : '\$'} ',
                      border: const OutlineInputBorder(),
                      helperText: 'ราคาปัจจุบัน: ${widget.signal.marketType == 'thai_stock' ? '฿' : '\$'}${widget.signal.price.toStringAsFixed(widget.signal.marketType == 'thai_stock' ? 2 : 4)}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),

                  // Calculate Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => _isLoading = true);
                        await _generateAnalysis();
                        setState(() => _isLoading = false);
                      },
                      icon: const Icon(Icons.calculate),
                      label: const Text('คำนวณ Roadmap'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Roadmap Comparison
          if (_roadmap != null) RoadmapComparisonWidget(
            roadmap: _roadmap!,
            marketType: widget.signal.marketType,
          ),

          // Save Goal Button
          if (_roadmap != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saveGoal,
                icon: const Icon(Icons.save),
                label: const Text('บันทึกเป้าหมายนี้'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryAlertTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Entry Alert Widget
          if (_entryAlert != null)
            EntryAlertWidget(
              alert: _entryAlert!,
              onSetAlert: _setNotificationAlert,
            ),

          const SizedBox(height: 16),

          // Patience Meter
          if (_patienceMeter != null)
            PatienceMeterWidget(
              meter: _patienceMeter!,
              onRefresh: _generateAnalysis,
            ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Potential Score Card
          if (_potentialScore != null)
            PotentialScoreCard(score: _potentialScore!),

          const SizedBox(height: 16),

          // AI Insights
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        'AI Investment Insights',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Signal Summary
                  _buildInsightRow(
                    icon: Icons.trending_up,
                    label: 'Signal',
                    value: widget.signal.signalType,
                    color: widget.signal.signalType == 'BUY'
                        ? Colors.green
                        : widget.signal.signalType == 'SELL'
                            ? Colors.red
                            : Colors.orange,
                  ),
                  _buildInsightRow(
                    icon: Icons.speed,
                    label: 'RSI',
                    value: widget.signal.rsi.toStringAsFixed(1),
                    color: widget.signal.rsi < 30
                        ? Colors.green
                        : widget.signal.rsi > 70
                            ? Colors.red
                            : null,
                  ),
                  _buildInsightRow(
                    icon: Icons.show_chart,
                    label: '24h Change',
                    value: '${widget.signal.changePercent >= 0 ? '+' : ''}${widget.signal.changePercent.toStringAsFixed(2)}%',
                    color: widget.signal.changePercent >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                  _buildInsightRow(
                    icon: Icons.verified,
                    label: 'Confidence',
                    value: '${(widget.signal.confidence * 100).toStringAsFixed(0)}%',
                  ),

                  if (_potentialScore != null) ...[
                    const Divider(height: 24),
                    _buildInsightRow(
                      icon: Icons.rocket_launch,
                      label: '5Y Potential',
                      value: '${_potentialScore!.potentialMultiplier.toStringAsFixed(1)}x',
                      color: _potentialScore!.has5xPotential
                          ? Colors.green
                          : Colors.orange,
                    ),
                    _buildInsightRow(
                      icon: Icons.category,
                      label: 'Sector',
                      value: _potentialScore!.category,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Recommendation
          if (_patienceMeter != null)
            Card(
              color: _patienceMeter!.shouldWait
                  ? Colors.orange.withAlpha(26)
                  : Colors.green.withAlpha(26),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _patienceMeter!.shouldWait
                          ? Icons.hourglass_top
                          : Icons.thumb_up,
                      size: 48,
                      color: _patienceMeter!.shouldWait
                          ? Colors.orange
                          : Colors.green,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _patienceMeter!.shouldWait
                          ? 'แนะนำให้รอจังหวะที่ดีกว่า'
                          : 'จังหวะดี พิจารณาเข้าซื้อได้',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _patienceMeter!.shouldWait
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _patienceMeter!.reason,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGoal() async {
    final investmentProvider = context.read<InvestmentProvider>();
    
    await investmentProvider.addGoal(
      symbol: widget.signal.symbol,
      marketType: widget.signal.marketType,
      initialCapital: double.tryParse(_initialCapitalController.text) ?? 100000,
      targetProfit: double.tryParse(_targetProfitController.text) ?? 500000,
      timeframeYears: _selectedTimeframe,
      targetEntryPrice: double.tryParse(_targetEntryController.text),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกเป้าหมายเรียบร้อย!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _setNotificationAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตั้งแจ้งเตือน'),
        content: Text(
          'ระบบจะแจ้งเตือนเมื่อราคา ${widget.signal.symbol} '
          'ลงมาถึง ${widget.signal.marketType == 'thai_stock' ? '฿' : '\$'}${_targetEntryController.text}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement Firebase notification
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ตั้งแจ้งเตือนเรียบร้อย!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('ตั้งแจ้งเตือน'),
          ),
        ],
      ),
    );
  }
}
