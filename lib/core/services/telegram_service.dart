import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eyeon/core/constants/app_constants.dart';

/// Service for sending SOS alerts via Telegram Bot API.
class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  /// Always configured — token lives on the server, not the client.
  bool get isConfigured => Supabase.instance.client.auth.currentUser != null;

  /// Send a full SOS alert to all emergency contacts via Edge Function.
  ///
  /// Sends: text alert → location pin → video evidence (if available).
  Future<Map<String, dynamic>> sendSOSAlert({
    required List<String> chatIds,
    required double lat,
    required double lng,
    required double magnitude,
    required String riderName,
    String? videoUrl,
  }) async {
    if (chatIds.isEmpty) {
      return {'success': false, 'error': 'No Telegram chat IDs configured'};
    }

    final mapsLink =
        '${AppUrls.googleMapsSearch}&query=$lat,$lng';
    final timestamp =
        '${DateFormat('dd MMM yyyy - HH:mm').format(DateTime.now())} WIB';

    String address = "Alamat tidak dapat dimuat";
    try {
      final reverseUrl = AppUrls.nominatimReverseUrl(lat, lng);
      final response = await http
          .get(Uri.parse(reverseUrl))
          .timeout(AppDurations.reverseGeocodeTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['display_name'] != null) {
          address = data['display_name'];
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }

    final message =
        '🚨 <b>DARURAT — EYE-ON! SOS ALERT</b> 🚨\n\n'
        '👤 <b>Pengendara:</b> $riderName\n'
        '⏰ <b>Waktu:</b> $timestamp\n'
        '📍 <b>Area Terdekat:</b> $address\n'
        '🗺️ <b>Google Maps:</b> <a href="$mapsLink">Buka Peta</a>\n'
        '📌 <b>Koordinat:</b> <code>$lat, $lng</code>\n'
        '💥 <b>Kekuatan guncangan:</b> ${magnitude.toStringAsFixed(1)} rad/s\n\n'
        '$riderName mungkin mengalami kecelakaan atau microsleep saat berkendara. '
        'Segera hubungi atau cek lokasinya!';

    try {
      final res = await Supabase.instance.client.functions.invoke(
        SupabaseConfig.edgeFunctionTelegramSOS,
        body: {
          'chatIds': chatIds,
          'message': message,
          'lat': lat,
          'lng': lng,
          'videoUrl': ?videoUrl,
        },
      );

      if (res.status == 200) {
        final data = res.data as Map<String, dynamic>;
        debugPrint(
          '✅ Telegram SOS sent via Edge Function: ${data['sent']}/${data['total']}',
        );
        return data;
      } else {
        debugPrint('❌ Edge Function error: ${res.status}');
        return {
          'success': false,
          'error': 'Edge Function returned ${res.status}',
        };
      }
    } catch (e) {
      debugPrint('TelegramService Edge Function error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send video evidence separately (after initial text+location SOS).
  /// Uploads video to Supabase Storage first, then sends URL via Edge Function.
  Future<bool> sendVideoToContacts({
    required List<String> chatIds,
    required String videoStorageUrl,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        SupabaseConfig.edgeFunctionTelegramSOS,
        body: {
          'chatIds': chatIds,
          'message': '',
          'lat': 0,
          'lng': 0,
          'videoUrl': videoStorageUrl,
        },
      );
      return res.status == 200;
    } catch (e) {
      debugPrint('Telegram video send error: $e');
      return false;
    }
  }
}
