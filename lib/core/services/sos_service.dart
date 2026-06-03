import 'package:eyeon/core/services/location_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/video_buffer_service.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();

  factory SOSService() => _instance;

  SOSService._internal();

  /// Trigger the full SOS flow: Returns status of cloud upload and local save
  Future<Map<String, dynamic>> triggerEmergencySOS(double magnitude) async {
    String? finalVideoUrl;
    bool gallerySaved = false;
    String? galleryError;

    try {
      // 1. Get Location
      final position = await LocationService.getCurrentLocation();
      if (position == null) throw Exception("Failed to get location");

      final lat = position.latitude;
      final lng = position.longitude;

      // 2. Extract Video Buffer (10s)
      try {
        final videoPath = await VideoBufferService().saveBufferToVideo();
        debugPrint('📹 Video Path: $videoPath');

        if (videoPath != null) {
          // 1. SAVE TO GALLERY (Primary Action)
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

          // 2. UPLOAD TO SUPABASE (Backup Action)
          try {
            debugPrint('☁️ Uploading backup to Supabase Storage...');
            finalVideoUrl = await SupabaseService().uploadIncidentVideo(
              videoPath,
            );
          } catch (uploadError) {
            debugPrint('☁️ Backup Upload Failed: $uploadError');
          }
        }
      } catch (e) {
        debugPrint('Failed to process video buffer: $e');
      }

      // 4. Log to Supabase (This triggers the Edge Function for WhatsApp SOS)
      await SupabaseService().logIncident(
        lat: lat,
        lng: lng,
        magnitude: magnitude,
        videoUrl: finalVideoUrl,
      );

      return {
        'videoUrl': finalVideoUrl,
        'gallerySaved': gallerySaved,
        'galleryError': galleryError,
      };
    } catch (e) {
      debugPrint('SOS Service Error: $e');
      // Final fallback: Call 112 directly
      final dialerUrl = Uri.parse("tel:112");
      if (await canLaunchUrl(dialerUrl)) {
        await launchUrl(dialerUrl);
      }
      return {'videoUrl': null, 'gallerySaved': false, 'error': e.toString()};
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
