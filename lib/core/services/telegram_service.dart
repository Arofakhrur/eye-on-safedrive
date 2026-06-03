import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for sending SOS alerts via Telegram Bot API.
///
/// Capabilities:
/// - Send text messages (SOS alert with details)
/// - Send GPS location pins
/// - Send video evidence files
class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  String get _botToken => dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '';

  String get _baseUrl => 'https://api.telegram.org/bot$_botToken';

  bool get isConfigured => _botToken.isNotEmpty && _botToken != 'your_bot_token_here';

  /// Send a plain text message to a Telegram chat.
  Future<bool> sendTextMessage(String chatId, String message) async {
    if (!isConfigured) {
      debugPrint('⚠️ Telegram bot token not configured');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'HTML',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Telegram text sent to $chatId');
        return true;
      } else {
        debugPrint('❌ Telegram sendMessage failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Telegram sendMessage error: $e');
      return false;
    }
  }

  /// Send a GPS location pin to a Telegram chat.
  Future<bool> sendLocation(String chatId, double lat, double lng) async {
    if (!isConfigured) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sendLocation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'latitude': lat,
          'longitude': lng,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Telegram location sent to $chatId');
        return true;
      } else {
        debugPrint('❌ Telegram sendLocation failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Telegram sendLocation error: $e');
      return false;
    }
  }

  /// Send a video file to a Telegram chat using multipart upload.
  Future<bool> sendVideo(String chatId, String videoPath) async {
    if (!isConfigured) return false;

    try {
      final file = File(videoPath);
      if (!file.existsSync()) {
        debugPrint('⚠️ Video file not found: $videoPath');
        return false;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/sendVideo'),
      );

      request.fields['chat_id'] = chatId;
      request.fields['caption'] = '🎥 Bukti rekaman insiden dari EYE-ON!';
      request.files.add(
        await http.MultipartFile.fromPath('video', videoPath),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        debugPrint('✅ Telegram video sent to $chatId');
        return true;
      } else {
        final body = await response.stream.bytesToString();
        debugPrint('❌ Telegram sendVideo failed: $body');
        return false;
      }
    } catch (e) {
      debugPrint('Telegram sendVideo error: $e');
      return false;
    }
  }

  /// Send a full SOS alert to all emergency contacts.
  ///
  /// Sends: text alert → location pin → video evidence (if available).
  Future<Map<String, dynamic>> sendSOSAlert({
    required List<String> chatIds,
    required double lat,
    required double lng,
    required double magnitude,
    String? videoPath,
  }) async {
    if (!isConfigured) {
      return {'success': false, 'error': 'Telegram bot not configured'};
    }

    if (chatIds.isEmpty) {
      return {'success': false, 'error': 'No Telegram chat IDs configured'};
    }

    final mapsLink = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final timestamp = DateTime.now().toIso8601String();

    final message = '🚨 <b>DARURAT — EYE-ON! SOS ALERT</b> 🚨\n\n'
        '⏰ Waktu: $timestamp\n'
        '📍 Lokasi: $mapsLink\n'
        '💥 Kekuatan guncangan: ${magnitude.toStringAsFixed(1)} rad/s\n\n'
        'Pengguna ini mungkin mengalami kecelakaan atau microsleep saat berkendara. '
        'Segera hubungi atau cek lokasinya!';

    int successCount = 0;
    final List<String> errors = [];

    for (final chatId in chatIds) {
      try {
        // 1. Send text alert
        await sendTextMessage(chatId, message);

        // 2. Send location pin
        await sendLocation(chatId, lat, lng);

        // 3. Send video if available
        if (videoPath != null) {
          await sendVideo(chatId, videoPath);
        }

        successCount++;
      } catch (e) {
        errors.add('Failed for $chatId: $e');
      }
    }

    return {
      'success': successCount > 0,
      'sent': successCount,
      'total': chatIds.length,
      'errors': errors,
    };
  }
}
