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
    final GoogleSignIn googleSignIn =
        GoogleSignIn(); // Menggunakan pemanggilan normal

    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }
    await client.auth.signOut();
  }

  Future<AuthResponse?> signInWithGoogle() async {
    print('--- Supabase Auth: Starting Google Sign-In ---');
    try {
      // TODO: Add your actual Client IDs here for production
      const webClientId =
          '773015281907-4s8r47vmqkc61ccrdhgthucahb6ap275.apps.googleusercontent.com';
      const iosClientId =
          '773015281907-4s8r47vmqkc61ccrdhgthucahb6ap275.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        clientId: iosClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        print('--- Supabase Auth: Google Sign-In Canceled by User ---');
        return null;
      }

      print('--- Supabase Auth: Google User Found: ${googleUser.email} ---');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        print('--- Supabase Auth: ERROR - Missing Tokens ---');
        throw Exception('No Access Token or ID Token found.');
      }

      print('--- Supabase Auth: Exchanging Tokens with Supabase ---');
      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      print('--- Supabase Auth: Google Sign-In Success ---');
      return response;
    } catch (e, stack) {
      print('--- Supabase Auth ERROR ---');
      print('Error Type: ${e.runtimeType}');
      print('Error: $e');
      print('Stack Trace: $stack');
      rethrow;
    }
  }

  // --- Database Utilities ---

  /// Save multiple emergency contacts to Supabase
  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    if (currentUser == null) return;

    // We can delete existing ones and replace, or just upsert the list
    // For simplicity in the setup screen, we'll replace the set for this user
    await client
        .from('emergency_contacts')
        .delete()
        .eq('user_id', currentUser!.id);

    if (contacts.isNotEmpty) {
      final data = contacts
          .map(
            (c) => {
              'user_id': currentUser!.id,
              'name': c.name,
              'phone': c.phone,
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await client.from('emergency_contacts').insert(data);
    }
  }

  /// Get all emergency contacts from Supabase
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    if (currentUser == null) return [];

    final response = await client
        .from('emergency_contacts')
        .select()
        .eq('user_id', currentUser!.id);

    return (response as List)
        .map((json) => EmergencyContact.fromJson(json))
        .toList();
  }

  /// Log an accident incident
  Future<void> logIncident(double lat, double lng, double magnitude) async {
    if (currentUser == null) return;

    await client.from('incident_logs').insert({
      'user_id': currentUser!.id,
      'latitude': lat,
      'longitude': lng,
      'magnitude': magnitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
