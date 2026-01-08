import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug Screen to view all data stored in SharedPreferences
/// Access from Settings -> Storage Debug
class StorageDebugScreen extends StatefulWidget {
  const StorageDebugScreen({super.key});

  @override
  State<StorageDebugScreen> createState() => _StorageDebugScreenState();
}

class _StorageDebugScreenState extends State<StorageDebugScreen> {
  Map<String, dynamic> _allData = {};
  bool _isLoading = true;
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final data = <String, dynamic>{};
      for (final key in keys) {
        final value = prefs.get(key);
        data[key] = value;
      }
      
      setState(() {
        _allData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  String _formatValue(dynamic value) {
    if (value is String) {
      try {
        // Try to parse as JSON for pretty formatting
        final decoded = json.decode(value);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (e) {
        return value;
      }
    }
    return value.toString();
  }

  int _getDataSize(dynamic value) {
    if (value is String) {
      return value.length;
    }
    return value.toString().length;
  }

  Future<void> _deleteKey(String key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ "$key" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      _loadAllData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบ "$key" เรียบร้อย')),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ลบข้อมูลทั้งหมด'),
        content: const Text(
          'การกระทำนี้จะลบข้อมูลทั้งหมดใน SharedPreferences!\n\n'
          'รวมถึง:\n'
          '• เป้าหมายการลงทุน\n'
          '• การแจ้งเตือน\n'
          '• รายการโปรด\n'
          '• การตั้งค่า\n\n'
          'ต้องการดำเนินการต่อหรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบทั้งหมด'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _loadAllData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบข้อมูลทั้งหมดเรียบร้อย'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกแล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Storage Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _clearAll,
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allData.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'ไม่มีข้อมูลใน SharedPreferences',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.withAlpha(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SharedPreferences Summary',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('Total Keys: ${_allData.length}'),
                          Text(
                            'Total Size: ${_allData.values.fold<int>(0, (sum, v) => sum + _getDataSize(v))} bytes',
                          ),
                        ],
                      ),
                    ),
                    
                    // Keys List
                    Expanded(
                      child: ListView.builder(
                        itemCount: _allData.length,
                        itemBuilder: (context, index) {
                          final key = _allData.keys.elementAt(index);
                          final value = _allData[key];
                          final isSelected = _selectedKey == key;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Key Header
                                ListTile(
                                  leading: _getIconForKey(key),
                                  title: Text(
                                    key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_getDataSize(value)} bytes • ${value.runtimeType}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 20),
                                        onPressed: () => _copyToClipboard(
                                          _formatValue(value),
                                        ),
                                        tooltip: 'Copy',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _deleteKey(key),
                                        tooltip: 'Delete',
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedKey = isSelected ? null : key;
                                    });
                                  },
                                ),
                                
                                // Value Content (Expandable)
                                if (isSelected)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      _formatValue(value),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _getIconForKey(String key) {
    if (key.contains('goal')) {
      return const CircleAvatar(
        backgroundColor: Colors.green,
        child: Icon(Icons.flag, color: Colors.white, size: 20),
      );
    } else if (key.contains('alert')) {
      return const CircleAvatar(
        backgroundColor: Colors.orange,
        child: Icon(Icons.notifications, color: Colors.white, size: 20),
      );
    } else if (key.contains('favourite')) {
      return const CircleAvatar(
        backgroundColor: Colors.red,
        child: Icon(Icons.favorite, color: Colors.white, size: 20),
      );
    } else if (key.contains('setting') || key.contains('theme')) {
      return const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(Icons.settings, color: Colors.white, size: 20),
      );
    }
    return const CircleAvatar(
      backgroundColor: Colors.grey,
      child: Icon(Icons.data_object, color: Colors.white, size: 20),
    );
  }
}
