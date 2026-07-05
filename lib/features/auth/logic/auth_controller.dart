import 'package:flutter/material.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/preference_service.dart';

class AuthController extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> signInWithGoogle(
    Function() onSuccess,
    Function(String) onError,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseService().signInWithGoogle();
      if (response != null) {
        await checkUserSetup(onSuccess);
      }
    } catch (e) {
      onError('Gagal masuk dengan Google: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmail(
    String email,
    String password,
    Function() onSuccess,
    Function(String) onError,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseService().signInWithEmail(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await checkUserSetup(onSuccess);
      } else {
        onError('Email atau password salah. Silakan coba lagi.');
      }
    } catch (e) {
      final msg = _friendlyAuthError(e.toString());
      onError(msg);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    String fullName,
    Function() onSuccess,
    Function(String) onError,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseService().signUpWithEmail(
        email: email,
        password: password,
        name: fullName,
      );

      if (response.user != null) {
        // User created. If email confirmation is required, user.identities will be empty.
        final needsConfirmation = response.user!.identities?.isEmpty ?? false;
        if (needsConfirmation) {
          // Account already exists but unconfirmed — treat as duplicate
          onError(
            'Email sudah terdaftar. Silakan login atau cek email kamu untuk konfirmasi.',
          );
        } else {
          onSuccess();
        }
      } else {
        onError('Pendaftaran gagal. Silakan coba lagi.');
      }
    } catch (e) {
      final msg = _friendlyAuthError(e.toString());
      onError(msg);
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
        await prefs.setContactSetup(true);
        await prefs.setCalibrated(true);
      }
      navigate();
    } catch (e) {
      debugPrint('checkUserSetup Error: $e');
      navigate();
    }
  }

  Future<void> resetPassword(
    String email,
    Function() onSuccess,
    Function(String) onError,
  ) async {
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      onSuccess();
    } catch (e) {
      onError('Gagal mengirim: $e');
    }
  }

  /// Converts raw Supabase/GoTrue error strings to user-friendly Indonesian messages.
  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password') ||
        lower.contains('wrong password')) {
      return 'Email atau password salah. Silakan coba lagi.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox kamu dan klik link verifikasi.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return 'Email sudah terdaftar. Silakan login.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Tidak ada koneksi internet. Cek jaringan kamu.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
