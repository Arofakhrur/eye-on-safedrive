import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      const webClientId = '773015281907-4s8r47vmqkc61ccrdhgthucahb6ap275.apps.googleusercontent.com';
      const iosClientId = '773015281907-4s8r47vmqkc61ccrdhgthucahb6ap275.apps.googleusercontent.com';

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

  // --- Database Utilities ---

  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    if (currentUser == null) return;
    await client.from('emergency_contacts').delete().eq('user_id', currentUser!.id);
    if (contacts.isNotEmpty) {
      final data = contacts.map((c) => {
        'user_id': currentUser!.id,
        'name': c.name,
        'phone': c.phone,
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

  Future<String?> uploadIncidentVideo(String filePath) async {
    if (currentUser == null) return null;
    final fileName = 'incident_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final path = '${currentUser!.id}/$fileName';
    final file = File(filePath);
    await client.storage.from('incident_videos').upload(path, file);
    return client.storage.from('incident_videos').getPublicUrl(path);
  }

  Future<void> logIncident({
    required double lat,
    required double lng,
    required double magnitude,
    String? videoUrl,
  }) async {
    if (currentUser == null) return;
    await client.from('incident_logs').insert({
      'user_id': currentUser!.id,
      'latitude': lat,
      'longitude': lng,
      'magnitude': magnitude,
      'video_url': videoUrl,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> logRide({
    required DateTime startTime,
    required DateTime endTime,
    required int totalMicrosleepAlerts,
    required int totalAccidentAlerts,
    required double distance,
    String? videoUrl,
  }) async {
    if (currentUser == null) return;
    try {
      await client.from('ride_logs').insert({
        'user_id': currentUser!.id,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'microsleep_alerts': totalMicrosleepAlerts,
        'accident_alerts': totalAccidentAlerts,
        'distance': distance,
        'video_url': videoUrl,
      });
    } catch (e) {
      print('Log Ride Error: $e');
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
      
      return (response as List).map((item) => {
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

  Future<void> updateUserMetadata(Map<String, dynamic> metadata) async {
    await client.auth.updateUser(UserAttributes(data: metadata));
  }
}
