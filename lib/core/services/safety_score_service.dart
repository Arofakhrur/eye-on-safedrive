import 'package:eyeon/core/services/supabase_service.dart';

/// Service for calculating and managing the Safety Score (0-100).
///
/// Scoring algorithm:
/// - Base score: 100
/// - Per microsleep alert: -5
/// - Per accident alert: -15
/// - Per clean ride (0 alerts): +2
/// - Clamped to range [0, 100]
class SafetyScoreService {
  static final SafetyScoreService _instance = SafetyScoreService._internal();
  factory SafetyScoreService() => _instance;
  SafetyScoreService._internal();

  static const int _baseSore = 100;
  static const int _microsleepPenalty = -5;
  static const int _accidentPenalty = -15;
  static const int _cleanRideBonus = 2;

  /// Calculate the user's current safety score from ride history.
  Future<int> calculateSafetyScore() async {
    final breakdown = await getScoreBreakdown();
    return breakdown['score'] as int;
  }

  /// Get a detailed breakdown of the safety score components.
  Future<Map<String, dynamic>> getScoreBreakdown() async {
    final rides = await SupabaseService().getRideHistory();

    int totalRides = rides.length;
    int totalMicrosleepAlerts = 0;
    int totalAccidentAlerts = 0;
    int cleanRides = 0;

    for (final ride in rides) {
      final microsleep = (ride['microsleep_alerts'] ?? 0) as int;
      final accidents = (ride['accident_alerts'] ?? 0) as int;
      totalMicrosleepAlerts += microsleep;
      totalAccidentAlerts += accidents;
      if (microsleep == 0 && accidents == 0) {
        cleanRides++;
      }
    }

    final microsleepTotal = totalMicrosleepAlerts * _microsleepPenalty;
    final accidentTotal = totalAccidentAlerts * _accidentPenalty;
    final cleanTotal = cleanRides * _cleanRideBonus;

    int rawScore = _baseSore + microsleepTotal + accidentTotal + cleanTotal;
    int finalScore = rawScore.clamp(0, 100);

    return {
      'score': finalScore,
      'totalRides': totalRides,
      'totalMicrosleepAlerts': totalMicrosleepAlerts,
      'totalAccidentAlerts': totalAccidentAlerts,
      'cleanRides': cleanRides,
      'microsleepPenalty': microsleepTotal,
      'accidentPenalty': accidentTotal,
      'cleanBonus': cleanTotal,
    };
  }

  /// Get a label for the score range.
  static String getScoreLabel(int score) {
    if (score >= 80) return 'Sangat Aman';
    if (score >= 60) return 'Cukup Aman';
    if (score >= 40) return 'Perlu Perhatian';
    if (score >= 20) return 'Berisiko';
    return 'Bahaya';
  }
}
