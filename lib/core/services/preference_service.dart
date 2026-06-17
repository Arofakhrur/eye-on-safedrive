import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static final PreferenceService _instance = PreferenceService._internal();
  factory PreferenceService() => _instance;
  PreferenceService._internal();

  static const String _keyIsFirstTime = 'is_first_time';
  static const String _keyIsContactSetup = 'is_contact_setup';
  static const String _keyIsPermissionsGranted = 'is_permissions_granted';
  static const String _keyIsCalibrated = 'is_calibrated';

  static const String _keyEarThreshold = 'ear_threshold';
  static const String _keyShockSensitivity = 'shock_sensitivity';
  static const String _keyIsAlarmEnabled = 'is_alarm_enabled';
  static const String _keyAlarmSound = 'alarm_sound';
  static const String _keySaveToGallery = 'save_to_gallery';


  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // First Time / Onboarding
  bool get isFirstTime => _prefs.getBool(_keyIsFirstTime) ?? true;
  Future<void> setFirstTime(bool value) => _prefs.setBool(_keyIsFirstTime, value);

  // Emergency Contact Setup
  bool get isContactSetup => _prefs.getBool(_keyIsContactSetup) ?? false;
  Future<void> setContactSetup(bool value) => _prefs.setBool(_keyIsContactSetup, value);

  // Permissions
  bool get isPermissionsGranted => _prefs.getBool(_keyIsPermissionsGranted) ?? false;
  Future<void> setPermissionsGranted(bool value) => _prefs.setBool(_keyIsPermissionsGranted, value);

  // Calibration
  bool get isCalibrated => _prefs.getBool(_keyIsCalibrated) ?? false;
  Future<void> setCalibrated(bool value) => _prefs.setBool(_keyIsCalibrated, value);

  // Sensitivity Settings
  double get earThreshold => _prefs.getDouble(_keyEarThreshold) ?? 0.25;
  Future<void> setEarThreshold(double value) => _prefs.setDouble(_keyEarThreshold, value);

  double get shockSensitivity => _prefs.getDouble(_keyShockSensitivity) ?? 5.0;
  Future<void> setShockSensitivity(double value) => _prefs.setDouble(_keyShockSensitivity, value);

  // Alarm Settings
  bool get isAlarmEnabled => _prefs.getBool(_keyIsAlarmEnabled) ?? true;
  Future<void> setAlarmEnabled(bool value) => _prefs.setBool(_keyIsAlarmEnabled, value);

  String get alarmSound => _prefs.getString(_keyAlarmSound) ?? 'Sound 1';
  Future<void> setAlarmSound(String value) => _prefs.setString(_keyAlarmSound, value);

  // Data Storage
  bool get saveToGallery => _prefs.getBool(_keySaveToGallery) ?? false;
  Future<void> setSaveToGallery(bool value) => _prefs.setBool(_keySaveToGallery, value);

  // Removed Telegram Chat IDs logic since it's merged with Supabase Contacts

  // Reset all (for logout or testing)
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
