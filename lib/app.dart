import 'package:flutter/material.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';

// Import Feature Views
import 'package:eyeon/features/splash/views/splash_screen.dart';
import 'package:eyeon/features/onboarding/views/onboarding_screen.dart';
import 'package:eyeon/features/auth/views/login_screen.dart';
import 'package:eyeon/features/auth/views/register_screen.dart';
import 'package:eyeon/features/setup/views/setup_emergency_contact_screen.dart';
import 'package:eyeon/features/setup/views/setup_wizard_screen.dart';
import 'package:eyeon/features/permission/views/permission_screen.dart';
import 'package:eyeon/features/calibration/views/calibration_screen.dart';
import 'package:eyeon/features/home/views/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EYE-ON!',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        useMaterial3: true,
        extensions: const [
          SkeletonizerConfigData(
            effect: SolidColorEffect(
              color: Color(0xFFE0E0E0),
            ),
            ignoreContainers: true,
          ),
        ],
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.setupWizard: (context) => const SetupWizardScreen(),
        AppRoutes.setup: (context) => const SetupEmergencyContactScreen(),
        AppRoutes.permission: (context) => const PermissionScreen(),
        AppRoutes.calibration: (context) => const CalibrationScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
      },
    );
  }
}
