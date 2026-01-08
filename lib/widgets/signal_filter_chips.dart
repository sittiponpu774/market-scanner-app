import 'package:flutter/material.dart';

class SignalFilterChips extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final int allCount;
  final int buyCount;
  final int sellCount;
  final int holdCount;

  const SignalFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.allCount,
    required this.buyCount,
    required this.sellCount,
    required this.holdCount,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _buildChip('ALL', allCount, Colors.grey),
          const SizedBox(width: 8),
          _buildChip('BUY', buyCount, Colors.green),
          const SizedBox(width: 8),
          _buildChip('SELL', sellCount, Colors.red),
          const SizedBox(width: 8),
          _buildChip('HOLD', holdCount, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int count, Color color) {
    final isSelected = selectedFilter == label;
    
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => onFilterChanged(label),
      backgroundColor: color.withAlpha(51),
      selectedColor: color,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : color,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
