import 'package:flutter/material.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/preference_service.dart';

class AuthController extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> signInWithGoogle(Function() onSuccess, Function(String) onError) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseService().signInWithGoogle();
      if (response != null) {
        await checkUserSetup(onSuccess);
      }
    } catch (e) {
      onError('Failed to sign in with Google: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> checkUserSetup(Function() navigate) async {
    try {
      final prefs = PreferenceService();
      final contacts = await SupabaseService().getEmergencyContacts();
      if (contacts.isNotEmpty) {
        // If they already have contacts saved, it means they are an existing user
        await prefs.setContactSetup(true);
        await prefs.setCalibrated(true);
      }
      navigate();
    } catch (e) {
      debugPrint('checkUserSetup Error: $e');
      navigate(); // Proceed anyway, it will be handled by the navigator
    }
  }

  Future<void> resetPassword(String email, Function() onSuccess, Function(String) onError) async {
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      onSuccess();
    } catch (e) {
      onError('Gagal mengirim: $e');
    }
  }
}
