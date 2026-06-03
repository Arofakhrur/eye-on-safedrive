import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  static SupabaseClient get client => Supabase.instance.client;

  // --- Auth Utilities ---

  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<void> signOut() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }
    await client.auth.signOut();
  }

  /// Manual Email/Password Registration
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
  }

  /// Manual Email/Password Login
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse?> signInWithGoogle() async {
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
      final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        clientId: iosClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('No Access Token or ID Token found.');
      }

      return await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ================================================================
  // Emergency Contacts — Per-individu CRUD (Task 7)
  // ================================================================

  /// Add a single emergency contact. Enforces max 5 per user.
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    if (currentUser == null) return;

    // Check max limit
    final existing = await getEmergencyContacts();
    if (existing.length >= 5) {
      throw Exception('Maksimal 5 kontak darurat');
    }

    // Check uniqueness
    final duplicate = existing.any(
      (c) => c.phone == contact.phone,
    );
    if (duplicate) {
      throw Exception('Nomor telepon sudah terdaftar');
    }

    await client.from('emergency_contacts').insert(contact.toJson());
  }

  /// Update an existing emergency contact by its ID.
  Future<void> updateEmergencyContact(
    String contactId, {
    String? name,
    String? phone,
    String? telegramChatId,
  }) async {
    if (currentUser == null) return;

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (telegramChatId != null) updates['telegram_chat_id'] = telegramChatId;

    await client
        .from('emergency_contacts')
        .update(updates)
        .eq('id', contactId)
        .eq('user_id', currentUser!.id);
  }

  /// Delete a single emergency contact by its ID.
  Future<void> deleteEmergencyContact(String contactId) async {
    if (currentUser == null) return;
    await client
        .from('emergency_contacts')
        .delete()
        .eq('id', contactId)
        .eq('user_id', currentUser!.id);
  }

  /// Legacy bulk save — kept for backward compatibility during initial setup.
  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    if (currentUser == null) return;
    await client.from('emergency_contacts').delete().eq('user_id', currentUser!.id);
    if (contacts.isNotEmpty) {
      final data = contacts.map((c) => {
        'user_id': currentUser!.id,
        'name': c.name,
        'phone': c.phone,
        if (c.telegramChatId != null) 'telegram_chat_id': c.telegramChatId,
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();
      await client.from('emergency_contacts').insert(data);
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    if (currentUser == null) return [];
    final response = await client.from('emergency_contacts').select().eq('user_id', currentUser!.id);
    return (response as List).map((json) => EmergencyContact.fromJson(json)).toList();
  }

  // ================================================================
  // Incident Logs — with ride_id FK (Task 8)
  // ================================================================

  Future<void> logIncident({
    required double lat,
    required double lng,
    required double magnitude,
    String? videoUrl,
    String? rideId,
  }) async {
    if (currentUser == null) return;
    await client.from('incident_logs').insert({
      'user_id': currentUser!.id,
      'latitude': lat,
      'longitude': lng,
      'magnitude': magnitude,
      if (videoUrl != null) 'video_url': videoUrl,
      if (rideId != null) 'ride_id': rideId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Get incidents associated with a specific ride.
  Future<List<Map<String, dynamic>>> getIncidentsForRide(String rideId) async {
    if (currentUser == null) return [];
    final response = await client
        .from('incident_logs')
        .select()
        .eq('ride_id', rideId)
        .order('timestamp');
    return List<Map<String, dynamic>>.from(response);
  }

  // ================================================================
  // Ride Logs — returns ride UUID (Task 8)
  // ================================================================

  /// Log a ride and return its UUID for incident linking.
  Future<String?> logRide({
    required DateTime startTime,
    required DateTime endTime,
    required int totalMicrosleepAlerts,
    required int totalAccidentAlerts,
    required double distance,
    String? videoUrl,
  }) async {
    if (currentUser == null) return null;
    try {
      final result = await client.from('ride_logs').insert({
        'user_id': currentUser!.id,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'microsleep_alerts': totalMicrosleepAlerts,
        'accident_alerts': totalAccidentAlerts,
        'distance': distance,
        if (videoUrl != null) 'video_url': videoUrl,
      }).select('id').single();
      return result['id']?.toString();
    } catch (e) {
      debugPrint('Log Ride Error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getRideHistory() async {
    if (currentUser == null) return [];
    try {
      final response = await client
          .from('ride_logs')
          .select()
          .eq('user_id', currentUser!.id)
          .order('start_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Fallback to incident_logs if ride_logs is still missing
      final response = await client
          .from('incident_logs')
          .select()
          .eq('user_id', currentUser!.id)
          .order('timestamp', ascending: false);
      
      return (response as List).map((item) => <String, dynamic>{
        'id': item['id'],
        'start_time': item['timestamp'],
        'end_time': item['timestamp'],
        'microsleep_alerts': 0,
        'accident_alerts': 1,
        'distance': 0.0,
        'latitude': item['latitude'],
        'longitude': item['longitude'],
        'magnitude': item['magnitude'],
        'video_url': item['video_url'],
      }).toList();
    }
  }

  // ================================================================
  // Profiles Table — Isolated Medical Info (Task 9)
  // ================================================================

  /// Get the current user's public profile.
  Future<Map<String, dynamic>?> getProfile() async {
    if (currentUser == null) return null;
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Get profile error: $e');
      return null;
    }
  }

  /// Create or update the user's profile in the profiles table.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (currentUser == null) return;
    try {
      await client.from('profiles').upsert({
        'id': currentUser!.id,
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Update profile error: $e');
    }
  }

  /// Legacy metadata update — kept for backward compatibility.
  Future<void> updateUserMetadata(Map<String, dynamic> metadata) async {
    await client.auth.updateUser(UserAttributes(data: metadata));
  }

  // ================================================================
  // Video Upload (kept as optional backup)
  // ================================================================

  Future<String?> uploadIncidentVideo(String filePath) async {
    if (currentUser == null) return null;
    final fileName = 'incident_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final path = '${currentUser!.id}/$fileName';
    final file = File(filePath);
    await client.storage.from('incident_videos').upload(path, file);
    return client.storage.from('incident_videos').getPublicUrl(path);
  }
}
