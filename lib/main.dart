import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:eyeon/app.dart';
import 'package:eyeon/core/services/preference_service.dart';

import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize locale data for date formatting (id_ID/id)
  await initializeDateFormatting('id', null);

  // Load environment variables from .env safely
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('DotEnv Load Error: $e');
  }

  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    debugPrint('Supabase Init Error: $e');
  }

  // Initialize Preferences safely
  try {
    await PreferenceService().init();
  } catch (e) {
    debugPrint('Preferences Init Error: $e');
  }

  runApp(const MyApp());
}
