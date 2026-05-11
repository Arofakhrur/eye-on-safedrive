import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eyeon/app.dart';
import 'package:eyeon/core/services/preference_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://ultznlqcxxzsskegcubw.supabase.co',
      anonKey: 'sb_publishable_cWI9XkzCFZeJBt6v9jTK7A_4dpClbhB',
    );
  } catch (e) {
    debugPrint('Supabase Init Error: $e');
  }

  // Initialize Preferences
  await PreferenceService().init();

  runApp(const MyApp());
}
