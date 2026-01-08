import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/api_service.dart';

class CryptoTab extends StatefulWidget {
  const CryptoTab({super.key});

  @override
  State<CryptoTab> createState() => _CryptoTabState();
}

class _CryptoTabState extends State<CryptoTab> {
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Signal? _searchResult;
  bool _isSearching = false;
  String? _searchError;
  
  // Fear & Greed Index
  FearGreedIndex? _fearGreedIndex;
  bool _isLoadingFearGreed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final limit = context.read<SettingsProvider>().displayLimit;
      context.read<SignalProvider>().fetchCryptoSignals(limit: limit);
      _loadFearGreedIndex();
    });
  }
  
  Future<void> _loadFearGreedIndex() async {
    setState(() => _isLoadingFearGreed = true);
    try {
      final index = await ApiService().getFearGreedIndex();
      if (mounted) {
        setState(() {
          _fearGreedIndex = index;
          _isLoadingFearGreed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFearGreed = false);
      }
    }
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
        if (provider.isLoading && provider.cryptoSignals.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.error != null && provider.cryptoSignals.isEmpty) {
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
                    provider.fetchCryptoSignals(limit: limit);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final signals = _filterBySearch(provider.getCryptoBySignal(_selectedFilter));

        return RefreshIndicator(
          onRefresh: () {
            final limit = context.read<SettingsProvider>().displayLimit;
            return provider.fetchCryptoSignals(limit: limit);
          },
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาเหรียญ (BTC, ETH, ...)',
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
                  onSubmitted: (value) => _searchRealCrypto(context, value),
                ),
              ),
              // Real search button
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : () => _searchRealCrypto(context, _searchQuery),
                      icon: _isSearching 
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_download, size: 18),
                      label: Text(_isSearching ? 'กำลังค้นหา...' : 'ดึงข้อมูลจริง "$_searchQuery" จาก Binance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
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
                      title: const Text('ไม่พบเหรียญ'),
                      subtitle: Text(_searchError!),
                    ),
                  ),
                ),
              // Fear & Greed Index + Filter Chips (same row)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Fear & Greed Compact
                    FearGreedCompact(
                      data: _fearGreedIndex,
                      isLoading: _isLoadingFearGreed,
                      onTap: () => _showFearGreedDetail(context),
                    ),
                    const SizedBox(width: 12),
                    // Filter Chips
                    Expanded(
                      child: SignalFilterChips(
                        selectedFilter: _selectedFilter,
                        onFilterChanged: (filter) {
                          setState(() => _selectedFilter = filter);
                        },
                        allCount: provider.countCryptoByType('ALL'),
                        buyCount: provider.countCryptoByType('BUY'),
                        sellCount: provider.countCryptoByType('SELL'),
                        holdCount: provider.countCryptoByType('HOLD'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
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
          side: BorderSide(color: Colors.orange, width: 2),
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
                        color: Colors.orange.withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 14, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            'ผลการค้นหา',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
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

  void _showFearGreedDetail(BuildContext context) {
    if (_fearGreedIndex == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FearGreedWidget(
              data: _fearGreedIndex,
              isLoading: false,
              onRefresh: () {
                Navigator.pop(context);
                _loadFearGreedIndex();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '\$${price.toStringAsFixed(2)}';
    } else if (price >= 1) {
      return '\$${price.toStringAsFixed(3)}';
    } else {
      return '\$${price.toStringAsFixed(6)}';
    }
  }

  Future<void> _searchRealCrypto(BuildContext context, String symbol) async {
    if (symbol.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResult = null;
    });
    
    final provider = context.read<SignalProvider>();
    final binanceProvider = context.read<BinanceProvider>();
    final signal = await provider.searchCryptoReal(symbol);
    
    if (mounted) {
      setState(() {
        _isSearching = false;
        if (signal != null) {
          _searchResult = signal;
          // Subscribe to this symbol for real-time updates
          binanceProvider.addSymbol(symbol);
        } else {
          _searchError = 'ไม่พบเหรียญ "$symbol" ใน Binance';
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
