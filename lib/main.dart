import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'firebase_options.dart';

/// Convert NotificationMode to LocalNotificationMode
LocalNotificationMode _toLocalNotificationMode(NotificationMode mode) {
  switch (mode) {
    case NotificationMode.all:
      return LocalNotificationMode.all;
    case NotificationMode.favourites:
      return LocalNotificationMode.favourites;
    case NotificationMode.off:
      return LocalNotificationMode.off;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 App starting...');
  
  // Initialize Firebase FIRST (required for background handler)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized in main()');
      
      // Register background message handler BEFORE any other FCM operations
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      print('✅ Background handler registered');
    } catch (e) {
      print('⚠️ Firebase init in main failed: $e');
    }
  }
  
  // Initialize FCM service (Firebase Cloud Messaging) for push notifications
  try {
    print('📱 Initializing FCM...');
    await FcmService().initialize();
    // Topic subscription is now inside initialize()
    print('✅ FCM initialized successfully');
  } catch (e, stackTrace) {
    print('⚠️ FCM initialization failed: $e');
    print('📍 Stack: $stackTrace');
    // Continue without FCM - app will still work
  }
  
  // Initialize local notification service (for foreground notifications)
  try {
    await NotificationService().initialize();
  } catch (e) {
    print('⚠️ NotificationService failed: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SignalProvider()..initNotifications()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => FavouriteProvider()),
        ChangeNotifierProvider(create: (_) => InvestmentProvider()..loadGoals()),
        ChangeNotifierProvider(create: (_) => BinanceProvider()..initialize()),
      ],
      child: Consumer3<SettingsProvider, SignalProvider, FavouriteProvider>(
        builder: (context, settings, signalProvider, favouriteProvider, _) {
          // Sync notification mode and favourites to SignalProvider (for local notifications)
          final localMode = _toLocalNotificationMode(settings.notificationMode);
          signalProvider.setNotificationMode(localMode);
          signalProvider.updateNotificationFavourites(favouriteProvider.favouriteSymbols);
          
          // Sync FCM notification mode and favourites (for push notifications on Android)
          if (!kIsWeb) {
            FcmService().setNotificationMode(
              settings.notificationMode,
              onFavouritesModeChanged: (enabled) {
                // Update FavouriteProvider when mode changes
                favouriteProvider.setFavouritesMode(enabled);
              },
            );
            FcmService().updateFavourites(favouriteProvider.favouriteSymbols);
          }
          
          return MaterialApp(
            title: 'Market Scanner',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            routes: {
              '/': (context) => const DashboardScreen(),
              '/signal-detail': (context) => const SignalDetailScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/potential-scanner': (context) => const PotentialScannerScreen(),
            },
          );
        },
      ),
    );
  }
}
