import 'package:flutter/foundation.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';

class ProfileController extends ChangeNotifier {
  // Personal Info
  String _userName = 'Rider';
  String? _avatarUrl;
  String _email = 'rider@eyeon.app';
  String _address = 'Not set';
  String _bloodType = 'Not set';
  String _origin = 'Not set';
  String _medicalNotes = '';

  String get userName => _userName;
  String? get avatarUrl => _avatarUrl;
  String get email => _email;
  String get address => _address;
  String get bloodType => _bloodType;
  String get origin => _origin;
  String get medicalNotes => _medicalNotes;

  // Preferences
  double _earThreshold = PreferenceService().earThreshold;
  double _shockSensitivity = PreferenceService().shockSensitivity;
  String _alarmSound = PreferenceService().alarmSound;
  bool _saveToGallery = PreferenceService().saveToGallery;
  bool _showFaceMesh = PreferenceService().showFaceMesh;

  double get earThreshold => _earThreshold;
  double get shockSensitivity => _shockSensitivity;
  String get alarmSound => _alarmSound;
  bool get saveToGallery => _saveToGallery;
  bool get showFaceMesh => _showFaceMesh;

  ProfileController() {
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    final user = SupabaseService().currentUser;
    if (user != null) {
      _email = user.email ?? 'rider@eyeon.app';
      if (user.userMetadata != null) {
        _userName = user.userMetadata!['full_name'] ??
            user.userMetadata!['name'] ??
            'Rider';
        _avatarUrl = (user.userMetadata!['avatar_url'] ??
                user.userMetadata!['picture'])
            ?.toString()
            .replaceFirst('http://', 'https://');
      }

      // Load from profiles table
      final profile = await SupabaseService().getProfile();
      if (profile != null) {
        // Restore ear_threshold if available
        if (profile['ear_threshold'] != null) {
          final cloudThreshold = (profile['ear_threshold'] as num).toDouble();
          await PreferenceService().setEarThreshold(cloudThreshold);
          _earThreshold = cloudThreshold;
        }

        // Restore preferences if available
        if (profile['shock_sensitivity'] != null) {
          final val = (profile['shock_sensitivity'] as num).toDouble();
          await PreferenceService().setShockSensitivity(val);
          _shockSensitivity = val;
        }
        if (profile['alarm_sound'] != null) {
          final val = profile['alarm_sound'] as String;
          await PreferenceService().setAlarmSound(val);
          _alarmSound = val;
        }
        if (profile['save_to_gallery'] != null) {
          final val = profile['save_to_gallery'] as bool;
          await PreferenceService().setSaveToGallery(val);
          _saveToGallery = val;
        }

        if (profile['full_name'] != null) _userName = profile['full_name'];
        _address = profile['address'] ?? 'Not set';
        _bloodType = profile['blood_type'] ?? 'Not set';
        _origin = profile['origin'] ?? 'Not set';
        _medicalNotes = profile['emergency_medical_notes'] ?? '';
      }
      
      notifyListeners();
    }
  }

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  Future<void> updatePersonalInfo({
    required String name,
    required String address,
    required String bloodType,
    required String origin,
    required String medicalNotes,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      // Save to profiles table — error is rethrown by SupabaseService
      await SupabaseService().updateProfile({
        'full_name': name,
        'address': address,
        'blood_type': bloodType,
        'origin': origin,
        'emergency_medical_notes': medicalNotes,
      });

      // Also update auth metadata (best-effort, do not block if this fails)
      try {
        await SupabaseService().updateUserMetadata({
          'full_name': name,
          'address': address,
          'blood_type': bloodType,
          'origin': origin,
        });
      } catch (e) {
        debugPrint('Auth metadata update failed (non-critical): $e');
      }

      _userName = name;
      _address = address;
      _bloodType = bloodType;
      _origin = origin;
      _medicalNotes = medicalNotes;
      notifyListeners();

      await loadUserProfile();
    } catch (e) {
      debugPrint('updatePersonalInfo error: $e');
      rethrow; // let UI show a Snackbar
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateDetectionSettings({
    required double shockSensitivity,
    required String alarmSound,
    required bool saveToGallery,
  }) async {
    await PreferenceService().setShockSensitivity(shockSensitivity);
    await PreferenceService().setAlarmSound(alarmSound);
    await PreferenceService().setSaveToGallery(saveToGallery);

    try {
      await SupabaseService().updateProfile({
        'shock_sensitivity': shockSensitivity,
        'alarm_sound': alarmSound,
        'save_to_gallery': saveToGallery,
      });
    } catch (e) {
      debugPrint('Failed to sync settings to cloud: $e');
    }

    _shockSensitivity = shockSensitivity;
    _alarmSound = alarmSound;
    _saveToGallery = saveToGallery;
    notifyListeners();
  }

  Future<void> updateShowFaceMesh(bool value) async {
    await PreferenceService().setShowFaceMesh(value);
    _showFaceMesh = value;
    notifyListeners();
  }

  Future<int> syncOfflineData() async {
    return await SupabaseService().syncOfflineData();
  }

  Future<void> signOut() async {
    await SupabaseService().signOut();
  }
}
