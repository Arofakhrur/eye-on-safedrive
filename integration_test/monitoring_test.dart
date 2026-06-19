import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eyeon/main.dart' as app;

void monitoringTest() {
  testWidgets('Simulate core functionality and monitoring', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Firebase Test Lab automatically grants system permissions,
    // but if there is an in-app PermissionScreen with a continue button, we tap it.
    final izinkanButton = find.text('Izinkan');
    if (izinkanButton.evaluate().isNotEmpty) {
      await tester.tap(izinkanButton.first);
      await tester.pumpAndSettle();
    }
    final lanjutkanButton = find.text('Lanjutkan');
    if (lanjutkanButton.evaluate().isNotEmpty) {
      await tester.tap(lanjutkanButton.first);
      await tester.pumpAndSettle();
    }

    // Find "SWIPE UP TO START" and simulate drag up gesture
    final swipeButton = find.text('SWIPE UP TO START');
    if (swipeButton.evaluate().isNotEmpty) {
      await tester.drag(swipeButton, const Offset(0, -300));
      await tester.pumpAndSettle(); // Wait for camera and map animations
    }

    // Validate monitoring text indicators
    expect(find.text('EAR'), findsWidgets);
    expect(find.text('G-Force'), findsWidgets);
    expect(find.text('DRIVING'), findsWidgets);
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  monitoringTest();
}
