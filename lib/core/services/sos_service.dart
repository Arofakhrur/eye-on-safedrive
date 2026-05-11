import 'package:url_launcher/url_launcher.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/location_service.dart';
import 'package:flutter/foundation.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();

  factory SOSService() {
    return _instance;
  }

  SOSService._internal();

  /// Trigger the full SOS flow: Get Location -> Log to DB -> Launch WhatsApp
  Future<void> triggerEmergencySOS(double magnitude) async {
    try {
      // 1. Get Location
      final position = await LocationService.getCurrentLocation();
      if (position == null) throw Exception("Failed to get location");

      final lat = position.latitude;
      final lng = position.longitude;

      // 2. Log to Supabase
      await SupabaseService().logIncident(lat, lng, magnitude);

      // 3. Get Emergency Contact
      final contacts = await SupabaseService().getEmergencyContacts();
      String phone = "112"; // Default fallback
      if (contacts.isNotEmpty) {
        phone = contacts.first.phone;
      }

      // Clean phone number (remove non-digits except +)
      phone = phone.replaceAll(RegExp(r'[^\d+]'), '');

      // 4. Launch WhatsApp URL
      final message = Uri.encodeComponent(
          "🚨 EMERGENCY (EYE-ON! SOS) 🚨\n\nI have been involved in an accident. My location is:\nhttps://www.google.com/maps/search/?api=1&query=$lat,$lng\n\nPlease send help immediately.");
      
      final url = Uri.parse("https://wa.me/$phone?text=$message");

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch WhatsApp. Attempting to dial...');
        // Fallback to phone dialer
        final dialerUrl = Uri.parse("tel:$phone");
        if (await canLaunchUrl(dialerUrl)) {
          await launchUrl(dialerUrl);
        }
      }
    } catch (e) {
      debugPrint('SOS Service Error: $e');
      // Final fallback: Call 112
      final dialerUrl = Uri.parse("tel:112");
      if (await canLaunchUrl(dialerUrl)) {
        await launchUrl(dialerUrl);
      }
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
