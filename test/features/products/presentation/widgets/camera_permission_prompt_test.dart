import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lpco_llc/features/products/presentation/widgets/camera_permission_prompt.dart';

void main() {
  testWidgets('permission button invokes its callback', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraPermissionPrompt(
            requesting: false,
            cameraStartFailed: false,
            onBack: () {},
            onManualSearch: () {},
            onRequestPermission: () => requests++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Allow Camera Permission'));
    expect(requests, 1);
  });

  testWidgets('permission button is disabled while requesting', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraPermissionPrompt(
            requesting: true,
            cameraStartFailed: false,
            onBack: () {},
            onManualSearch: () {},
            onRequestPermission: () => requests++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
    expect(requests, 0);
  });
}
