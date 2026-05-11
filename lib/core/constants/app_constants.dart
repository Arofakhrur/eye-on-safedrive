/// Named route constants used throughout the app.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String setup = '/setup';
  static const String permission = '/permission';
  static const String calibration = '/calibration';
  static const String home = '/home';
}

/// Asset path constants.
class AppAssets {
  AppAssets._();

  static const String logo = 'assets/images/EYE-ON!_Logo.webp';
  static const String iconApps = 'assets/images/icon-apps.webp';

  // Onboarding slides
  static const String onboardingSlide1 = 'assets/images/onboarding-slide1.webp';
  static const String onboardingSlide2 = 'assets/images/onboarding-slide2.webp';
  static const String onboardingSlide3 = 'assets/images/onboarding-slide3.webp';
  static const String onboardingSlide4 = 'assets/images/onboarding-slide4.webp';
  static const String onboardingSlide5 = 'assets/images/onboarding-slide5.webp';

  // Models directory (for future TFLite)
  static const String modelsDir = 'assets/models/';
}
