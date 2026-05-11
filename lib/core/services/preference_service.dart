import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static final PreferenceService _instance = PreferenceService._internal();
  factory PreferenceService() => _instance;
  PreferenceService._internal();

  static const String _keyIsFirstTime = 'is_first_time';
  static const String _keyIsContactSetup = 'is_contact_setup';
  static const String _keyIsPermissionsGranted = 'is_permissions_granted';
  static const String _keyIsCalibrated = 'is_calibrated';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // First Time / Onboarding
  bool get isFirstTime => _prefs.getBool(_keyIsFirstTime) ?? true;
  Future<void> setFirstTime(bool value) =>
      _prefs.setBool(_keyIsFirstTime, value);

  // Emergency Contact Setup
  bool get isContactSetup => _prefs.getBool(_keyIsContactSetup) ?? false;
  Future<void> setContactSetup(bool value) =>
      _prefs.setBool(_keyIsContactSetup, value);

  // Permissions
  bool get isPermissionsGranted =>
      _prefs.getBool(_keyIsPermissionsGranted) ?? false;
  Future<void> setPermissionsGranted(bool value) =>
      _prefs.setBool(_keyIsPermissionsGranted, value);

  // Calibration
  bool get isCalibrated => _prefs.getBool(_keyIsCalibrated) ?? false;
  Future<void> setCalibrated(bool value) =>
      _prefs.setBool(_keyIsCalibrated, value);

  // Reset all (for logout or testing)
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
