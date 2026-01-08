import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favourite_provider.dart';
import '../providers/signal_provider.dart';
import '../providers/binance_provider.dart';
import '../models/models.dart';
import '../widgets/signal_card.dart';
import '../services/api_service.dart';

class FavouritesTab extends StatefulWidget {
  const FavouritesTab({super.key});

  @override
  State<FavouritesTab> createState() => _FavouritesTabState();
}

class _FavouritesTabState extends State<FavouritesTab> {
  final ApiService _apiService = ApiService();
  final Map<String, Signal> _fetchedSignals = {};
  final Set<String> _loadingSymbols = {};
  bool _isLoadingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMissingFavourites();
    });
  }

  Future<void> _loadMissingFavourites() async {
    final favouriteProvider = context.read<FavouriteProvider>();
    final signalProvider = context.read<SignalProvider>();
    
    if (!favouriteProvider.isLoaded) return;
    
    setState(() => _isLoadingAll = true);
    
    for (final favItem in favouriteProvider.favourites) {
      // Check if already in cache
      final inCrypto = signalProvider.cryptoSignals
          .any((s) => s.symbol == favItem.symbol);
      final inThai = signalProvider.thaiStockSignals
          .any((s) => s.symbol == favItem.symbol);
      
      if (!inCrypto && !inThai && !_fetchedSignals.containsKey(favItem.symbol)) {
        await _fetchSignal(favItem.symbol, favItem.marketType);
      }
    }
    
    if (mounted) {
      setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _fetchSignal(String symbol, String marketType) async {
    if (_loadingSymbols.contains(symbol)) return;
    
    setState(() => _loadingSymbols.add(symbol));
    
    try {
      Signal? signal;
      if (marketType == 'crypto') {
        signal = await _apiService.searchCryptoReal(symbol);
        // Subscribe to this symbol for real-time updates
        if (mounted) {
          context.read<BinanceProvider>().addSymbol(symbol);
        }
      } else {
        signal = await _apiService.searchThaiReal(symbol);
      }
      
      if (mounted) {
        setState(() {
          _fetchedSignals[symbol] = signal!;
          _loadingSymbols.remove(symbol);
        });
      }
    } catch (e) {
      debugPrint('Error fetching $symbol: $e');
      if (mounted) {
        setState(() => _loadingSymbols.remove(symbol));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FavouriteProvider, SignalProvider>(
      builder: (context, favouriteProvider, signalProvider, child) {
        if (!favouriteProvider.isLoaded) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (favouriteProvider.favourites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No favourites yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the heart icon on any signal\nto add it to your favourites',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        // Get favourite signals from both crypto and thai stocks, plus fetched ones
        final List<Signal> favouriteSignals = [];
        final List<FavouriteItem> pendingFavourites = [];
        
        for (final favItem in favouriteProvider.favourites) {
          // Try to find in crypto signals
          final cryptoSignal = signalProvider.cryptoSignals
              .where((s) => s.symbol == favItem.symbol)
              .firstOrNull;
          if (cryptoSignal != null) {
            favouriteSignals.add(cryptoSignal);
            continue;
          }
          
          // Try to find in thai stock signals
          final thaiSignal = signalProvider.thaiStockSignals
              .where((s) => s.symbol == favItem.symbol)
              .firstOrNull;
          if (thaiSignal != null) {
            favouriteSignals.add(thaiSignal);
            continue;
          }
          
          // Try to find in fetched signals
          final fetchedSignal = _fetchedSignals[favItem.symbol];
          if (fetchedSignal != null) {
            favouriteSignals.add(fetchedSignal);
            continue;
          }
          
          // Mark as pending
          pendingFavourites.add(favItem);
        }

        return RefreshIndicator(
          onRefresh: () async {
            _fetchedSignals.clear();
            await signalProvider.fetchAllSignals();
            await _loadMissingFavourites();
          },
          child: Column(
            children: [
              if (_isLoadingAll || _loadingSymbols.isNotEmpty)
                LinearProgressIndicator(
                  backgroundColor: Colors.grey[300],
                ),
              Expanded(
                child: favouriteSignals.isEmpty && pendingFavourites.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading favourite signals...',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await signalProvider.fetchAllSignals();
                                await _loadMissingFavourites();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: favouriteSignals.length + pendingFavourites.length,
                        itemBuilder: (context, index) {
                          if (index < favouriteSignals.length) {
                            final signal = favouriteSignals[index];
                            return SignalCard(
                              signal: signal,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/signal-detail',
                                  arguments: signal,
                                );
                              },
                            );
                          } else {
                            // Show loading card for pending favourites
                            final pending = pendingFavourites[index - favouriteSignals.length];
                            return _buildLoadingCard(pending);
                          }
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(FavouriteItem favItem) {
    final isLoading = _loadingSymbols.contains(favItem.symbol);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: favItem.marketType == 'crypto' 
              ? Colors.blue.withAlpha(51)
              : Colors.purple.withAlpha(51),
          child: Icon(
            favItem.marketType == 'crypto' 
                ? Icons.currency_bitcoin 
                : Icons.trending_up,
            color: favItem.marketType == 'crypto' ? Colors.blue : Colors.purple,
          ),
        ),
        title: Text(
          favItem.symbol,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isLoading ? 'กำลังโหลด...' : 'แตะเพื่อดึงข้อมูล',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _fetchSignal(favItem.symbol, favItem.marketType),
              ),
        onTap: isLoading ? null : () => _fetchSignal(favItem.symbol, favItem.marketType),
      ),
    );
  }
}
