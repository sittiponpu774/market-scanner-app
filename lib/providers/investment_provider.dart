import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/investment_goal.dart';
import '../models/signal.dart';
import '../services/investment_service.dart';

/// Investment Provider for Goal-Based Tracking & Alerts
class InvestmentProvider extends ChangeNotifier {
  final InvestmentService investmentService = InvestmentService();
  
  // Alias for backward compatibility
  InvestmentService get _investmentService => investmentService;
  
  // State
  List<InvestmentGoal> _goals = [];
  final Map<String, EntryAlert> _alerts = {};
  final Map<String, PatienceMeter> _patienceMeters = {};
  final Map<String, InvestmentRoadmap> _roadmaps = {};
  List<PotentialScore> _topPotentials = [];
  
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<InvestmentGoal> get goals => _goals;
  Map<String, EntryAlert> get alerts => _alerts;
  Map<String, PatienceMeter> get patienceMeters => _patienceMeters;
  Map<String, InvestmentRoadmap> get roadmaps => _roadmaps;
  List<PotentialScore> get topPotentials => _topPotentials;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Storage keys
  static const String _storageKey = 'investment_goals';
  static const String _alertsStorageKey = 'investment_alerts';
  
  // ===========================================
  // GOAL MANAGEMENT
  // ===========================================
  
  /// Load goals and alerts from storage
  Future<void> loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load goals
      final goalsJson = prefs.getString(_storageKey);
      
      if (goalsJson != null) {
        final List<dynamic> decoded = json.decode(goalsJson);
        _goals = decoded.map((g) => InvestmentGoal.fromJson(g)).toList();
      }
      
