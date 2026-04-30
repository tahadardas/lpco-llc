import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lpco_llc/core/theme/app_theme.dart';

void main() {
  testWidgets('Smoke: app theme renders main scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: Text('LPCO LLC'))),
        ),
      ),
    );

    expect(find.text('LPCO LLC'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
