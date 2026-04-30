// File generated manually for build-time wiring.
// Replace these placeholders by running:
// flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static bool get isConfigured {
    final options = currentPlatform;
    return !_isPlaceholder(options.apiKey) &&
        !_isPlaceholder(options.projectId) &&
        options.messagingSenderId != '000000000000' &&
        !options.appId.contains(':000000000000:');
  }

  static bool _isPlaceholder(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.isEmpty || normalized.startsWith('REPLACE_WITH_');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'REPLACE_WITH_PROJECT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGK2FbQrQ94orzJZgsoNq2rhvICmaEWv4',
    appId: '1:434792367249:android:00a1c8b24f31b594a16b30',
    messagingSenderId: '434792367249',
    projectId: 'lpco-llc-730ab',
    storageBucket: 'lpco-llc-730ab.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    iosBundleId: 'com.lpco.store',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_MACOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    iosBundleId: 'com.lpco.store',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WINDOWS_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'REPLACE_WITH_PROJECT_ID',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_LINUX_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'REPLACE_WITH_PROJECT_ID',
  );
}
