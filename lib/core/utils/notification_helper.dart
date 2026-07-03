import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Enum yang mendefinisikan tipe notifikasi yang tersedia.
enum NotificationType { success, error, warning, info }

/// Helper terpusat untuk menampilkan notifikasi seragam di seluruh aplikasi.
///
/// Semua notifikasi menggunakan [showTop] agar selalu muncul di bagian
/// atas layar dengan tampilan yang konsisten.
class NotificationHelper {
  NotificationHelper._();

  // ── Konfigurasi warna & ikon berdasarkan tipe ──────────────────────

  static Color _backgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF1B5E20); // deep green
      case NotificationType.error:
        return const Color(0xFFB71C1C); // deep red
      case NotificationType.warning:
        return const Color(0xFFE65100); // deep orange
      case NotificationType.info:
        return const Color(0xFF0D47A1); // deep blue
    }
  }

  static Color _accentColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF69F0AE); // light green
      case NotificationType.error:
        return const Color(0xFFFF8A80); // light red
      case NotificationType.warning:
        return const Color(0xFFFFD180); // light orange
      case NotificationType.info:
        return const Color(0xFF82B1FF); // light blue
    }
  }

  static IconData _icon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.error:
        return Icons.error_rounded;
      case NotificationType.warning:
        return Icons.warning_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
    }
  }

  // ── Public API ─────────────────────────────────────────────────────

  /// Menampilkan SnackBar di bagian **atas** layar.
  ///
  /// Gunakan [type] untuk menentukan warna & ikon secara otomatis:
  /// - [NotificationType.success] → hijau, ikon centang
  /// - [NotificationType.error]   → merah, ikon error
  /// - [NotificationType.warning] → oranye, ikon peringatan
  /// - [NotificationType.info]    → biru, ikon informasi
  ///
  /// [duration] default 3 detik, dapat diubah sesuai kebutuhan.
  static void showTop(
    BuildContext context, {
    required String message,
    required NotificationType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    showTopWithMessenger(
      ScaffoldMessenger.of(context),
      screenHeight: screenHeight,
      message: message,
      type: type,
      duration: duration,
    );
  }

  /// Variasi [showTop] yang menerima [ScaffoldMessengerState] dan [screenHeight]
  /// yang sudah di-capture sebelum async gap, untuk menghindari lint
  /// `use_build_context_synchronously`.
  ///
  /// Contoh penggunaan:
  /// ```dart
  /// final messenger = ScaffoldMessenger.of(context);
  /// final height = MediaQuery.of(context).size.height;
  /// await someAsyncCall();
  /// NotificationHelper.showTopWithMessenger(messenger, screenHeight: height, ...);
  /// ```
  static void showTopWithMessenger(
    ScaffoldMessengerState messenger, {
    required double screenHeight,
    required String message,
    required NotificationType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final bg = _backgroundColor(type);
    final accent = _accentColor(type);
    final icon = _icon(type);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: accent.withValues(alpha: 0.4), width: 1),
          ),
          margin: EdgeInsets.only(
            bottom: screenHeight - 150,
            left: 24,
            right: 24,
          ),
        ),
      );
  }
}
