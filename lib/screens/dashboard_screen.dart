import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/binance_widgets.dart';
import 'crypto_tab.dart';
import 'thai_stock_tab.dart';
import 'favourites_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> 
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Register lifecycle observer for auto-reconnect
    WidgetsBinding.instance.addObserver(this);
    
    // Load initial data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - auto reconnect
      debugPrint('📱 App resumed - checking connection...');
      _reconnectAndRefresh();
    }
  }

  Future<void> _reconnectAndRefresh() async {
    final settings = context.read<SettingsProvider>();
    final signalProvider = context.read<SignalProvider>();
    final binanceProvider = context.read<BinanceProvider>();
    
    // Check API connection
    await settings.checkConnection();
    
    // If connected, refresh data
    if (settings.isConnected) {
      debugPrint('✅ Connection restored - refreshing data...');
      await signalProvider.fetchAllSignals(limit: settings.displayLimit);
      
      // Re-subscribe to Binance WebSocket
      if (signalProvider.cryptoSignals.isNotEmpty) {
        await binanceProvider.subscribeFromSignals(signalProvider.cryptoSignals);
      }
    } else {
      debugPrint('❌ Still disconnected');
    }
  }

  Future<void> _initializeData() async {
    final settings = context.read<SettingsProvider>();
    final signalProvider = context.read<SignalProvider>();
    final binanceProvider = context.read<BinanceProvider>();
    
    // Check connection first
    await settings.checkConnection();
    
    // Fetch initial signals
    signalProvider.setNotificationsEnabled(settings.notificationsEnabled);
    await signalProvider.fetchAllSignals(limit: settings.displayLimit);
    
    // Subscribe to all crypto symbols from signals for real-time prices
    if (signalProvider.cryptoSignals.isNotEmpty) {
      await binanceProvider.subscribeFromSignals(signalProvider.cryptoSignals);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Scanner'),
        centerTitle: true,
        actions: [
          // Binance WebSocket status indicator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: BinanceStatusIndicator(),
          ),
          // API connection status
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  settings.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: settings.isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.favorite),
              child: Consumer<FavouriteProvider>(
                builder: (context, provider, _) => Text(
                  'Favourites (${provider.count})',
                ),
              ),
            ),
            Tab(
              icon: const Icon(Icons.currency_bitcoin),
              child: Consumer<SignalProvider>(
                builder: (context, provider, _) => Text(
                  'Crypto (${provider.cryptoSignals.length})',
                ),
              ),
            ),
            Tab(
              icon: const Icon(Icons.trending_up),
              child: Consumer<SignalProvider>(
                builder: (context, provider, _) => Text(
                  'Thai (${provider.thaiStockSignals.length})',
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FavouritesTab(),
          CryptoTab(),
          ThaiStockTab(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 5x Potential Scanner Button
          FloatingActionButton.small(
            heroTag: 'scanner',
            onPressed: () => Navigator.pushNamed(context, '/potential-scanner'),
            backgroundColor: Colors.purple,
            child: const Icon(Icons.rocket_launch, size: 20),
          ),
          const SizedBox(height: 12),
          // Refresh Button
          FloatingActionButton(
            heroTag: 'refresh',
            onPressed: () => _refreshAll(context),
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll(BuildContext context) async {
    final provider = context.read<SignalProvider>();
    final settings = context.read<SettingsProvider>();
    final binanceProvider = context.read<BinanceProvider>();
    
    // Check connection first
    await settings.checkConnection();
    
    provider.setNotificationsEnabled(settings.notificationsEnabled);
    await provider.fetchAllSignals(limit: settings.displayLimit);
    
    // Re-subscribe to Binance if needed
    if (provider.cryptoSignals.isNotEmpty) {
      await binanceProvider.subscribeFromSignals(provider.cryptoSignals);
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.isConnected 
              ? 'Signals refreshed!' 
              : 'Connection failed - using cached data'),
          duration: const Duration(seconds: 2),
          backgroundColor: settings.isConnected ? Colors.green : Colors.orange,
        ),
      );
    }
  }
}
