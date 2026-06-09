// This file contains the schema definitions for reference.
// Note: These tables must be created manually in the Supabase SQL Editor
// using the script provided in `supabase/schema.sql`.

class AppDatabaseSchema {
  static const String emergencyContactsTable = 'emergency_contacts';
  static const String incidentLogsTable = 'incident_logs';
  static const String rideLogsTable = 'ride_logs';
  static const String profilesTable = 'profiles';

  // Columns for emergency_contacts
  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colName = 'name';
  static const String colPhone = 'phone';
  static const String colTelegramChatId = 'telegram_chat_id';
  static const String colUpdatedAt = 'updated_at';

  // Columns for incident_logs
  static const String colLat = 'latitude';
  static const String colLng = 'longitude';
  static const String colMagnitude = 'magnitude';
  static const String colTimestamp = 'timestamp';
  static const String colRideId = 'ride_id';
  static const String colVideoUrl = 'video_url';

  // Columns for ride_logs
  static const String colStartTime = 'start_time';
  static const String colEndTime = 'end_time';
  static const String colMicrosleepAlerts = 'microsleep_alerts';
  static const String colAccidentAlerts = 'accident_alerts';
  static const String colDistance = 'distance';

  // Columns for profiles
  static const String colFullName = 'full_name';
  static const String colBloodType = 'blood_type';
  static const String colAddress = 'address';
  static const String colOrigin = 'origin';
  static const String colEmergencyMedicalNotes = 'emergency_medical_notes';
  static const String colEarThreshold = 'ear_threshold';
  static const String colShockSensitivity = 'shock_sensitivity';
  static const String colAlarmSound = 'alarm_sound';
  static const String colSaveToGallery = 'save_to_gallery';
}
