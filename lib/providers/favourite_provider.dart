import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FavouriteItem {
  final String symbol;
  final String marketType;

  FavouriteItem({required this.symbol, required this.marketType});

  Map<String, dynamic> toJson() => {'symbol': symbol, 'marketType': marketType};

  factory FavouriteItem.fromJson(Map<String, dynamic> json) {
    return FavouriteItem(
      symbol: json['symbol'] as String,
      marketType: json['marketType'] as String? ?? 'crypto',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavouriteItem &&
          runtimeType == other.runtimeType &&
          symbol == other.symbol;

  @override
  int get hashCode => symbol.hashCode;
}

class FavouriteProvider extends ChangeNotifier {
  static const String _favouritesKey = 'favourite_symbols';
  static const String _favouritesKeyV2 = 'favourite_items_v2';
  
  Set<FavouriteItem> _favourites = {};
  bool _isLoaded = false;
  bool _isFavouritesMode = false; // Track if we're in favourites-only notification mode

  Set<FavouriteItem> get favourites => _favourites;
  Set<String> get favouriteSymbols => _favourites.map((f) => f.symbol).toSet();
  bool get isLoaded => _isLoaded;

  FavouriteProvider() {
    loadFavourites();
  }
  
  /// Convert symbol to FCM topic names (returns multiple possible topics)
  /// e.g., "BTC" -> ["signal_BTC", "signal_BTC_USDT", "signal_BTCUSDT"]
  List<String> _symbolToTopics(String symbol) {
    final safe = symbol.replaceAll('/', '_').replaceAll('.', '_').toUpperCase();
    final topics = <String>[
      'signal_$safe',  // signal_BTC or signal_FET
    ];
    
    // If symbol doesn't contain USDT, add USDT variants
    if (!safe.contains('USDT')) {
      topics.add('signal_${safe}_USDT');  // signal_BTC_USDT
      topics.add('signal_${safe}USDT');   // signal_BTCUSDT
    }
    
    return topics;
  }
  
  /// Set favourites mode (called when notification mode changes)
  Future<void> setFavouritesMode(bool enabled) async {
    _isFavouritesMode = enabled;
    debugPrint('📱 setFavouritesMode: $enabled, favourites: ${_favourites.map((f) => f.symbol).toList()}');
    if (enabled) {
      // Subscribe to all favourite symbol topics
      await _subscribeToFavouriteTopics();
    } else {
      // Unsubscribe from all symbol topics
      await _unsubscribeFromAllSymbolTopics();
    }
  }
  
  /// Subscribe to FCM topics for all favourites
  Future<void> _subscribeToFavouriteTopics() async {
    try {
      final messaging = FirebaseMessaging.instance;
      for (final fav in _favourites) {
        final topics = _symbolToTopics(fav.symbol);
        for (final topic in topics) {
          await messaging.subscribeToTopic(topic);
          debugPrint('✅ Subscribed to topic: $topic');
        }
      }
    } catch (e) {
      debugPrint('Error subscribing to favourite topics: $e');
    }
  }
  
  /// Unsubscribe from all symbol topics
  Future<void> _unsubscribeFromAllSymbolTopics() async {
    try {
      final messaging = FirebaseMessaging.instance;
      for (final fav in _favourites) {
        final topics = _symbolToTopics(fav.symbol);
        for (final topic in topics) {
          await messaging.unsubscribeFromTopic(topic);
          debugPrint('🔕 Unsubscribed from topic: $topic');
        }
      }
    } catch (e) {
      debugPrint('Error unsubscribing from symbol topics: $e');
    }
  }

  /// Load favourites from SharedPreferences
  Future<void> loadFavourites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load notification mode to check if we need to subscribe to topics
      final savedMode = prefs.getString('notification_mode') ?? 'all';
      _isFavouritesMode = savedMode == 'favourites';
      debugPrint('📋 Loaded favourites mode: $_isFavouritesMode');
      
      // Try to load new format first
      final String? savedJson = prefs.getString(_favouritesKeyV2);
      if (savedJson != null) {
        final List<dynamic> decoded = json.decode(savedJson);
        _favourites = decoded
            .map((item) => FavouriteItem.fromJson(item as Map<String, dynamic>))
            .toSet();
      } else {
        // Migrate from old format
        final List<String>? oldFavourites = prefs.getStringList(_favouritesKey);
        if (oldFavourites != null) {
          _favourites = oldFavourites
              .map((symbol) => FavouriteItem(
                    symbol: symbol,
                    marketType: symbol.endsWith('.BK') ? 'thai_stock' : 'crypto',
                  ))
              .toSet();
          // Save in new format
          await _saveFavourites();
        }
      }
      
      // If we're in favourites mode, subscribe to all favourite topics
      if (_isFavouritesMode && _favourites.isNotEmpty) {
        debugPrint('⭐ Restoring topic subscriptions for ${_favourites.length} favourites');
        await _subscribeToFavouriteTopics();
      }
      
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favourites: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Save favourites to SharedPreferences
  Future<void> _saveFavourites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = json.encode(_favourites.map((f) => f.toJson()).toList());
      await prefs.setString(_favouritesKeyV2, jsonStr);
    } catch (e) {
      debugPrint('Error saving favourites: $e');
    }
  }

  /// Check if a symbol is favourite
  bool isFavourite(String symbol) {
    return _favourites.any((f) => f.symbol == symbol);
  }

  /// Get market type for a favourite
  String? getMarketType(String symbol) {
    try {
      return _favourites.firstWhere((f) => f.symbol == symbol).marketType;
    } catch (e) {
      return null;
    }
  }

  /// Toggle favourite status with market type
  Future<void> toggleFavourite(String symbol, {String marketType = 'crypto'}) async {
    final existing = _favourites.where((f) => f.symbol == symbol).toList();
    final topics = _symbolToTopics(symbol);
    
    if (existing.isNotEmpty) {
      // Removing from favourites
      _favourites.removeAll(existing);
      if (_isFavouritesMode) {
        try {
          for (final topic in topics) {
            await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
            debugPrint('🔕 Unsubscribed from topic: $topic');
          }
        } catch (e) {
          debugPrint('Error unsubscribing: $e');
        }
      }
    } else {
      // Adding to favourites
      _favourites.add(FavouriteItem(symbol: symbol, marketType: marketType));
      if (_isFavouritesMode) {
        try {
          for (final topic in topics) {
            await FirebaseMessaging.instance.subscribeToTopic(topic);
            debugPrint('✅ Subscribed to topic: $topic');
          }
        } catch (e) {
          debugPrint('Error subscribing: $e');
        }
      }
    }
    notifyListeners();
    await _saveFavourites();
  }

  /// Add to favourites with market type
  Future<void> addFavourite(String symbol, {String marketType = 'crypto'}) async {
    if (!isFavourite(symbol)) {
      _favourites.add(FavouriteItem(symbol: symbol, marketType: marketType));
      if (_isFavouritesMode) {
        try {
          final topics = _symbolToTopics(symbol);
          for (final topic in topics) {
            await FirebaseMessaging.instance.subscribeToTopic(topic);
            debugPrint('✅ Subscribed to topic: $topic');
          }
        } catch (e) {
          debugPrint('Error subscribing: $e');
        }
      }
      notifyListeners();
      await _saveFavourites();
    }
  }

  /// Remove from favourites
  Future<void> removeFavourite(String symbol) async {
    final existing = _favourites.where((f) => f.symbol == symbol).toList();
    if (existing.isNotEmpty) {
      _favourites.removeAll(existing);
      if (_isFavouritesMode) {
        try {
          final topics = _symbolToTopics(symbol);
          for (final topic in topics) {
            await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
            debugPrint('🔕 Unsubscribed from topic: $topic');
          }
        } catch (e) {
          debugPrint('Error unsubscribing: $e');
        }
      }
      notifyListeners();
      await _saveFavourites();
    }
  }

  /// Clear all favourites
  Future<void> clearFavourites() async {
    if (_isFavouritesMode) {
      await _unsubscribeFromAllSymbolTopics();
    }
    _favourites.clear();
    notifyListeners();
    await _saveFavourites();
  }

  /// Get favourite count
  int get count => _favourites.length;
}
