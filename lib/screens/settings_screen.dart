import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/providers.dart';
import '../services/web_notification.dart';
import '../services/fcm_service.dart';
import '../models/signal.dart';
import 'storage_debug_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiUrlController;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _apiUrlController = TextEditingController(text: settings.apiUrl);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // API Configuration
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'API Configuration',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _apiUrlController,
                        decoration: InputDecoration(
                          labelText: 'API URL',
                          hintText: 'http://localhost:8000',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: () => _saveApiUrl(settings),
                          ),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            settings.isConnected 
                                ? Icons.check_circle 
                                : Icons.error,
                            color: settings.isConnected 
                                ? Colors.green 
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            settings.isConnected 
                                ? 'Connected' 
                                : 'Disconnected',
                            style: TextStyle(
                              color: settings.isConnected 
                                  ? Colors.green 
                                  : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _isTestingConnection 
                                ? null 
                                : () => _testConnection(settings),
                            child: _isTestingConnection
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Test Connection'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Push Notifications Info (FCM)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active, size: 24, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'Push Notifications',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🔔 การแจ้งเตือนส่งผ่าน Firebase Cloud Messaging (FCM)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.cloud_done, color: Colors.green),
                        title: const Text('Backend Server'),
                        subtitle: const Text('แจ้งเตือนเมื่อสัญญาณเปลี่ยนแม้ปิดแอพ'),
                      ),
                      const Divider(),
                      // FCM Status display (token hidden for security)
                      FutureBuilder<Map<String, String>>(
                        future: _getFcmDebugInfo(),
                        builder: (context, snapshot) {
                          final info = snapshot.data ?? {'token': 'Loading...', 'error': ''};
                          final token = info['token'] ?? 'No token';
                          final error = info['error'] ?? '';
                          final hasToken = token != 'No token' && token != 'Loading...';
                          return Column(
                            children: [
                              ListTile(
                                leading: Icon(
                                  hasToken ? Icons.check_circle : Icons.error,
                                  color: hasToken ? Colors.green : Colors.red,
                                ),
                                title: const Text('Push Notification'),
                                subtitle: Text(
                                  hasToken ? 'พร้อมรับการแจ้งเตือน ✓' : (token == 'Loading...' ? 'กำลังโหลด...' : 'ไม่พร้อม'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasToken ? Colors.green : Colors.red,
                                  ),
                                ),
                                trailing: hasToken ? null : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    setState(() {}); // Refresh
                                  },
                                ),
                              ),
                              if (error.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'Error: $error',
                                    style: const TextStyle(color: Colors.red, fontSize: 11),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      // Web Notification Test Button
                      if (kIsWeb) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.notifications_active, color: Colors.orange),
                          title: const Text('Browser Notification'),
                          subtitle: const Text('ทดสอบแจ้งเตือนบน Web'),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              final webNotif = WebNotificationService();
                              final granted = await webNotif.requestPermission();
                              if (granted) {
                                webNotif.showSignalNotification(Signal(
                                  symbol: 'TEST/USDT',
                                  price: 100.0,
                                  changePercent: 5.0,
                                  signalType: 'BUY',
                                  confidence: 0.85,
                                  rsi: 35.0,
                                  macd: 0.5,
                                  macdSignal: 0.3,
                                  volume: 1000000.0,
                                  marketType: 'crypto',
                                  timestamp: DateTime.now(),
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ ส่งแจ้งเตือนทดสอบแล้ว!')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('❌ ไม่ได้รับอนุญาตแจ้งเตือน')),
                                );
                              }
                            },
                            child: const Text('ทดสอบ'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // App Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'App Settings',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Enable dark theme'),
                        value: settings.isDarkMode,
                        onChanged: (value) => settings.setDarkMode(value),
                        secondary: Icon(
                          settings.isDarkMode 
                              ? Icons.dark_mode 
                              : Icons.light_mode,
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          settings.notificationMode == NotificationMode.off
                              ? Icons.notifications_off
                              : Icons.notifications_active,
                          color: settings.notificationMode == NotificationMode.off
                              ? Colors.grey
                              : Colors.green,
                        ),
                        title: const Text('การแจ้งเตือน'),
                        subtitle: Text(_getNotificationModeText(settings.notificationMode)),
                        trailing: DropdownButton<NotificationMode>(
                          value: settings.notificationMode,
                          underline: const SizedBox(),
                          items: NotificationMode.values.map((mode) {
                            return DropdownMenuItem<NotificationMode>(
                              value: mode,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getNotificationModeIcon(mode),
                                    size: 18,
                                    color: _getNotificationModeColor(mode),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_getNotificationModeLabel(mode)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              await settings.setNotificationMode(value);
                              // Sync with SignalProvider
                              context.read<SignalProvider>().setNotificationsEnabled(value != NotificationMode.off);
                              // Sync with FCM Service (for Android push notifications)
                              if (!kIsWeb) {
                                await FcmService().setNotificationMode(value);
                                // Update favourites in FCM service
                                final favourites = context.read<FavouriteProvider>().favouriteSymbols;
                                FcmService().updateFavourites(favourites);
                              }
                            }
                          },
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.format_list_numbered),
                        title: const Text('จำนวนเหรียญ/หุ้นที่แสดง'),
                        subtitle: Text('แสดง ${settings.displayLimit} รายการ'),
                        trailing: DropdownButton<int>(
                          value: settings.displayLimit,
                          underline: const SizedBox(),
                          items: SettingsProvider.limitOptions.map((limit) {
                            return DropdownMenuItem<int>(
                              value: limit,
                              child: Text('$limit'),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              await settings.setDisplayLimit(value);
                              // Refresh signals with new limit
                              if (mounted) {
                                final signalProvider = context.read<SignalProvider>();
                                signalProvider.fetchCryptoSignals(limit: value);
                                signalProvider.fetchThaiStockSignals(limit: value);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('กำลังโหลด $value รายการ...')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // About
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'About',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const ListTile(
                        title: Text('Market Scanner'),
                        subtitle: Text('Version 1.0.0'),
                        leading: Icon(Icons.trending_up),
                      ),
                      const Divider(),
                      const ListTile(
                        title: Text('Crypto & Thai Stock Scanner'),
                        subtitle: Text('ML-powered market analysis'),
                        leading: Icon(Icons.analytics),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('📦 Storage Debug'),
                        subtitle: const Text('ดูข้อมูลที่บันทึกใน SharedPreferences'),
                        leading: const Icon(Icons.storage, color: Colors.orange),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StorageDebugScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveApiUrl(SettingsProvider settings) async {
    await settings.setApiUrl(_apiUrlController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL saved')),
      );
    }
  }

  Future<void> _testConnection(SettingsProvider settings) async {
    setState(() => _isTestingConnection = true);
    
    await settings.setApiUrl(_apiUrlController.text);
    
    setState(() => _isTestingConnection = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.isConnected 
                ? 'Connection successful!' 
                : 'Connection failed',
          ),
          backgroundColor: settings.isConnected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<Map<String, String>> _getFcmDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('fcm_token');
    final error = prefs.getString('fcm_error');
    return {
      'token': token ?? 'No token',
      'error': error ?? '',
    };
  }

  String _getNotificationModeText(NotificationMode mode) {
    switch (mode) {
      case NotificationMode.all:
        return 'แจ้งเตือนทุกเหรียญ/หุ้น';
      case NotificationMode.favourites:
        return 'แจ้งเตือนเฉพาะรายการโปรด';
      case NotificationMode.off:
        return 'ปิดการแจ้งเตือน';
    }
  }

  String _getNotificationModeLabel(NotificationMode mode) {
    switch (mode) {
      case NotificationMode.all:
        return 'ทั้งหมด';
      case NotificationMode.favourites:
        return 'รายการโปรด';
      case NotificationMode.off:
        return 'ปิด';
    }
  }

  IconData _getNotificationModeIcon(NotificationMode mode) {
    switch (mode) {
      case NotificationMode.all:
        return Icons.notifications_active;
      case NotificationMode.favourites:
        return Icons.favorite;
      case NotificationMode.off:
        return Icons.notifications_off;
    }
  }

  Color _getNotificationModeColor(NotificationMode mode) {
    switch (mode) {
      case NotificationMode.all:
        return Colors.green;
      case NotificationMode.favourites:
        return Colors.orange;
      case NotificationMode.off:
        return Colors.grey;
    }
  }
}
