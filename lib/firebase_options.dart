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
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not configured');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows is not configured');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not configured');
      default:
        throw UnsupportedError('Unknown platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCb0Nt9CpM_BtgFfh9_rtAdWoVsYB_nO0Q',
    appId: '1:786358717490:web:20b8461f446c927e60802b',
    messagingSenderId: '786358717490',
    projectId: 'predictionapp-3c436',
    authDomain: 'predictionapp-3c436.firebaseapp.com',
    storageBucket: 'predictionapp-3c436.firebasestorage.app',
    measurementId: 'G-LFCYY7Y883',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVkfriIyYc__QIza9gECZtFZyATnZYtOw',
    appId: '1:786358717490:android:3ccc64440e012b1b60802b',
    messagingSenderId: '786358717490',
    projectId: 'predictionapp-3c436',
    storageBucket: 'predictionapp-3c436.firebasestorage.app',
  );
}
