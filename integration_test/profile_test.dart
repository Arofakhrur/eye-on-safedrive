import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eyeon/main.dart' as app;

void profileTest() {
  testWidgets('Simulate profile and settings interaction', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Navigate to Profile Screen via Bottom Nav Bar
    final profileTab = find.text('Profile');
    if (profileTab.evaluate().isNotEmpty) {
      await tester.tap(profileTab);
      await tester.pumpAndSettle();
    }

    // 2. Edit Personal Information
    final editButton = find.text('Edit');
    if (editButton.evaluate().isNotEmpty) {
      // It might find multiple 'Edit' texts if there are multiple sections, so we pick the first
      await tester.tap(editButton.first);
      await tester.pumpAndSettle();

      // Find text fields by hint text or text type
      final nameField = find.byWidgetPredicate((widget) => 
        widget is TextField && widget.decoration?.hintText == 'Masukkan nama lengkap...'
      );
      if (nameField.evaluate().isNotEmpty) {
        await tester.enterText(nameField, 'Rider Baru Test');
      }

      // Save changes
      final saveButton = find.text('Simpan Perubahan');
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
      }
    }

    // 3. Toggle settings (Simpan Salinan ke Galeri)
    final saveToGallerySwitch = find.byType(Switch).last;
    if (saveToGallerySwitch.evaluate().isNotEmpty) {
      await tester.tap(saveToGallerySwitch);
      await tester.pumpAndSettle();
    }

    // 4. Sync Data
    final syncButton = find.text('Sinkronisasi Data');
    if (syncButton.evaluate().isNotEmpty) {
      await tester.tap(syncButton);
      await tester.pumpAndSettle(); // Wait for snackbar
    }

    // Navigate back to Home for the next test
    final homeTab = find.text('Home');
    if (homeTab.evaluate().isNotEmpty) {
      await tester.tap(homeTab);
      await tester.pumpAndSettle();
    }
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  profileTest();
}
