import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';

class SplashController extends ChangeNotifier {
  Future<void> handleNavigation(BuildContext context) async {
    await Future.delayed(AppDurations.splashDelay);
    if (!context.mounted) return;

    final prefs = PreferenceService();
    final user = Supabase.instance.client.auth.currentUser;

    // 1. Onboarding
    if (prefs.isFirstTime) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      return;
    }

    // 2. Permissions
    if (!prefs.isPermissionsGranted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.permission);
      return;
    }

    // 3. Auth
    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    // 4. Smart Data Check: If logged in, check if setup was already done in Supabase
    if (!prefs.isContactSetup) {
      try {
        final contacts = await SupabaseService().getEmergencyContacts();
        if (contacts.isNotEmpty) {
          await prefs.setContactSetup(true);
          await prefs.setCalibrated(true);
        }
      } catch (e) {
        debugPrint('Error checking existing contacts: $e');
      }
    }

    if (!context.mounted) return;

    // 5. Emergency Contact
    if (!prefs.isContactSetup) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.setupWizard);
      return;
    }

    // 6. Calibration
    if (!prefs.isCalibrated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.calibration);
      return;
    }

    // 7. Home
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }
}
