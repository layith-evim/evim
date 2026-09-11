import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service to manage Supabase client lifecycle and environment credentials.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initializes Supabase using loaded .env credentials
  static Future<void> initialize() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();

    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      throw StateError('SUPABASE_URL is missing or empty in .env');
    }

    if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is missing or empty in .env');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );
  }

  /// Current authenticated user (nullable)
  static User? get currentUser => client.auth.currentUser;

  /// Whether a user session currently exists
  static bool get isAuthenticated => currentUser != null;
}
