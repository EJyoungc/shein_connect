import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration and environment variable access.
///
/// Ensures no secrets are hardcoded in the application.
class AppConfig {
  AppConfig._();

  static late final String supabaseUrl;
  static late final String supabaseAnonKey;
  static late final String environment;
  static const String appVersion = '1.0.1';
  static const int buildNumber = 2;

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Loads environment variables from the bundled .env file.
  /// Safely falls back to placeholders or compile-time definitions if needed.
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      try {
        final envFile = File('.env');
        if (envFile.existsSync()) {
          dotenv.loadFromString(envString: envFile.readAsStringSync());
        }
      } catch (_) {
        debugPrint('[AppConfig] Warning: Failed to load .env file: $e');
      }
    }

    supabaseUrl = dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://placeholder.supabase.co');

    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'placeholder-anon-key');

    environment = dotenv.env['APP_ENV'] ?? 'development';
    _isInitialized = true;
  }

  static bool get isSupabaseConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseUrl.contains('placeholder') &&
        !supabaseAnonKey.contains('placeholder');
  }
}
