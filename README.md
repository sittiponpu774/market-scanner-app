# Market Scanner Flutter App

แอป Flutter สำหรับดูสัญญาณการซื้อขาย Crypto และหุ้นไทย พร้อมระบบ Push Notification

## Features

- 📈 ดูสัญญาณ BUY/SELL สำหรับ Crypto และหุ้นไทย
- ⭐ ระบบ Favourites เพื่อติดตามเหรียญที่สนใจ
- 🔔 Push Notification เมื่อมีสัญญาณใหม่
- 📊 กราฟราคา Real-time จาก Binance
- 😱 Fear & Greed Index
- 🌙 Dark/Light theme

## Setup Instructions

### 1. Clone Repository

```bash
git clone https://github.com/sittiponpu774/market-scanner-flutter.git
cd market-scanner-flutter
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup (Required)

คุณต้องสร้าง Firebase project ของตัวเอง:

1. ไปที่ [Firebase Console](https://console.firebase.google.com/)
2. สร้าง Project ใหม่
3. เพิ่ม Android App:
   - Package name: `com.marketscanner.market_scanner_app` (หรือเปลี่ยนตามต้องการ)
   - ดาวน์โหลด `google-services.json` ไปวางที่ `android/app/`
4. เพิ่ม Web App:
   - Copy Firebase config

5. สร้างไฟล์ `lib/firebase_options.dart`:

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS is not configured');
      default:
        throw UnsupportedError('Unknown platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT.appspot.com',
    measurementId: 'YOUR_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT.appspot.com',
  );
}
```

### 4. Run the App

```bash
# Android
flutter run

# Web
flutter run -d chrome

# Build APK
flutter build apk --release

# Build Web
flutter build web --release
```

## Project Structure

```
lib/
├── main.dart              # Entry point
├── firebase_options.dart  # Firebase config (create this file)
├── models/                # Data models
├── providers/             # State management
├── screens/               # UI screens
├── services/              # API, FCM, WebSocket services
├── theme/                 # App theme
└── widgets/               # Reusable widgets
```

## API Endpoints

แอปดึงข้อมูลจาก:
- Signal API: GitHub Pages JSON files
- Binance WebSocket: Real-time price data
- Fear & Greed: alternative.me API

## Push Notifications

ระบบ notification ใช้ Firebase Cloud Messaging (FCM):
- Topic `signal_alerts` - รับทุกสัญญาณ
- Topic `signal_{SYMBOL}` - รับเฉพาะเหรียญที่ favourite

## License

MIT License
