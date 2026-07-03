import 'package:flutter/material.dart';
import 'package:eyeon/core/services/supabase_service.dart';

class HomeController extends ChangeNotifier {
  String _userName = 'Rider';
  String? _avatarUrl;

  String get userName => _userName;
  String? get avatarUrl => _avatarUrl;

  HomeController() {
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final user = SupabaseService().currentUser;
    if (user != null && user.userMetadata != null) {
      final name = user.userMetadata!['full_name'] ?? user.userMetadata!['name'];
      final avatar = (user.userMetadata!['avatar_url'] ?? user.userMetadata!['picture'])
          ?.toString().replaceFirst('http://', 'https://');
      
      if (name != null) _userName = name;
      _avatarUrl = avatar;
      notifyListeners();
    }
  }
}
