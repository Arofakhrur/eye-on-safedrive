import 'package:flutter/material.dart';
import 'package:eyeon/core/services/supabase_service.dart';

class HistoryController extends ChangeNotifier {
  String _selectedCategory = 'Semua';
  String get selectedCategory => _selectedCategory;

  void setSelectedCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  Stream<List<Map<String, dynamic>>> getRideHistoryStream() {
    return SupabaseService().streamRideHistory();
  }

  List<Map<String, dynamic>> filterLogs(List<Map<String, dynamic>> logs) {
    return logs.where((log) {
      if (_selectedCategory == 'Semua') return true;
      if (_selectedCategory == 'Microsleep') {
        return (log['microsleep_alerts'] ?? 0) > 0;
      }
      if (_selectedCategory == 'Kecelakaan') {
        return (log['accident_alerts'] ?? 0) > 0;
      }
      return true;
    }).toList();
  }

  Future<List<Map<String, dynamic>>?> loadIncidentsForRide(String rideId) async {
    try {
      return await SupabaseService().getIncidentsForRide(rideId);
    } catch (e) {
      return null;
    }
  }
}
