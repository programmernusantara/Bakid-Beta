import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static late final SupabaseClient client;
  static late final GoTrueClient auth;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://ngvsfzxbykihfsevrxup.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ndnNmenhieWtpaGZzZXZyeHVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY1MTEyMDAsImV4cCI6MjA2MjA4NzIwMH0.KauGuTHBzfGKym-C63wmmAIk900oB4PSa20rIzO8MvM',
    );
    client = Supabase.instance.client;
    auth = client.auth;
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) throw Exception('User ID not found');
    return userId;
  }
}
