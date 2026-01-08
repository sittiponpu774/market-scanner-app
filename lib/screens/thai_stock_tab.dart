import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class ThaiStockTab extends StatefulWidget {
  const ThaiStockTab({super.key});

  @override
  State<ThaiStockTab> createState() => _ThaiStockTabState();
}

class _ThaiStockTabState extends State<ThaiStockTab> {
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Signal? _searchResult;
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final limit = context.read<SettingsProvider>().displayLimit;
      context.read<SignalProvider>().fetchThaiStockSignals(limit: limit);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Signal> _filterBySearch(List<Signal> signals) {
    if (_searchQuery.isEmpty) return signals;
    return signals.where((s) => 
      s.symbol.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SignalProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.thaiStockSignals.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.error != null && provider.thaiStockSignals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(provider.error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final limit = context.read<SettingsProvider>().displayLimit;
                    provider.fetchThaiStockSignals(limit: limit);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final signals = _filterBySearch(provider.getThaiBySignal(_selectedFilter));

        return RefreshIndicator(
          onRefresh: () {
            final limit = context.read<SettingsProvider>().displayLimit;
            return provider.fetchThaiStockSignals(limit: limit);
          },
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาหุ้น (PTT, KBANK, ...)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _searchResult = null;
                                _searchError = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _searchResult = null;
                      _searchError = null;
                    });
                  },
                  onSubmitted: (value) => _searchRealThai(context, value),
                ),
              ),
              // Real search button
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : () => _searchRealThai(context, _searchQuery),
                      icon: _isSearching 
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_download, size: 18),
                      label: Text(_isSearching ? 'กำลังค้นหา...' : 'ดึงข้อมูลจริง "$_searchQuery" จาก Yahoo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              // Search Result Card
              if (_searchResult != null)
                _buildSearchResultCard(_searchResult!),
              // Search Error
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Card(
                    color: Colors.red.withAlpha(25),
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: const Text('ไม่พบหุ้น'),
                      subtitle: Text(_searchError!),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SignalFilterChips(
                selectedFilter: _selectedFilter,
                onFilterChanged: (filter) {
                  setState(() => _selectedFilter = filter);
                },
                allCount: provider.countThaiByType('ALL'),
                buyCount: provider.countThaiByType('BUY'),
                sellCount: provider.countThaiByType('SELL'),
                holdCount: provider.countThaiByType('HOLD'),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: signals.isEmpty
                    ? const Center(child: Text('No signals found'))
                    : ListView.builder(
                        itemCount: signals.length,
                        itemBuilder: (context, index) {
                          final signal = signals[index];
                          return SignalCard(
                            signal: signal,
                            onTap: () => _showSignalDetails(context, signal),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultCard(Signal signal) {
    final signalColor = _getSignalColor(signal.signalType);
    final changeColor = signal.changePercent >= 0 ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue, width: 2),
        ),
        child: InkWell(
          onTap: () => _showSignalDetails(context, signal),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 14, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            'ผลการค้นหา',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Favourite button
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
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signal.symbol,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatPrice(signal.price),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: signalColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            signal.signalType.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${signal.changePercent >= 0 ? '+' : ''}${signal.changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStat('RSI', signal.rsi.toStringAsFixed(1)),
                    _buildMiniStat('Confidence', '${(signal.confidence * 100).toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showSignalDetails(context, signal),
                    icon: const Icon(Icons.analytics, size: 18),
                    label: const Text('ดูรายละเอียด'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
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

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '฿${price.toStringAsFixed(2)}';
    } else if (price >= 1) {
      return '฿${price.toStringAsFixed(2)}';
    } else {
      return '฿${price.toStringAsFixed(4)}';
    }
  }

  Future<void> _searchRealThai(BuildContext context, String symbol) async {
    if (symbol.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResult = null;
    });
    
    final provider = context.read<SignalProvider>();
    final signal = await provider.searchThaiReal(symbol);
    
    if (mounted) {
      setState(() {
        _isSearching = false;
        if (signal != null) {
          _searchResult = signal;
        } else {
          _searchError = 'ไม่พบหุ้น "$symbol" ใน Yahoo Finance';
        }
      });
    }
  }

  void _showSignalDetails(BuildContext context, Signal signal) {
    Navigator.pushNamed(
      context,
      '/signal-detail',
      arguments: signal,
    );
  }
}
