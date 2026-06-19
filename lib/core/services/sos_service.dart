import 'package:eyeon/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/telegram_service.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();

  factory SOSService() => _instance;

  SOSService._internal();

  /// Trigger the full SOS flow:
  /// 1. Get GPS location
  /// 2. Send SOS via Telegram Edge Function (text + location)
  /// 3. Process video evidence (FFmpeg render)
  /// 4. Save video to gallery + send via Telegram
  /// 5. Log incident to Supabase
  Future<Map<String, dynamic>> triggerEmergencySOS(
    double magnitude, {
    String? rideId,
    String? videoPath,
  }) async {
    bool gallerySaved = false;
    String? galleryError;
    
    final stopwatch = Stopwatch()..start();
    int timeGps = 0;
    int timeFfmpeg = 0;
    int timeTelegram = 0;

    try {
      // 1. Get Location
      final startGps = stopwatch.elapsedMilliseconds;
      final position = await LocationService.getCurrentLocation();
      if (position == null) throw Exception("Failed to get location");

      final lat = position.latitude;
      final lng = position.longitude;
      timeGps = stopwatch.elapsedMilliseconds - startGps;
      // debugPrint('⏱️ Waktu ambil GPS: ...');

      // 2. Get Contacts & Send Text/GPS via Edge Function (Instant)
      final contacts = await SupabaseService().getEmergencyContacts();
      final chatIds = contacts
          .where((c) => c.telegramChatId != null && c.telegramChatId!.isNotEmpty)
          .map((c) => c.telegramChatId!)
          .toList();

      Map<String, dynamic> telegramResult = {'success': false};
      if (chatIds.isNotEmpty && TelegramService().isConfigured) {
        final user = SupabaseService().currentUser;
        final name = user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'] ?? 'Pengendara';

        final startTextTelegram = stopwatch.elapsedMilliseconds;
        telegramResult = await TelegramService().sendSOSAlert(
          chatIds: chatIds,
          lat: lat,
          lng: lng,
          magnitude: magnitude,
          riderName: name,
        );
        timeTelegram += (stopwatch.elapsedMilliseconds - startTextTelegram);
        // debugPrint('⏱️ Waktu kirim Teks & Lokasi via Edge Function: ...');
      } else {
        debugPrint('⚠️ Telegram not configured or no chat IDs');
      }

      // 3. Process Video Evidence (if provided)
      try {
        if (videoPath != null) {
          final startFfmpeg = stopwatch.elapsedMilliseconds;
          // Note: FFMpeg render time is technically zero now since it's native
          timeFfmpeg = stopwatch.elapsedMilliseconds - startFfmpeg;
          debugPrint('📹 Video Path: $videoPath');
          // Save to gallery (primary local action)
          try {
            final hasAccess = await Gal.hasAccess();
            if (!hasAccess) await Gal.requestAccess();
            await Gal.putVideo(videoPath);
            gallerySaved = true;
            debugPrint('📁 Berhasil: Video tersimpan ke galeri');
          } catch (galError) {
            galleryError = galError.toString();
            debugPrint('❌ Gagal: Video gagal tersimpan, Error: $galError');
          }
          // debugPrint('⏱️ Waktu simpan ke Galeri: ...');

          // Upload to Supabase Storage, then send URL via Edge Function
          if (chatIds.isNotEmpty && TelegramService().isConfigured) {
            try {
              final startVideoTelegram = stopwatch.elapsedMilliseconds;
              final videoStorageUrl = await SupabaseService().uploadIncidentVideo(videoPath);
              if (videoStorageUrl != null) {
                await TelegramService().sendVideoToContacts(
                  chatIds: chatIds,
                  videoStorageUrl: videoStorageUrl,
                );
              }
              timeTelegram += (stopwatch.elapsedMilliseconds - startVideoTelegram);
            } catch (e) {
              debugPrint('Failed to upload/send video via Edge Function: $e');
            }
            // debugPrint('⏱️ Waktu kirim Video via Edge Function: ...');
          }
        }
      } catch (e) {
        debugPrint('Failed to process video buffer: $e');
      }

      // 4. Log to Supabase (metadata only)
      await SupabaseService().logIncident(
        lat: lat,
        lng: lng,
        magnitude: magnitude,
        rideId: rideId,
      );
      // debugPrint('⏱️ Waktu catat insiden Supabase: ...');
      
      stopwatch.stop();
      // debugPrint('⏱️ Total Waktu SOS: ...');

      if (kDebugMode) {
        try {
          await SupabaseService.client.from('evaluation_metrics').insert({
            'test_scenario': 'SOS Trigger with Video',
            'gps_latency_ms': timeGps,
            'ffmpeg_render_ms': timeFfmpeg,
            'telegram_latency_ms': timeTelegram,
            'total_response_ms': stopwatch.elapsedMilliseconds,
          });
          debugPrint('📊 Evaluation metrics logged to Supabase.');
        } catch (e) {
          debugPrint('Failed to log metrics: $e');
        }
      }

      return {
        'gallerySaved': gallerySaved,
        'galleryError': galleryError,
        'telegramSent': telegramResult['success'] ?? false,
        'telegramDetails': telegramResult,
      };
    } catch (e) {
      debugPrint('SOS Service Error: $e');
      // Final fallback: Call emergency contact
      await callEmergencyContact();
      return {
        'gallerySaved': false,
        'telegramSent': false,
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
        final url = Uri.parse("tel:$phone");
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
          return;
        }
      }
    } catch (e) {
      debugPrint('Failed to get emergency contacts: $e');
    }

    final url = Uri.parse("tel:112");
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
          decoration: const BoxDecoration(
            color: Colors.white,
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
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ...contacts.map(
                (c) => ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.person, color: Colors.white),
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
                        icon: const Icon(Icons.message_rounded, color: Colors.teal),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          // Format number to international format (e.g. 0812 -> 62812)
                          String waNumber = c.phone.replaceAll(RegExp(r'\D'), '');
                          if (waNumber.startsWith('0')) {
                            waNumber = '62${waNumber.substring(1)}';
                          }
                          final url = Uri.parse("https://wa.me/$waNumber");
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
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
                leading: const CircleAvatar(
                  backgroundColor: Colors.black87,
                  child: Icon(Icons.local_hospital, color: Colors.white),
                ),
                title: const Text(
                  'Layanan Darurat Nasional',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('112'),
                trailing: const Icon(Icons.call, color: Colors.green),
                onTap: () async {
                  Navigator.pop(ctx);
                  final url = Uri.parse("tel:112");
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
