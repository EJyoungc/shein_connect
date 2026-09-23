import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shein_pro/core/constants/app_config.dart';
import 'package:shein_pro/core/services/supabase_service.dart';
import 'package:shein_pro/models/procurement_session_model.dart';
import 'package:shein_pro/services/auth_service.dart';
import 'package:shein_pro/services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

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

  group('Supabase Live Admin Dashboard & Database Linkage', () {
    test('1. Admin logs in with root360 and has admin role', () async {
      final authService = AuthService();
      final loginRes = await authService.login('admin@admin.com', 'root360');

      expect(loginRes.success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.isAdmin, isTrue);
      print('✓ Admin login and role check: PASSED');
    });

    test('2. SessionService loads live procurement sessions from Supabase', () async {
      final sessionService = SessionService();
      await sessionService.loadSessions();

      expect(sessionService.sessions, isNotEmpty);
      expect(sessionService.activeSession, isNotNull);
      print('✓ Loaded ${sessionService.sessions.length} sessions from Supabase');
      print('  Active session: ${sessionService.activeSession?.sessionCode} (status: ${sessionService.activeSession?.status.displayName})');
    });

    test('3. Admin can create and update session status directly in Supabase', () async {
      final sessionService = SessionService();
      final testBatchCode = 'TEST-BATCH-${DateTime.now().millisecondsSinceEpoch % 10000}';

      // Create session
      final createRes = await sessionService.createSession(
        sessionCode: testBatchCode,
        exchangeRate: 1750.0,
        targetAmountUsd: 1200.0,
      );
      expect(createRes.success, isTrue);
      print('✓ Admin created session: $testBatchCode');

      // Find created session
      final createdSession = sessionService.sessions.firstWhere((s) => s.sessionCode == testBatchCode);
      expect(createdSession.status, SessionStatus.open);

      // Update status to LOCKED
      final updateRes = await sessionService.updateSessionStatus(
        sessionId: createdSession.id,
        newStatus: SessionStatus.locked,
      );
      expect(updateRes.success, isTrue);

      final updatedSession = sessionService.sessions.firstWhere((s) => s.id == createdSession.id);
      expect(updatedSession.status, SessionStatus.locked);
      print('✓ Admin updated session status to LOCKED');

      // Test updateSession (edit code, rate, target, and status)
      final editedBatchCode = '$testBatchCode-EDITED';
      final editRes = await sessionService.updateSession(
        sessionId: createdSession.id,
        sessionCode: editedBatchCode,
        exchangeRate: 1820.0,
        targetAmountUsd: 2500.0,
        status: SessionStatus.inTransit,
      );
      expect(editRes.success, isTrue);

      final editedSession = sessionService.sessions.firstWhere((s) => s.id == createdSession.id);
      expect(editedSession.sessionCode, editedBatchCode);
      expect(editedSession.exchangeRate, 1820.0);
      expect(editedSession.targetAmountUsd, 2500.0);
      expect(editedSession.status, SessionStatus.inTransit);
      print('✓ Admin edited session details and updated directly in Supabase');

      // Clean up test session
      await sessionService.deleteSession(createdSession.id);
      print('✓ Cleaned up test session');
    });

    test('4. Admin can load customer profiles and orders from Supabase', () async {
      final sessionService = SessionService();
      await sessionService.loadCustomers();
      await sessionService.loadAllOrders();

      expect(sessionService.customers, isNotNull);
      print('✓ Admin loaded ${sessionService.customers.length} registered profiles from Supabase');
      print('✓ Admin loaded ${sessionService.allOrders.length} orders from Supabase');
    });
  });
}
