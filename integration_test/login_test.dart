import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eyeon/main.dart' as app;

void loginTest() {
  testWidgets('Simulate user login', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Find email and password fields
    final emailFields = find.byType(TextFormField);
    if (emailFields.evaluate().isNotEmpty) {
      await tester.enterText(emailFields.first, 'test@example.com');
      await tester.enterText(emailFields.last, 'password123');
      
      // Tap "Sign In" button
      final signInButton = find.text('Sign In');
      if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
      }
    }
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  loginTest();
}
