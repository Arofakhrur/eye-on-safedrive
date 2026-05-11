import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _animController.forward();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

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
          // If they have contacts, we assume they might have calibrated too, 
          // but we'll only skip calibration if the flag is explicitly set or if we want to be generous.
          // For now, let's just skip setup.
        }
      } catch (e) {
        debugPrint('Error checking existing contacts: $e');
      }
    }

    // 5. Emergency Contact
    if (!prefs.isContactSetup) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.setup);
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

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD7F454),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Logo Image
                Image.asset(
                  'assets/images/EYE-ON!_Logo.webp',
                  width: 150,
                  height: 150,
                ),

                const SizedBox(height: 24),

                // App Name Text
                const Text(
                  'EYE-ON!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 1.2,
                  ),
                ),

                const Spacer(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
