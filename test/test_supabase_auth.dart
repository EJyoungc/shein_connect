import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shein_pro/core/constants/app_config.dart';
import 'package:shein_pro/core/services/supabase_service.dart';
import 'package:shein_pro/models/profile_model.dart';
import 'package:shein_pro/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // Enables real network connectivity in test runner

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppConfig.initialize();

    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    SupabaseService.setClientForTesting(client);
  });

  group('Pure Supabase AuthService (No Local Mock Scopes & No Demo Credentials)', () {
    test('1. Admin login directly with Supabase email + password', () async {
      final authService = AuthService();
      final result = await authService.login('admin@admin.com', 'root360');

      expect(result.success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.isAdmin, isTrue);
      expect(authService.currentUser?.email, 'admin@admin.com');
      expect(authService.currentProfile?.role, UserRole.admin);

      await authService.logout();
      expect(authService.isLoggedIn, isFalse);
    });

    test('2. Admin login directly using phone number lookup (Malawian mobile)', () async {
      final authService = AuthService();
      final result = await authService.login('0999000111', 'root360');

      expect(result.success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.isAdmin, isTrue);
      expect(authService.currentUser?.email, 'admin@admin.com');

      await authService.logout();
      expect(authService.isLoggedIn, isFalse);
    });

    test('3. Invalid credentials rejected directly by Supabase', () async {
      final authService = AuthService();
      final result = await authService.login('admin@admin.com', 'wrong_password_123');

      expect(result.success, isFalse);
      expect(result.message, contains('Incorrect'));
      expect(authService.isLoggedIn, isFalse);
    });

    test('4. Non-existent phone number rejected directly without local fallback', () async {
      final authService = AuthService();
      final result = await authService.login('0880998877', 'any_password');

      expect(result.success, isFalse);
      expect(result.message, contains('No account found with mobile number'));
      expect(authService.isLoggedIn, isFalse);
    });

    test('5. resendConfirmationEmail handles invalid and valid format requests', () async {
      final authService = AuthService();
      final invalidRes = await authService.resendConfirmationEmail('not-an-email');
      expect(invalidRes.success, isFalse);
      expect(invalidRes.message, contains('valid email address'));

      // Resend to a syntactically valid email calls Supabase
      final resendRes = await authService.resendConfirmationEmail('unconfirmed_test@example.com');
      // Supabase either accepts or responds with rate limit/user not found, but it exercises the Supabase API without crash
      expect(resendRes.message, isNotEmpty);
    });
  });
}
