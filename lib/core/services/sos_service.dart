import 'package:eyeon/core/services/location_service.dart';
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
  Future<Map<String, dynamic>> triggerEmergencySOS(double magnitude, {String? rideId}) async {
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
        final chatIds = PreferenceService().telegramChatIds;
        if (chatIds.isNotEmpty && TelegramService().isConfigured) {
          telegramResult = await TelegramService().sendSOSAlert(
            chatIds: chatIds,
            lat: lat,
            lng: lng,
            magnitude: magnitude,
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
      // Final fallback: Call 112 directly
      final dialerUrl = Uri.parse("tel:112");
      if (await canLaunchUrl(dialerUrl)) {
        await launchUrl(dialerUrl);
      }
      return {'gallerySaved': false, 'telegramSent': false, 'error': e.toString()};
    }
  }

  /// Manual dial 112
  Future<void> callNationalEmergency() async {
    final url = Uri.parse("tel:112");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
