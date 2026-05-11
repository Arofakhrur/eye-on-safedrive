/// This file contains the schema definitions for reference.
/// Note: These tables must be created manually in the Supabase SQL Editor
/// using the script provided in `supabase/schema.sql`.

class AppDatabaseSchema {
  static const String emergencyContactsTable = 'emergency_contacts';
  static const String incidentLogsTable = 'incident_logs';

  // Columns for emergency_contacts
  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colName = 'name';
  static const String colPhone = 'phone';
  static const String colUpdatedAt = 'updated_at';

  // Columns for incident_logs
  static const String colLat = 'latitude';
  static const String colLng = 'longitude';
  static const String colMagnitude = 'magnitude';
  static const String colTimestamp = 'timestamp';
}
