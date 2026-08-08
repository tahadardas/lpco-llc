import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/firebase_options.dart';

void main() {
  test('iOS Firebase configuration matches the LPCO Apple app', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(DefaultFirebaseOptions.isConfigured, isTrue);

    final options = DefaultFirebaseOptions.currentPlatform;
    expect(options.projectId, 'lpco-llc-730ab');
    expect(options.messagingSenderId, '434792367249');
    expect(options.appId, '1:434792367249:ios:bc9a44f404c82902a16b30');
    expect(options.iosBundleId, 'com.lpco.store');
  });
}
