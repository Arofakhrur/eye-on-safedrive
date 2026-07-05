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

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _rideLogs = [];
  List<Map<String, dynamic>> get rideLogs => _rideLogs;

  HistoryController() {
    refreshHistory();
  }

  Future<void> refreshHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _rideLogs = await SupabaseService().getRideHistory();
    } catch (e) {
      _rideLogs = [];
    }
    _isLoading = false;
    notifyListeners();
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
