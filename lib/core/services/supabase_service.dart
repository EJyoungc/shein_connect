import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_config.dart';

/// Central client manager for Supabase services.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient? _client;

  /// Direct handle to the initialized Supabase client.
  static SupabaseClient get client {
    if (_client == null) {
      if (Supabase.instance.isInitialized) {
        _client = Supabase.instance.client;
      } else {
        throw StateError(
          'Supabase has not been initialized. Ensure SupabaseService.initialize() has completed.',
        );
      }
    }
    return _client!;
  }

  /// Safe accessor that returns null if Supabase is not configured with real credentials.
  static SupabaseClient? get clientOrNull {
    try {
      return client;
    } catch (_) {
      return null;
    }
  }

  /// Sets client instance directly for testing or headless execution.
  @visibleForTesting
  static void setClientForTesting(SupabaseClient testClient) {
    _client = testClient;
  }

  /// Initializes the Supabase SDK with credentials from [AppConfig].
  static Future<void> initialize() async {
    if (!AppConfig.isSupabaseConfigured) {
      debugPrint(
        '[SupabaseService] Notice: Supabase credentials are placeholder. '
        'Offline mock mode will be active until real credentials are supplied.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
        debug: kDebugMode,
      );
      _client = Supabase.instance.client;
      debugPrint('[SupabaseService] Initialized successfully with ${AppConfig.supabaseUrl}');
    } catch (e, stack) {
      debugPrint('[SupabaseService] Error initializing Supabase: $e\n$stack');
    }
  }
}
