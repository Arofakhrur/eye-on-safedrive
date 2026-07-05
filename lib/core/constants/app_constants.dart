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

  /// Maps display name → audioplayers asset path for alarm playback.
  static const Map<String, String> alarmAudioFiles = {
    'Sound 1': 'audio/sound1.mp3',
    'Sound 2': 'audio/sound2.mp3',
    'Sound 3': 'audio/sound3.mp3',
    'Sound 4': 'audio/sound4.mp3',
  };
}

/// URL and Endpoint constants used across the app.
class AppUrls {
  AppUrls._();

  // Nominatim Geocoding API
  static const String nominatimBase =
      'https://nominatim.openstreetmap.org';

  static const String nominatimSearch = '$nominatimBase/search';

  /// Build a full Nominatim search URL with the given query.
  static String nominatimSearchUrl(String query) =>
      '$nominatimSearch?q=$query&format=json&addressdetails=1&limit=5&countrycodes=id';

  /// Build a Nominatim reverse geocode URL for given coordinates.
  static String nominatimReverseUrl(double lat, double lng) =>
      '$nominatimBase/reverse?lat=$lat&lon=$lng&format=json';

  // OpenStreetMap Tile Server
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Telegram Bot
  static const String telegramBotUsername = 'EyeonEmergency_bot';
  static const String telegramBotDeepLink =
      'tg://resolve?domain=$telegramBotUsername&start=start';
  static const String telegramBotHttpsUrl =
      'https://t.me/$telegramBotUsername';

  // Google Maps
  static const String googleMapsSearch =
      'https://www.google.com/maps/search/?api=1';

  /// Google Maps query URL for a lat/lng pair.
  static String googleMapsQueryUrl(double lat, double lng) =>
      '$googleMapsSearch&query=$lat,$lng';

  /// WhatsApp deep-link URL for a given E.164 phone number (digits only).
  static String whatsAppUrl(String cleanPhone) =>
      'https://wa.me/$cleanPhone';

  /// Pesan undangan Telegram yang dikirim ke kontak darurat.
  static const String telegramInviteMessage =
      'Halo! Saya menggunakan aplikasi keselamatan berkendara EYE-ON! '
      'dan menjadikanmu sebagai kontak darurat saya. '
      'Tolong klik link ini: $telegramBotHttpsUrl lalu tekan tombol START. '
      'Setelah itu, tolong kirimkan angka Chat ID balasan dari bot tersebut ke saya ya! '
      'Terima kasih.';

  /// User-Agent header for HTTP requests.
  static const String userAgent = 'EyeOnSafeDrive/1.0';
}

/// Global app limits and constraints.
class AppLimits {
  AppLimits._();

  /// Maximum number of emergency contacts a user can have.
  static const int maxEmergencyContacts = 3;
}

/// Detection algorithm parameters.
class DetectionConfig {
  DetectionConfig._();

  // ── Microsleep Detection ──

  /// Default EAR threshold (overridden by personal calibration).
  static const double defaultEarThreshold = 0.25;

  /// Default shock sensitivity (m/s²).
  static const double defaultShockSensitivity = 30.0;

  /// Consecutive drowsy frames before alarm triggers (~1.5s at ~20fps).
  static const int drowsyFrameThreshold = 30;

  /// Cooldown after resume (seconds) to prevent alarm spam.
  static const int resumeCooldownSeconds = 10;

  /// EAR Low-Pass Filter: weight of current frame.
  static const double earLpfAlpha = 0.4;

  /// EAR Low-Pass Filter: weight of previous frame.
  static const double earLpfBeta = 0.6;

  /// Microsleep Level 1 alarm volume.
  static const double alarmVolumeLevel1 = 0.7;

  /// Microsleep Level 2+ alarm volume (max).
  static const double alarmVolumeMax = 1.0;

  // ── Accident Detection ──

  /// Low-Pass Filter alpha for accelerometer readings.
  static const double accelLpfAlpha = 0.5;

  /// Speed-Gate verification duration (seconds).
  static const int speedGateSeconds = 4;

  /// Speed threshold (km/h) to distinguish real crash vs road bump.
  static const double speedGateThresholdKmH = 2.0;

  /// Tilt threshold (degrees) to bypass Speed-Gate when motorcycle falls over.
  static const double tiltThresholdDegrees = 60.0;

  /// Minimum total gravity magnitude to avoid divide-by-zero.
  static const double minGravityMagnitude = 0.1;

  // ── Calibration ──

  /// Target EAR samples for calibration (~5s at ~20fps).
  static const int calibrationTargetSamples = 100;

  /// Frames without a face before showing warning.
  static const int noFaceTimeoutFrames = 60;

  /// Multiplier applied to baseline average → personal threshold (75%).
  static const double earThresholdMultiplier = 0.75;

  /// Lower clamp for calibrated EAR threshold.
  static const double earThresholdMin = 0.12;

  /// Upper clamp for calibrated EAR threshold.
  static const double earThresholdMax = 0.35;

  /// Minimum acceptable EAR sample value.
  static const double earSampleMin = 0.05;

  /// Maximum acceptable EAR sample value.
  static const double earSampleMax = 0.6;

  // ── Level 3 Lock ──

  /// Default lockdown duration (seconds) when Level 3 is triggered.
  static const int level3LockdownSeconds = 120;

  /// Speed below which Level 3 lock can be dismissed (km/h).
  static const double level3UnlockSpeedKmH = 1.0;
}

/// Timing and duration constants used across the app.
class AppDurations {
  AppDurations._();

  static const Duration splashDelay = Duration(seconds: 2);
  static const Duration noFaceWarning = Duration(seconds: 3);
  static const Duration locationTimeout = Duration(seconds: 5);
  static const Duration nominatimTimeout = Duration(seconds: 5);
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const Duration reverseGeocodeTimeout = Duration(seconds: 5);
}

/// GPS and location tracking constants.
class LocationConfig {
  LocationConfig._();

  /// Minimum distance change (in meters) before GPS stream fires.
  static const int distanceFilterMeters = 5;
}

/// Supabase table names and storage buckets.
class SupabaseConfig {
  SupabaseConfig._();

  static const String tableEmergencyContacts = 'emergency_contacts';
  static const String tableIncidentLogs = 'incident_logs';
  static const String tableRideLogs = 'ride_logs';
  static const String tableProfiles = 'profiles';
  static const String tableEvaluationMetrics = 'evaluation_metrics';
  static const String bucketIncidentVideos = 'incident_videos';
  static const String offlineDbName = 'eyeon_offline.db';
  static const String edgeFunctionTelegramSOS = 'send-telegram-sos';
}

/// National emergency and SOS constants.
class EmergencyConfig {
  EmergencyConfig._();

  static const String nationalEmergencyNumber = '112';
  static const String whatsAppBaseUrl = 'https://wa.me/';
  static const String indonesianCountryCode = '62';
  static const String fallbackRiderName = 'Pengendara';
}
