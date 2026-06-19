import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eyeon/main.dart' as app;

void setupTest() {
  testWidgets('Simulate setup wizard', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Find "Masukkan nama pengguna..."
    final usernameField = find.text('Masukkan nama pengguna...');
    if (usernameField.evaluate().isNotEmpty) {
      await tester.enterText(usernameField, 'Test User');
    }

    // Find "Cari alamat dari OpenStreetMap..."
    final addressField = find.text('Cari alamat dari OpenStreetMap...');
    if (addressField.evaluate().isNotEmpty) {
      await tester.enterText(addressField, 'Jl. Sudirman No. 1, Jakarta');
    }

    // Press "Lanjutkan" to move to next page
    final nextButton = find.text('Lanjutkan');
    if (nextButton.evaluate().isNotEmpty) {
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }

    // Press "Selesaikan Setup" on final page
    final finishButton = find.text('Selesaikan Setup');
    if (finishButton.evaluate().isNotEmpty) {
      await tester.tap(finishButton);
      await tester.pumpAndSettle();
    }
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setupTest();
}
