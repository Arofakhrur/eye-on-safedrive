import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/telegram_service.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:gal/gal.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eyeon/core/constants/app_constants.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();

  factory SOSService() => _instance;

  SOSService._internal();

  /// Trigger the full SOS flow:
  /// 1. Get GPS location
  /// 2. Send SOS via Telegram Edge Function (text + location)
  /// 3. Process video evidence (CameraX rolling (5) )
  /// 4. kirim ke Telegram + Save video ke galeri (optional)
  /// 5. Log insidene langsung ke Supabase

  Future<Map<String, dynamic>> triggerEmergencySOS(
    double magnitude, {
    String? rideId,
    String? videoPath,
    int sensorDetectionMs = 0,
    int videoExtractionMs = 0,
  }) async {
    bool isTelegramSent = false;
    Map<String, dynamic>? telegramDetails;
    bool gallerySaved = false;
    String? galleryError;

    final stopwatch = Stopwatch()..start();
    int gallerySaveMs = 0;
    int telegramApiMs = 0;
    int startTelegramApiPart1 = 0;
    int startTelegramApiPart2 = 0;
    int telegramPart1Ms = 0;
    int telegramPart2Ms = 0;

    try {
      // 1. Get Location and Contacts (Part of Telegram API process)
      startTelegramApiPart1 = stopwatch.elapsedMilliseconds;
      final position = await LocationService.getCurrentLocation();
      if (position == null) throw Exception("Failed to get location");

      final lat = position.latitude;
      final lng = position.longitude;

      // 2. Get Contacts & Send Text/GPS via Edge Function (Instant)
      final contacts = await SupabaseService().getEmergencyContacts();
      final chatIds = contacts
          .where((c) => c.telegramChatId.isNotEmpty)
          .map((c) => c.telegramChatId)
          .toList();

      if (chatIds.isNotEmpty && TelegramService().isConfigured) {
        final user = SupabaseService().currentUser;
        final name =
            user?.userMetadata?['full_name'] ??
            user?.userMetadata?['name'] ??
            EmergencyConfig.fallbackRiderName;

        telegramDetails = await TelegramService().sendSOSAlert(
          chatIds: chatIds,
          lat: lat,
          lng: lng,
          magnitude: magnitude,
          riderName: name,
        );
        isTelegramSent = telegramDetails['success'] ?? false;
      } else {
        debugPrint('⚠️ Telegram not configured or no chat IDs');
      }
      telegramPart1Ms = stopwatch.elapsedMilliseconds - startTelegramApiPart1;

      // 3. Process Video Evidence (if provided)
      try {
        if (videoPath != null) {
          debugPrint('📹 Video Path: $videoPath');
          // Save to gallery (only if user has enabled the setting)
          try {
            final startGallery = stopwatch.elapsedMilliseconds;
            final shouldSaveToGallery = PreferenceService().saveToGallery;
            if (shouldSaveToGallery) {
              // Request access if needed
              final hasAccess = await Gal.hasAccess();
              if (!hasAccess) {
                await Gal.requestAccess();
              }
              // Check again after request
              final accessGranted = await Gal.hasAccess();
              if (accessGranted) {
                await Gal.putVideo(videoPath);
                gallerySaved = true;
                gallerySaveMs = stopwatch.elapsedMilliseconds - startGallery;
                debugPrint('📁 Berhasil: Video tersimpan ke galeri (${gallerySaveMs}ms)');
              } else {
                galleryError = 'Izin akses galeri ditolak';
                debugPrint('❌ Gagal: Izin galeri tidak diberikan — $galleryError');
              }
            } else {
              debugPrint('📁 Skip gallery save: Fitur "Simpan ke Galeri" dinonaktifkan oleh pengguna.');
            }
          } catch (galError) {
            galleryError = galError.toString();
            debugPrint('❌ Gagal: Video gagal tersimpan ke galeri — $galError');
          }

          // Upload to Supabase Storage, then send URL via Edge Function
          String? finalVideoUrl;
          if (chatIds.isNotEmpty && TelegramService().isConfigured) {
            try {
              startTelegramApiPart2 = stopwatch.elapsedMilliseconds;
              finalVideoUrl = await SupabaseService().uploadIncidentVideo(
                videoPath,
              );
              if (finalVideoUrl != null) {
                await TelegramService().sendVideoToContacts(
                  chatIds: chatIds,
                  videoStorageUrl: finalVideoUrl,
                );
              }
              telegramPart2Ms =
                  stopwatch.elapsedMilliseconds - startTelegramApiPart2;
            } catch (e) {
              debugPrint('Failed to upload/send video via Edge Function: $e');
            }
          }

          // 4. Log to Supabase (metadata only)
          await SupabaseService().logIncident(
            lat: lat,
            lng: lng,
            magnitude: magnitude,
            rideId: rideId,
            videoUrl: finalVideoUrl,
          );
        } else {
          // No video, just log incident
          await SupabaseService().logIncident(
            lat: lat,
            lng: lng,
            magnitude: magnitude,
            rideId: rideId,
          );
        }
      } catch (e) {
        debugPrint('Failed to process video buffer: $e');
        // Fallback logging if video processing completely fails
        await SupabaseService().logIncident(
          lat: lat,
          lng: lng,
          magnitude: magnitude,
          rideId: rideId,
        );
      }

      stopwatch.stop();

      telegramApiMs = telegramPart1Ms + telegramPart2Ms;
      int totalMitigationMs =
          sensorDetectionMs + videoExtractionMs + gallerySaveMs + telegramApiMs;

      if (kDebugMode) {
        debugPrint('📊 [METRICS] sensor_detection_ms: $sensorDetectionMs');
        debugPrint('📊 [METRICS] video_extraction_ms: $videoExtractionMs');
        debugPrint('📊 [METRICS] gallery_save_ms: $gallerySaveMs');
        debugPrint('📊 [METRICS] telegram_api_ms: $telegramApiMs');
        debugPrint('📊 [METRICS] total_mitigation_ms: $totalMitigationMs');

        // Konversi Milidetik ke Detik
        double waktuSensor = sensorDetectionMs / 1000.0;
        double waktuVideo = videoExtractionMs / 1000.0;
        double waktuGaleri = gallerySaveMs / 1000.0;
        double waktuTelegram = telegramApiMs / 1000.0;
        double waktuTotal = totalMitigationMs / 1000.0;

        // Cetak langsung ke Terminal dengan tag pencarian
        debugPrint('\n========== [EVALUASI BAB 4] TABEL 4.3 ==========');
        debugPrint(
          '1. Deteksi sensor hingga memicu status Accident : ${waktuSensor.toStringAsFixed(2)} Detik',
        );
        debugPrint(
          '2. Ekstraksi Video Buffer MP4 (CameraX)         : ${waktuVideo.toStringAsFixed(2)} Detik',
        );
        debugPrint(
          '3. Penyimpanan Video ke Galeri Perangkat        : ${waktuGaleri.toStringAsFixed(2)} Detik',
        );
        debugPrint(
          '4. Telegram API: Kirim Teks, GPS, & Video       : ${waktuTelegram.toStringAsFixed(2)} Detik',
        );
        debugPrint('--------------------------------------------------');
        debugPrint(
          'TOTAL WAKTU RESPONS MITIGASI                    : ${waktuTotal.toStringAsFixed(2)} Detik',
        );
        debugPrint('==================================================\n');

        try {
          await SupabaseService.client.from(SupabaseConfig.tableEvaluationMetrics).insert({
            'test_scenario': 'SOS Success',
            'sensor_detection_ms': sensorDetectionMs,
            'video_extraction_ms': videoExtractionMs,
            'gallery_save_ms': gallerySaveMs,
            'telegram_api_ms': telegramApiMs,
            'total_mitigation_ms': totalMitigationMs,
          });
          debugPrint('📊 Evaluation metrics logged to Supabase.');
        } catch (e) {
          debugPrint(
            '⚠️ Failed to log metrics (table might need migration): $e',
          );
        }
      }

      return {
        'gallerySaved': gallerySaved,
        'galleryError': galleryError,
        'telegramSent': isTelegramSent,
        'telegramDetails': telegramDetails,
      };
    } catch (e) {
      debugPrint('SOS Service Error: $e');
      stopwatch.stop();

      // LOG METRICS EVEN ON ERROR SO WE KNOW WHAT FAILED
      telegramApiMs = telegramPart1Ms + telegramPart2Ms;
      int totalMitigationMs =
          sensorDetectionMs + videoExtractionMs + gallerySaveMs + telegramApiMs;

      try {
        await SupabaseService.client.from(SupabaseConfig.tableEvaluationMetrics).insert({
          'test_scenario':
              'SOS FAILED: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}',
          'sensor_detection_ms': sensorDetectionMs,
          'video_extraction_ms': videoExtractionMs,
          'gallery_save_ms': gallerySaveMs,
          'telegram_api_ms': telegramApiMs,
          'total_mitigation_ms': totalMitigationMs,
        });
      } catch (_) {}

      // Final fallback: Call emergency contact
      await callEmergencyContact();
      return {
        'gallerySaved': false,
        'telegramSent': isTelegramSent,
        'telegramDetails': telegramDetails,
        'error': e.toString(),
      };
    }
  }

  /// Auto dial emergency contact or 112
  Future<void> callEmergencyContact() async {
    try {
      final contacts = await SupabaseService().getEmergencyContacts();
      if (contacts.isNotEmpty) {
        final phone = contacts.first.phone;
        final called = await FlutterPhoneDirectCaller.callNumber(phone);
        if (called == true) return;
      }
    } catch (e) {
      debugPrint('Failed to get emergency contacts: $e');
    }

    // Fallback to national emergency number
    try {
      final called = await FlutterPhoneDirectCaller.callNumber(EmergencyConfig.nationalEmergencyNumber);
      if (called == true) return;
    } catch (_) {}

    // Final fallback via url_launcher
    final url = Uri.parse("tel:${EmergencyConfig.nationalEmergencyNumber}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  /// Show emergency contacts bottom sheet for manual selection
  Future<void> showEmergencyContactSheet(BuildContext context) async {
    try {
      final contacts = await SupabaseService().getEmergencyContacts();
      if (contacts.isEmpty) {
        callEmergencyContact(); // fallback to 112
        return;
      }

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hubungi Kontak Darurat',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...contacts.map(
                (c) => ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.person, color: AppColors.background),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(c.phone),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.call, color: Colors.green),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final url = Uri.parse("tel:${c.phone}");
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.message_rounded,
                          color: Colors.teal,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          // Format number to international format (e.g. 0812 -> 62812)
                          String waNumber = c.phone.replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          if (waNumber.startsWith('0')) {
                            waNumber = '${EmergencyConfig.indonesianCountryCode}${waNumber.substring(1)}';
                          }
                          final url = Uri.parse("${EmergencyConfig.whatsAppBaseUrl}$waNumber");
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: null, // Actions moved to trailing buttons
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.textPrimary.withValues(alpha: 0.87),
                  child: Icon(Icons.local_hospital, color: AppColors.background),
                ),
                title: const Text(
                  'Layanan Darurat Nasional',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(EmergencyConfig.nationalEmergencyNumber),
                trailing: const Icon(Icons.call, color: Colors.green),
                onTap: () async {
                  Navigator.pop(ctx);
                  final url = Uri.parse("tel:${EmergencyConfig.nationalEmergencyNumber}");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing emergency sheet: $e');
      callEmergencyContact();
    }
  }
}