      // Load alerts
      final alertsJson = prefs.getString(_alertsStorageKey);
      if (alertsJson != null) {
        final Map<String, dynamic> decoded = json.decode(alertsJson);
        decoded.forEach((key, value) {
          _alerts[key] = EntryAlert.fromJson(value);
        });
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading goals: $e');
      _error = 'Failed to load goals';
    }
  }
  
  /// Save goals to storage
  Future<void> _saveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = json.encode(_goals.map((g) => g.toJson()).toList());
      await prefs.setString(_storageKey, goalsJson);
    } catch (e) {
      print('Error saving goals: $e');
    }
  }
  
  /// Save alerts to storage
  Future<void> _saveAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsMap = <String, dynamic>{};
      _alerts.forEach((key, value) {
        alertsMap[key] = value.toJson();
      });
      await prefs.setString(_alertsStorageKey, json.encode(alertsMap));
    } catch (e) {
      print('Error saving alerts: $e');
    }
  }
  
  /// Add new investment goal
  Future<void> addGoal({
    required String symbol,
    required String marketType,
    required double initialCapital,
    required double targetProfit,
    required int timeframeYears,
    double? targetEntryPrice,
  }) async {
    final goal = InvestmentGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: symbol.toUpperCase(),
      marketType: marketType,
      initialCapital: initialCapital,
      targetProfit: targetProfit,
      timeframeYears: timeframeYears,
      targetEntryPrice: targetEntryPrice,
      createdAt: DateTime.now(),
    );
    
    _goals.add(goal);
    await _saveGoals();
    notifyListeners();
    
    // Refresh analysis for new goal
    if (targetEntryPrice != null) {
      await refreshEntryAlert(goal);
    }
  }
  
  /// Update existing goal
  Future<void> updateGoal(InvestmentGoal updatedGoal) async {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      _goals[index] = updatedGoal.copyWith(updatedAt: DateTime.now());
      await _saveGoals();
      notifyListeners();
    }
  }
  
  /// Delete goal
  Future<void> deleteGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    await _saveGoals();
    notifyListeners();
  }
  
  /// Get goals for a specific symbol
  List<InvestmentGoal> getGoalsForSymbol(String symbol) {
    return _goals.where((g) => 
      g.symbol.toUpperCase() == symbol.toUpperCase()
    ).toList();
  }
  
  // ===========================================
  // ENTRY ALERT ANALYSIS
  // ===========================================
  
  /// Refresh entry alert for a goal
  Future<void> refreshEntryAlert(InvestmentGoal goal) async {
    if (goal.targetEntryPrice == null) return;
    
    try {
      final currentPrice = await _investmentService.getCurrentPrice(
        goal.symbol, 
        goal.marketType,
      );
      
      if (currentPrice != null) {
        final alert = await _investmentService.analyzeEntryProbability(
          symbol: goal.symbol,
          currentPrice: currentPrice,
          targetEntryPrice: goal.targetEntryPrice!,
        );
        
        _alerts[goal.symbol] = alert;
        await _saveAlerts(); // Save to storage
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing alert: $e');
    }
  }
  
  /// Refresh all entry alerts
  Future<void> refreshAllAlerts() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      for (final goal in _goals) {
        await refreshEntryAlert(goal);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get alert for symbol
  EntryAlert? getAlert(String symbol) => _alerts[symbol.toUpperCase()];
  
  // ===========================================
  // PATIENCE METER
  // ===========================================
  
  /// Analyze patience meter for a signal
  Future<void> analyzePatienceMeter(Signal signal, double targetEntryPrice) async {
    try {
      final meter = await _investmentService.analyzePatienceMeter(
        signal: signal,
        targetEntryPrice: targetEntryPrice,
      );
      
      _patienceMeters[signal.symbol] = meter;
      notifyListeners();
    } catch (e) {
      print('Error analyzing patience meter: $e');
    }
  }
  
  /// Get patience meter for symbol
  PatienceMeter? getPatienceMeter(String symbol) => _patienceMeters[symbol.toUpperCase()];
  
  // ===========================================
  // INVESTMENT ROADMAP
  // ===========================================
  
  /// Generate roadmap for a goal
  Future<InvestmentRoadmap?> generateRoadmap({
    required InvestmentGoal goal,
    required double currentPrice,
    required double predictedPrice,
  }) async {
    try {
      final roadmap = await _investmentService.generateRoadmap(
        goal: goal,
        currentPrice: currentPrice,
        predictedPrice: predictedPrice,
      );
      
      _roadmaps[goal.symbol] = roadmap;
      notifyListeners();
      return roadmap;
    } catch (e) {
      print('Error generating roadmap: $e');
      return null;
    }
  }
  
  /// Get roadmap for symbol
  InvestmentRoadmap? getRoadmap(String symbol) => _roadmaps[symbol.toUpperCase()];
  
  // ===========================================
  // 5X POTENTIAL SCANNING
  // ===========================================
  
  /// Scan for 5x potential coins
  Future<void> scan5xPotentials(List<Signal> signals, {int topN = 10}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _topPotentials = await _investmentService.scan5xPotentialCoins(
        signals: signals,
        topN: topN,
      );
    } catch (e) {
      print('Error scanning potentials: $e');
      _error = 'Failed to scan potentials';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get potential score for a signal
  Future<PotentialScore?> getPotentialScore(Signal signal) async {
    try {
      return await _investmentService.calculate5xPotential(signal: signal);
    } catch (e) {
      print('Error calculating potential: $e');
      return null;
    }
  }
  
  // ===========================================
  // UTILITY
  // ===========================================
  
  /// Calculate required entry price for a goal
  double calculateRequiredEntry({
    required double predictedPrice,
    required double initialCapital,
    required double targetProfit,
  }) {
    return _investmentService.calculateRequiredEntryPrice(
      predictedPrice: predictedPrice,
      initialCapital: initialCapital,
      targetProfit: targetProfit,
    );
  }
  
  /// Clear all data
  Future<void> clearAll() async {
    _goals.clear();
    _alerts.clear();
    _patienceMeters.clear();
    _roadmaps.clear();
    _topPotentials.clear();
    await _saveGoals();
    notifyListeners();
  }
}
