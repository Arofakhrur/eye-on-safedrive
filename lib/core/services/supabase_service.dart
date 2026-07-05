import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  static SupabaseClient get client => Supabase.instance.client;

  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, SupabaseConfig.offlineDbName),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              table_name TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<void> _saveToOfflineQueue(String tableName, Map<String, dynamic> data) async {
    final db = await _getDb();
    await db.insert('offline_queue', {
      'table_name': tableName,
      'payload': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
    debugPrint('📦 Saved to offline queue: $tableName');
  }

  /// Sync all offline queued data to Supabase.
  /// Returns the number of successfully synced records.
  Future<int> syncOfflineData() async {
    final db = await _getDb();
    final rows = await db.query('offline_queue', orderBy: 'id ASC');
    if (rows.isEmpty) return 0;

    int synced = 0;
    for (final row in rows) {
      try {
        final tableName = row['table_name'] as String;
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        await client.from(tableName).insert(payload);
        await db.delete('offline_queue', where: 'id = ?', whereArgs: [row['id']]);
        synced++;
      } catch (e) {
        debugPrint('⚠️ Failed to sync row ${row['id']}: $e');
        // Stop at first failure to maintain order
        break;
      }
    }
    debugPrint('✅ Synced $synced/${rows.length} offline records');
    return synced;
  }

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

  /// Add a single emergency contact. Enforces max 5 per user.
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    if (currentUser == null) return;

    // Check max limit
    final existing = await getEmergencyContacts();
    if (existing.length >= AppLimits.maxEmergencyContacts) {
      throw Exception('Maksimal ${AppLimits.maxEmergencyContacts} kontak darurat');
    }

    // Check uniqueness
    final duplicate = existing.any(
      (c) => c.phone == contact.phone,
    );
    if (duplicate) {
      throw Exception('Nomor telepon sudah terdaftar');
    }

    await client.from(SupabaseConfig.tableEmergencyContacts).insert(contact.toJson());
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
        .from(SupabaseConfig.tableEmergencyContacts)
        .update(updates)
        .eq('id', contactId)
        .eq('user_id', currentUser!.id);
  }

  /// Delete a single emergency contact by its ID.
  Future<void> deleteEmergencyContact(String contactId) async {
    if (currentUser == null) return;
    await client
        .from(SupabaseConfig.tableEmergencyContacts)
        .delete()
        .eq('id', contactId)
        .eq('user_id', currentUser!.id);
  }

  /// Legacy bulk save — kept for backward compatibility during initial setup.
  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    if (currentUser == null) return;
    await client.from(SupabaseConfig.tableEmergencyContacts).delete().eq('user_id', currentUser!.id);
    if (contacts.isNotEmpty) {
      final data = contacts.map((c) => {
        'user_id': currentUser!.id,
        'name': c.name,
        'phone': c.phone,
        'telegram_chat_id': c.telegramChatId,
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();
      await client.from(SupabaseConfig.tableEmergencyContacts).insert(data);
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    if (currentUser == null) return [];
    final response = await client.from(SupabaseConfig.tableEmergencyContacts).select().eq('user_id', currentUser!.id);
    return (response as List).map((json) => EmergencyContact.fromJson(json)).toList();
  }

  Future<void> logIncident({
    required double lat,
    required double lng,
    required double magnitude,
    String? videoUrl,
    String? rideId,
  }) async {
    if (currentUser == null) return;
    final data = {
      'user_id': currentUser!.id,
      'latitude': lat,
      'longitude': lng,
      'magnitude': magnitude,
      if (videoUrl != null) 'video_url': videoUrl,
      if (rideId != null) 'ride_id': rideId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    try {
      await client.from(SupabaseConfig.tableIncidentLogs).insert(data);
    } catch (e) {
      debugPrint('⚠️ logIncident failed, saving offline: $e');
      await _saveToOfflineQueue(SupabaseConfig.tableIncidentLogs, data);
    }
  }

  /// Get incidents associated with a specific ride.
  Future<List<Map<String, dynamic>>> getIncidentsForRide(String rideId) async {
    if (currentUser == null) return [];
    final response = await client
        .from(SupabaseConfig.tableIncidentLogs)
        .select()
        .eq('ride_id', rideId)
        .order('timestamp');
    return List<Map<String, dynamic>>.from(response);
  }

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
      final result = await client.from(SupabaseConfig.tableRideLogs).insert({
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

  /// Update an existing ride record with final data when ride ends.
  Future<void> updateRide({
    required String rideId,
    required DateTime endTime,
    required int totalMicrosleepAlerts,
    required int totalAccidentAlerts,
    required double distance,
  }) async {
    if (currentUser == null) return;
    try {
      await client.from(SupabaseConfig.tableRideLogs).update({
        'end_time': endTime.toIso8601String(),
        'microsleep_alerts': totalMicrosleepAlerts,
        'accident_alerts': totalAccidentAlerts,
        'distance': distance,
      }).eq('id', rideId);
      debugPrint('Ride updated: $rideId');
    } catch (e) {
      debugPrint('Update Ride Error, saving offline: $e');
      await _saveToOfflineQueue('ride_logs', {
        'user_id': currentUser!.id,
        'id': rideId,
        'end_time': endTime.toIso8601String(),
        'microsleep_alerts': totalMicrosleepAlerts,
        'accident_alerts': totalAccidentAlerts,
        'distance': distance,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getRideHistory() async {
    if (currentUser == null) return [];
    try {
      final response = await client
          .from(SupabaseConfig.tableRideLogs)
          .select()
          .eq('user_id', currentUser!.id)
          .order('start_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Fallback to incident_logs only if ride_logs is specifically missing
      final errStr = e.toString().toLowerCase();
      if (!errStr.contains('does not exist') && !errStr.contains('42p01')) {
        rethrow;
      }
      
      final response = await client
          .from(SupabaseConfig.tableIncidentLogs)
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

  /// Real-time stream of ride history
  Stream<List<Map<String, dynamic>>> streamRideHistory() {
    if (currentUser == null) return const Stream.empty();
    
    // We try to stream from ride_logs. 
    // Supabase will automatically listen to updates on this table if Realtime is enabled.
    return client
        .from(SupabaseConfig.tableRideLogs)
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .order('start_time', ascending: false)
        .map((response) {
      return List<Map<String, dynamic>>.from(response);
    }).handleError((error) {
      debugPrint('Stream error (ride_logs might not exist or Realtime disabled): $error');
      return <Map<String, dynamic>>[];
    });
  }

  /// Get the current user's public profile.
  Future<Map<String, dynamic>?> getProfile() async {
    if (currentUser == null) return null;
    try {
      final response = await client
          .from(SupabaseConfig.tableProfiles)
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
      await client.from(SupabaseConfig.tableProfiles).upsert({
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

  Future<String?> uploadIncidentVideo(String filePath, [String? rideId]) async {
    if (currentUser == null) return null;
    final fileName = 'incident_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final path = '${currentUser!.id}/$fileName';
    final file = File(filePath);
    
    try {
      await client.storage.from(SupabaseConfig.bucketIncidentVideos).upload(path, file);
      
      // Cleanup local cache to free up memory
      if (await file.exists()) {
        await file.delete();
      }
      
      return client.storage.from(SupabaseConfig.bucketIncidentVideos).getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload video error: $e');
      return null;
    }
  }
}
