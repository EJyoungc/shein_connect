import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shein_pro/core/constants/app_config.dart';
import 'package:shein_pro/core/services/supabase_service.dart';
import 'package:shein_pro/models/cart_item_model.dart';
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

  group('Supabase Normal User Orders & Removal Flow', () {
    test('1. User can submit order and fetch it via loadUserOrders', () async {
      final authService = AuthService();
      final loginRes = await authService.login('admin@admin.com', 'root360');
      expect(loginRes.success, isTrue);

      final sessionService = SessionService();
      await sessionService.loadSessions();
      expect(sessionService.sessions, isNotEmpty);
      final activeSession = sessionService.activeSession!;

      // Create a test cart item
      final testItem = CartItem(
        id: 'test_item_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Shein Floral Dress Test',
        url: 'https://shein.top/test',
        imageUrl: 'https://img.shein.com/test.jpg',
        price: '\$15.00',
        numericPrice: 15.0,
        quantity: 2,
        variation: 'Size: M',
      );

      // Submit order
      final submitRes = await sessionService.submitOrder(
        sessionId: activeSession.id,
        cartItems: [testItem],
        exchangeRate: activeSession.exchangeRate,
      );
      expect(submitRes.success, isTrue);
      expect(submitRes.orderId, isNotNull);

      // Verify order is visible in loadUserOrders
      await sessionService.loadUserOrders();
      final foundOrder = sessionService.userOrders.any((o) => o.id == submitRes.orderId);
      expect(foundOrder, isTrue);

      // Verify user can upload payment proof
      final uploadRes1 = await sessionService.uploadProofOfPayment(
        orderId: submitRes.orderId!,
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        fileExtension: 'jpg',
      );
      expect(uploadRes1.success, isTrue);
      expect(uploadRes1.url, isNotNull);

      // Verify user can re-upload / change payment proof
      final uploadRes2 = await sessionService.uploadProofOfPayment(
        orderId: submitRes.orderId!,
        imageBytes: Uint8List.fromList([5, 6, 7, 8, 9]),
        fileExtension: 'png',
      );
      expect(uploadRes2.success, isTrue);
      expect(uploadRes2.url, isNotNull);

      // Verify user can remove their own order
      final deleteRes = await sessionService.deleteUserOrder(submitRes.orderId!);
      expect(deleteRes.success, isTrue);

      // Verify order is removed from userOrders list
      final stillExists = sessionService.userOrders.any((o) => o.id == submitRes.orderId);
      expect(stillExists, isFalse);

      await authService.logout();
    });
  });
}
