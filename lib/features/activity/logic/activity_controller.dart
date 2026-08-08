import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eyeon/core/services/supabase_service.dart';

class ActivityController extends ChangeNotifier {
  String _selectedPeriod = 'Hari Ini';
  String get selectedPeriod => _selectedPeriod;

  // Processed Data
  double _totalDurationHours = 0.0;
  double _totalDistance = 0.0;
  int _totalMicrosleep = 0;
  int _totalIncidents = 0;
  List<FlSpot> _chartSpots = [];

  double get totalDurationHours => _totalDurationHours;
  double get totalDistance => _totalDistance;
  int get totalMicrosleep => _totalMicrosleep;
  int get totalIncidents => _totalIncidents;
  List<FlSpot> get chartSpots => _chartSpots;

  void setSelectedPeriod(String period) {
    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      notifyListeners();
    }
  }

  void processData(List<Map<String, dynamic>> allLogs) {
    final now = DateTime.now();
    List<Map<String, dynamic>> filteredLogs = [];

    if (_selectedPeriod == 'Hari Ini') {
      filteredLogs = allLogs.where((log) {
        final date = DateTime.parse(log['start_time']);
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      }).toList();
    } else if (_selectedPeriod == 'Minggu Ini') {
      final weekAgo = now.subtract(const Duration(days: 7));
      filteredLogs = allLogs.where((log) {
        final date = DateTime.parse(log['start_time']);
        return date.isAfter(weekAgo);
      }).toList();
    } else {
      final monthAgo = now.subtract(const Duration(days: 30));
      filteredLogs = allLogs.where((log) {
        final date = DateTime.parse(log['start_time']);
        return date.isAfter(monthAgo);
      }).toList();
    }

    // Aggregate Metrics
    double durationSecs = 0;
    double dist = 0;
    int microsleep = 0;
    int incidents = 0;
    for (var log in filteredLogs) {
      final start = DateTime.parse(log['start_time']);
      final end = DateTime.parse(log['end_time']);
      durationSecs += end.difference(start).inSeconds;

      dist += (log['distance'] ?? 0.0);
      microsleep += (log['microsleep_alerts'] ?? 0) as int;
      incidents += (log['accident_alerts'] ?? 0) as int;
    }

    _totalDurationHours = durationSecs / 3600.0;
    _totalDistance = dist;
    _totalMicrosleep = microsleep;
    _totalIncidents = incidents;

    // Build Chart Spots for "Senin - Minggu" (Waktu Berkendara)
    Map<int, double> dailyDuration = {};
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    
    final currentWeekLogs = allLogs.where((log) {
      final date = DateTime.parse(log['start_time']);
      return date.isAfter(monday.subtract(const Duration(seconds: 1))) && date.isBefore(nextMonday);
    });

    for (var log in currentWeekLogs) {
      final start = DateTime.parse(log['start_time']);
      final end = DateTime.parse(log['end_time']);
      final durationMinutes = end.difference(start).inSeconds / 60.0;
      dailyDuration[start.weekday] = (dailyDuration[start.weekday] ?? 0) + durationMinutes;
    }

    _chartSpots = [];
    for (int i = 1; i <= 7; i++) {
      _chartSpots.add(
        FlSpot(i.toDouble(), dailyDuration[i] ?? 0.0),
      );
    }
  }

  Stream<List<Map<String, dynamic>>> getRideHistoryStream() {
    return SupabaseService().streamRideHistory();
  }
}
