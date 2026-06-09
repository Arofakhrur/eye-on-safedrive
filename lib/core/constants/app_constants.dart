/// Named route constants used throughout the app.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String setup = '/setup';
  static const String setupWizard = '/setup-wizard';
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

  // Alarm sounds
  static const String alarmSound1 = 'sounds/sound 1.mp3';
  static const String alarmSound2 = 'sounds/sound 2.mp3';
  static const String alarmSound3 = 'sounds/sound 3.mp3';
  static const String alarmSound4 = 'sounds/sound 4.mp3';

  /// Maps display name → asset path for alarm sounds.
  static const Map<String, String> alarmSoundFiles = {
    'Sound 1': alarmSound1,
    'Sound 2': alarmSound2,
    'Sound 3': alarmSound3,
    'Sound 4': alarmSound4,
  };
}

/// URL and Endpoint constants used across the app.
class AppUrls {
  AppUrls._();

  // Nominatim Geocoding API
  static const String nominatimSearch =
      'https://nominatim.openstreetmap.org/search';

  /// Build a full Nominatim search URL with the given query.
  static String nominatimSearchUrl(String query) =>
      '$nominatimSearch?q=$query&format=json&addressdetails=1&limit=5&countrycodes=id';

  // OpenStreetMap Tile Server
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Telegram Bot
  static const String telegramBotUsername = 'EyeonEmergency_bot';
  static const String telegramBotDeepLink =
      'tg://resolve?domain=$telegramBotUsername&start=start';
  static const String telegramBotHttpsUrl =
      'https://t.me/$telegramBotUsername';
}
