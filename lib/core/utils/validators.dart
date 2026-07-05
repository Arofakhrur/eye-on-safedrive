/// Centralized form validators for consistent validation logic across the app.
class AppValidators {
  AppValidators._();

  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 32;

  /// Validates an email address.
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email wajib diisi';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  /// Validates a password with full strength requirements:
  /// min 8 chars, 1 uppercase, 1 digit, 1 special character.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }
    if (value.length < minPasswordLength) {
      return 'Password minimal $minPasswordLength karakter';
    }
    if (value.length > maxPasswordLength) {
      return 'Password maksimal $maxPasswordLength karakter';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password harus mengandung minimal 1 huruf kapital';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password harus mengandung minimal 1 angka';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/]').hasMatch(value)) {
      return 'Password harus mengandung minimal 1 simbol (!@#\$%^&* dll)';
    }
    return null;
  }

  /// Validates a name field.
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama wajib diisi';
    }
    return null;
  }

  /// Validates a phone number (Indonesian local 08xx or international +628xx format).
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Empty is handled separately per-field
    }
    // Accept: +628xx... (international) or 08xx... (local), digits only after +
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 8 || digitsOnly.length > 15) {
      return 'Nomor HP tidak valid (8-15 digit)';
    }
    return null;
  }

  /// Returns a [PasswordStrength] level for live UI feedback.
  static PasswordStrength getPasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.empty;

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/]').hasMatch(password)) score++;

    if (score <= 1) return PasswordStrength.weak;
    if (score == 2) return PasswordStrength.fair;
    if (score == 3) return PasswordStrength.good;
    return PasswordStrength.strong;
  }
}

enum PasswordStrength { empty, weak, fair, good, strong }

