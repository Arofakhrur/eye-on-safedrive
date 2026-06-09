import 'package:eyeon/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/video_buffer_service.dart';
import 'package:eyeon/core/services/telegram_service.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();

  factory SOSService() => _instance;

  SOSService._internal();

  /// Trigger the full SOS flow:
  /// 1. Get GPS location
  /// 2. Save video to gallery
  /// 3. Send SOS via Telegram (text + location + video)
  /// 4. Log incident to Supabase (without uploading video to storage)
  Future<Map<String, dynamic>> triggerEmergencySOS(
    double magnitude, {
    String? rideId,
  }) async {
    bool gallerySaved = false;
    String? galleryError;
    String? videoPath;

    try {
      // 1. Get Location
      final position = await LocationService.getCurrentLocation();
      if (position == null) throw Exception("Failed to get location");

      final lat = position.latitude;
      final lng = position.longitude;

      // 2. Extract Video Buffer (evidence)
      try {
        videoPath = await VideoBufferService().saveBufferToVideo();
        debugPrint('📹 Video Path: $videoPath');

        if (videoPath != null) {
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
        }
      } catch (e) {
        debugPrint('Failed to process video buffer: $e');
      }

      // 3. Send SOS via Telegram Bot API (free, no storage cost)
      Map<String, dynamic> telegramResult = {'success': false};
      try {
        final contacts = await SupabaseService().getEmergencyContacts();
        final chatIds = contacts
            .where((c) => c.telegramChatId != null && c.telegramChatId!.isNotEmpty)
            .map((c) => c.telegramChatId!)
            .toList();
        if (chatIds.isNotEmpty && TelegramService().isConfigured) {
          final user = SupabaseService().currentUser;
          final name = user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'] ?? 'Pengendara';

          telegramResult = await TelegramService().sendSOSAlert(
            chatIds: chatIds,
            lat: lat,
            lng: lng,
            magnitude: magnitude,
            riderName: name,
            videoPath: videoPath,
          );
          debugPrint('📱 Telegram SOS result: $telegramResult');
        } else {
          debugPrint('⚠️ Telegram not configured or no chat IDs');
        }
      } catch (e) {
        debugPrint('Telegram SOS error: $e');
      }

      // 4. Log to Supabase (metadata only, no video upload to storage)
      await SupabaseService().logIncident(
        lat: lat,
        lng: lng,
        magnitude: magnitude,
        rideId: rideId,
      );

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
                  trailing: const Icon(Icons.call, color: Colors.green),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = Uri.parse("tel:${c.phone}");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
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
