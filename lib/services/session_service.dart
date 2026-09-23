import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_config.dart';
import '../core/errors/app_logger.dart';
import '../core/services/supabase_service.dart';
import '../models/cart_item_model.dart';
import '../models/payment_detail_model.dart';
import '../models/procurement_session_model.dart';
import '../models/session_order_model.dart';

/// Central service managing procurement sessions and orders linked directly to Supabase.
/// Provides full management capabilities for Administrators and Customers.
class SessionService extends ChangeNotifier {
  // Sessions & user state
  List<ProcurementSessionModel> _sessions = [];
  ProcurementSessionModel? _activeSession;
  List<SessionOrderModel> _userOrders = [];
  bool _isLoading = false;

  // Admin specific state
  List<SessionOrderModel> _allOrders = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isAdminLoading = false;

  // Payment Details state
  List<PaymentDetailModel> _paymentDetails = [];
  bool _isPaymentDetailsLoading = false;

  // Getters
  List<ProcurementSessionModel> get sessions => List.unmodifiable(_sessions);
  ProcurementSessionModel? get activeSession => _activeSession;
  List<SessionOrderModel> get userOrders => List.unmodifiable(_userOrders);
  List<SessionOrderModel> get allOrders => List.unmodifiable(_allOrders);
  List<Map<String, dynamic>> get customers => List.unmodifiable(_customers);
  List<PaymentDetailModel> get paymentDetails => List.unmodifiable(_paymentDetails);
  List<PaymentDetailModel> get activePaymentDetails => List.unmodifiable(_paymentDetails.where((p) => p.isActive));
  bool get isLoading => _isLoading;
  bool get isAdminLoading => _isAdminLoading;
  bool get isPaymentDetailsLoading => _isPaymentDetailsLoading;

  // Admin calculated KPI metrics
  double get totalRevenueMwk => _allOrders
      .where((o) => o.paymentStatus == PaymentStatus.paid)
      .fold(0.0, (sum, o) => sum + o.totalCostLocal);

  int get pendingApprovalsCount => _allOrders
      .where((o) => o.paymentStatus == PaymentStatus.verifying || o.paymentStatus == PaymentStatus.pendingPayment)
      .length;

  int get totalOrdersCount => _allOrders.length;

  SessionService() {
    loadSessions();
    loadUserOrders();
    loadPaymentDetails();
  }

  /// Fetches all procurement sessions directly from Supabase public.procurement_sessions.
  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();

    if (AppConfig.isSupabaseConfigured) {
      try {
        final supa = SupabaseService.clientOrNull;
        if (supa != null) {
          final data = await supa
              .from('procurement_sessions')
              .select()
              .order('created_at', ascending: false);

          _sessions = (data as List)
              .map((row) => ProcurementSessionModel.fromJson(row as Map<String, dynamic>))
              .toList();

          if (_sessions.isNotEmpty) {
            _activeSession = _sessions.firstWhere(
              (s) => s.status == SessionStatus.open,
              orElse: () => _sessions.first,
            );
          } else {
            _activeSession = null;
          }
        }
      } catch (e) {
        AppLogger.warning('Error loading procurement sessions from Supabase: $e', 'SessionService');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Sets the currently inspected active session
  void setActiveSession(ProcurementSessionModel session) {
    _activeSession = session;
    notifyListeners();
  }

  // ===========================================================================
  // ADMIN ACTIONS (Linked directly to Supabase)
  // ===========================================================================

  /// Admin: Create a new procurement batch session directly in Supabase
  Future<({bool success, String message})> createSession({
    required String sessionCode,
    required double exchangeRate,
    required double targetAmountUsd,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      return (success: false, message: 'Supabase is not configured.');
    }

    final code = sessionCode.trim().toUpperCase();
    if (code.isEmpty) {
      return (success: false, message: 'Please enter a valid session batch code.');
    }
    if (exchangeRate <= 0) {
      return (success: false, message: 'Please enter a valid exchange rate (MWK/USD).');
    }

    try {
      final supa = SupabaseService.client;
      await supa.from('procurement_sessions').insert({
        'session_code': code,
        'exchange_rate': exchangeRate,
        'target_amount_usd': targetAmountUsd,
        'status': 'OPEN',
      });

      await loadSessions();
      return (success: true, message: 'Procurement session "$code" created successfully!');
    } catch (e) {
      AppLogger.error('Error creating procurement session', e, null, 'SessionService');
      return (success: false, message: 'Failed to create session: $e');
    }
  }

  /// Admin: Update session details (code, exchange rate, target amount, status) directly in Supabase
  Future<({bool success, String message})> updateSession({
    required String sessionId,
    required String sessionCode,
    required double exchangeRate,
    required double targetAmountUsd,
    SessionStatus? status,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      return (success: false, message: 'Supabase is not configured.');
    }

    final code = sessionCode.trim().toUpperCase();
    if (code.isEmpty) {
      return (success: false, message: 'Please enter a valid session batch code.');
    }
    if (exchangeRate <= 0) {
      return (success: false, message: 'Please enter a valid exchange rate (MWK/USD).');
    }
    if (targetAmountUsd < 0) {
      return (success: false, message: 'Please enter a valid target amount.');
    }

    try {
      final supa = SupabaseService.client;
      final updateData = <String, dynamic>{
        'session_code': code,
        'exchange_rate': exchangeRate,
        'target_amount_usd': targetAmountUsd,
      };

      if (status != null) {
        updateData['status'] = status.dbValue;
      }

      await supa
          .from('procurement_sessions')
          .update(updateData)
          .eq('id', sessionId);

      await loadSessions();
      return (success: true, message: 'Session "$code" updated successfully!');
    } catch (e) {
      AppLogger.error('Error updating session', e, null, 'SessionService');
      return (success: false, message: 'Failed to update session: $e');
    }
  }

  /// Admin: Update the lifecycle status of a session (OPEN, LOCKED, PURCHASED, etc.)
  Future<({bool success, String message})> updateSessionStatus({
    required String sessionId,
    required SessionStatus newStatus,
  }) async {
    try {
      final supa = SupabaseService.client;
      await supa
          .from('procurement_sessions')
          .update({'status': newStatus.dbValue})
          .eq('id', sessionId);

      await loadSessions();
      return (success: true, message: 'Session status updated to ${newStatus.displayName}');
    } catch (e) {
      AppLogger.error('Error updating session status', e, null, 'SessionService');
      return (success: false, message: 'Failed to update session status: $e');
    }
  }

  /// Admin: Delete a procurement session
  Future<({bool success, String message})> deleteSession(String sessionId) async {
    try {
      final supa = SupabaseService.client;
      await supa.from('procurement_sessions').delete().eq('id', sessionId);
      await loadSessions();
      return (success: true, message: 'Session deleted successfully.');
    } catch (e) {
      AppLogger.error('Error deleting session', e, null, 'SessionService');
      return (success: false, message: 'Failed to delete session: $e');
    }
  }

  /// Admin: Fetch all customer orders across all procurement sessions from Supabase
  Future<void> loadAllOrders() async {
    _isAdminLoading = true;
    notifyListeners();

    if (AppConfig.isSupabaseConfigured) {
      try {
        final supa = SupabaseService.clientOrNull;
        if (supa != null) {
          final data = await supa
              .from('session_orders')
              .select('*, order_items(*), profiles!user_id(full_name, phone_number, email), procurement_sessions!session_id(session_code, status)')
              .order('created_at', ascending: false);

          _allOrders = (data as List).map((row) {
            final rawItems = row['order_items'] as List<dynamic>? ?? [];
            final items = rawItems
                .map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
                .toList();
            return SessionOrderModel.fromJson(row as Map<String, dynamic>, items);
          }).toList();
        }
      } catch (e) {
        // Fallback to separate queries if relational syntax is restricted by view
        try {
          final supa = SupabaseService.client;
          final ordersData = await supa
              .from('session_orders')
              .select('*, order_items(*)')
              .order('created_at', ascending: false);

          final List<SessionOrderModel> temp = [];
          for (final row in (ordersData as List)) {
            final rawItems = row['order_items'] as List<dynamic>? ?? [];
            final items = rawItems
                .map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
                .toList();
            temp.add(SessionOrderModel.fromJson(row as Map<String, dynamic>, items));
          }
          _allOrders = temp;
        } catch (err) {
          AppLogger.error('Error loading all orders for admin', err, null, 'SessionService');
        }
      }
    }

    _isAdminLoading = false;
    notifyListeners();
  }

  /// Admin: Move an order to a different procurement session
  Future<({bool success, String message})> moveOrderToSession({
    required String orderId,
    required String targetSessionId,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      return (success: false, message: 'Supabase is not configured.');
    }

    try {
      final supa = SupabaseService.client;
      await supa
          .from('session_orders')
          .update({'session_id': targetSessionId})
          .eq('id', orderId);

      await loadAllOrders();
      await loadUserOrders();
      return (success: true, message: 'Order reassigned to selected procurement session.');
    } catch (e) {
      AppLogger.error('Error moving order to session', e, null, 'SessionService');
      return (success: false, message: 'Failed to move order: $e');
    }
  }

  /// Admin: Verify or update payment status of a customer order
  Future<({bool success, String message})> updateOrderPaymentStatus({
    required String orderId,
    required PaymentStatus status,
  }) async {
    try {
      final supa = SupabaseService.client;
      await supa
          .from('session_orders')
          .update({'payment_status': status.dbValue})
          .eq('id', orderId);

      await loadAllOrders();
      await loadUserOrders();
      return (success: true, message: 'Order payment status updated to ${status.displayName}');
    } catch (e) {
      AppLogger.error('Error updating payment status', e, null, 'SessionService');
      return (success: false, message: 'Failed to update payment status: $e');
    }
  }

  /// Admin: Fetch registered customers from Supabase public.profiles
  Future<void> loadCustomers() async {
    if (!AppConfig.isSupabaseConfigured) return;
    try {
      final supa = SupabaseService.clientOrNull;
      if (supa != null) {
        final data = await supa
            .from('profiles')
            .select()
            .order('created_at', ascending: false);
        _customers = List<Map<String, dynamic>>.from(data as List);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('Error loading customers list: $e', 'SessionService');
    }
  }

  /// Admin: Generates consolidated line items for a session to buy in bulk on Shein
  List<ConsolidatedProcurementItem> getConsolidatedItemsForSession(String sessionId) {
    final sessionOrders = _allOrders.where(
      (o) => o.sessionId == sessionId && (o.paymentStatus == PaymentStatus.paid || o.paymentStatus == PaymentStatus.verifying),
    );

    final Map<String, ConsolidatedProcurementItem> map = {};
    for (final order in sessionOrders) {
      for (final item in order.items) {
        final key = '${item.productUrl}_${item.selectedOption ?? ""}';
        if (map.containsKey(key)) {
          final existing = map[key]!;
          map[key] = existing.copyWith(
            quantity: existing.quantity + item.quantity,
            totalUsd: existing.totalUsd + (item.priceUsd * item.quantity),
            totalLocal: existing.totalLocal + (item.priceLocal * item.quantity),
          );
        } else {
          map[key] = ConsolidatedProcurementItem(
            productName: item.productName,
            productUrl: item.productUrl,
            imageUrl: item.imageUrl,
            selectedOption: item.selectedOption,
            unitPriceUsd: item.priceUsd,
            quantity: item.quantity,
            totalUsd: item.priceUsd * item.quantity,
            totalLocal: item.priceLocal * item.quantity,
          );
        }
      }
    }
    return map.values.toList();
  }

  // ===========================================================================
  // CUSTOMER ORDER ACTIONS (Linked directly to Supabase)
  // ===========================================================================

  /// Submits an order for the given session directly to Supabase.
  Future<({bool success, String message, String? orderId})> submitOrder({
    required String sessionId,
    required List<CartItem> cartItems,
    required double exchangeRate,
  }) async {
    if (cartItems.isEmpty) {
      return (success: false, message: 'Cart is empty. Add products before submitting.', orderId: null);
    }

    final supa = SupabaseService.clientOrNull;
    final userId = supa?.auth.currentUser?.id;
    final subtotalUsd = cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);
    final totalLocal = subtotalUsd * exchangeRate;

    if (AppConfig.isSupabaseConfigured && supa != null && userId != null) {
      try {
        // Verify session is OPEN
        final sessionCheck = await supa
            .from('procurement_sessions')
            .select('status')
            .eq('id', sessionId)
            .maybeSingle();

        if (sessionCheck != null && sessionCheck['status'] != 'OPEN') {
          return (
            success: false,
            message: 'Cannot place order: this procurement session is locked or closed.',
            orderId: null
          );
        }

        // Insert order header
        final orderRes = await supa.from('session_orders').insert({
          'session_id': sessionId,
          'user_id': userId,
          'total_cost_local': totalLocal,
          'payment_status': 'PENDING_PAYMENT',
        }).select('id').single();

        final orderId = orderRes['id'] as String;

        // Snapshot line items
        final orderItemsPayload = cartItems.map((item) => {
              'order_id': orderId,
              'product_name': item.name,
              'product_url': item.url,
              'image_url': item.imageUrl ?? '',
              'price_usd': item.numericPrice,
              'price_local': item.numericPrice * exchangeRate,
              'quantity': item.quantity,
              'selected_option': item.variation ?? '',
            }).toList();

        await supa.from('order_items').insert(orderItemsPayload);

        // Clear remote cart items if they exist
        try {
          await supa.from('cart_items').delete().eq('user_id', userId);
        } catch (_) {}

        await loadUserOrders();
        return (
          success: true,
          message: 'Order submitted to Supabase! Please upload proof of payment.',
          orderId: orderId
        );
      } catch (e) {
        AppLogger.error('Order submission error', e, null, 'SessionService');
        return (success: false, message: 'Order submission failed: $e', orderId: null);
      }
    }

    return (success: false, message: 'Please sign in with Supabase to submit your order.', orderId: null);
  }

  /// Attach proof of payment URL to an order
  Future<({bool success, String message})> submitPaymentProof({
    required String orderId,
    required String proofUrl,
  }) async {
    try {
      final supa = SupabaseService.client;
      await supa.from('session_orders').update({
        'proof_of_payment_url': proofUrl,
        'payment_status': 'VERIFYING',
      }).eq('id', orderId);

      await loadUserOrders();
      await loadAllOrders();
      return (success: true, message: 'Proof of payment submitted. Verification in progress.');
    } catch (e) {
      AppLogger.error('Proof submission error', e, null, 'SessionService');
      return (success: false, message: 'Failed to submit proof: $e');
    }
  }

  /// Upload image bytes to Supabase storage 'payment_proofs' bucket
  /// and update the order's proof_of_payment_url and status to 'VERIFYING'.
  Future<({bool success, String message, String? url})> uploadProofOfPayment({
    required String orderId,
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      return (success: false, message: 'Supabase is not configured.', url: null);
    }

    try {
      final supa = SupabaseService.client;
      final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
      final fileName = '${orderId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';
      final path = 'receipts/$fileName';

      await supa.storage.from('payment_proofs').uploadBinary(
        path,
        imageBytes,
        fileOptions: FileOptions(
          contentType: cleanExt == 'png' ? 'image/png' : 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = supa.storage.from('payment_proofs').getPublicUrl(path);

      await supa.from('session_orders').update({
        'proof_of_payment_url': publicUrl,
        'payment_status': 'VERIFYING',
      }).eq('id', orderId);

      await loadUserOrders();
      await loadAllOrders();

      return (
        success: true,
        message: 'Proof of payment uploaded successfully! Receipt is now in verification.',
        url: publicUrl,
      );
    } catch (e) {
      AppLogger.error('Proof upload error', e, null, 'SessionService');
      return (success: false, message: 'Failed to upload proof of payment: $e', url: null);
    }
  }

  /// Customer or Admin: Remove / Cancel an order directly from Supabase
  /// Enforces that normal users cannot delete orders once the session is locked or closed.
  Future<({bool success, String message})> deleteUserOrder(
    String orderId, {
    bool isAdmin = false,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      return (success: false, message: 'Supabase is not configured.');
    }

    try {
      final supa = SupabaseService.client;

      if (!isAdmin) {
        final orderRow = await supa
            .from('session_orders')
            .select('session_id, procurement_sessions!session_id(status)')
            .eq('id', orderId)
            .maybeSingle();

        if (orderRow != null) {
          final sessionData = orderRow['procurement_sessions'] as Map<String, dynamic>?;
          final statusStr = sessionData?['status'] as String?;
          final status = SessionStatus.fromDbValue(statusStr);
          if (status != SessionStatus.open) {
            return (
              success: false,
              message: 'This order cannot be removed because session batch is ${status.displayName}.',
            );
          }
        }
      }

      // Foreign key CASCADE automatically removes corresponding order_items
      await supa.from('session_orders').delete().eq('id', orderId);

      await loadUserOrders();
      await loadAllOrders();
      return (success: true, message: 'Order removed successfully.');
    } catch (e) {
      AppLogger.error('Error removing order', e, null, 'SessionService');
      return (success: false, message: 'Failed to remove order: $e');
    }
  }

  /// Loads the authenticated user's submitted orders from Supabase.
  Future<void> loadUserOrders() async {
    final supa = SupabaseService.clientOrNull;
    final userId = supa?.auth.currentUser?.id;
    if (AppConfig.isSupabaseConfigured && supa != null && userId != null) {
      try {
        final data = await supa
            .from('session_orders')
            .select('*, order_items(*), procurement_sessions!session_id(session_code, status)')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final List<SessionOrderModel> temp = [];
        for (final orderRow in (data as List)) {
          final rawItems = orderRow['order_items'] as List<dynamic>? ?? [];
          final items = rawItems
              .map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
              .toList();
          temp.add(SessionOrderModel.fromJson(orderRow as Map<String, dynamic>, items));
        }
        _userOrders = temp;
        notifyListeners();
      } catch (e) {
        AppLogger.error('Error loading user orders', e, null, 'SessionService');
      }
    }
  }

  // ===========================================================================
  // PAYMENT DETAILS METHODS (Customers view & copy, Admin adds/edits/removes)
  // ===========================================================================

  /// Loads payment details from Supabase public.payment_details.
  Future<void> loadPaymentDetails() async {
    _isPaymentDetailsLoading = true;
    notifyListeners();

    final supa = SupabaseService.clientOrNull;
    if (AppConfig.isSupabaseConfigured && supa != null) {
      try {
        final data = await supa
            .from('payment_details')
            .select()
            .order('created_at', ascending: true);

        _paymentDetails = (data as List)
            .map((row) => PaymentDetailModel.fromJson(row as Map<String, dynamic>))
            .toList();
      } catch (e) {
        AppLogger.error('Error loading payment details', e, null, 'SessionService');
      }
    }

    _isPaymentDetailsLoading = false;
    notifyListeners();
  }

  /// Admin: Adds a new payment detail (bank, airtel_money, mpamba).
  Future<bool> addPaymentDetail({
    required PaymentDetailType type,
    required String accountName,
    required String accountNumber,
    String? bankName,
    String? branchName,
    String? instructions,
    bool isActive = true,
  }) async {
    final supa = SupabaseService.clientOrNull;
    if (!AppConfig.isSupabaseConfigured || supa == null) return false;

    try {
      final payload = {
        'type': type.dbValue,
        'account_name': accountName.trim(),
        'account_number': accountNumber.trim(),
        'bank_name': type == PaymentDetailType.bank ? bankName?.trim() : null,
        'branch_name': type == PaymentDetailType.bank ? branchName?.trim() : null,
        'instructions': instructions?.trim(),
        'is_active': isActive,
      };

      await supa.from('payment_details').insert(payload);
      await loadPaymentDetails();
      return true;
    } catch (e) {
      AppLogger.error('Error adding payment detail', e, null, 'SessionService');
      return false;
    }
  }

  /// Admin: Updates an existing payment detail.
  Future<bool> updatePaymentDetail({
    required String id,
    required PaymentDetailType type,
    required String accountName,
    required String accountNumber,
    String? bankName,
    String? branchName,
    String? instructions,
    required bool isActive,
  }) async {
    final supa = SupabaseService.clientOrNull;
    if (!AppConfig.isSupabaseConfigured || supa == null) return false;

    try {
      final payload = {
        'type': type.dbValue,
        'account_name': accountName.trim(),
        'account_number': accountNumber.trim(),
        'bank_name': type == PaymentDetailType.bank ? bankName?.trim() : null,
        'branch_name': type == PaymentDetailType.bank ? branchName?.trim() : null,
        'instructions': instructions?.trim(),
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supa.from('payment_details').update(payload).eq('id', id);
      await loadPaymentDetails();
      return true;
    } catch (e) {
      AppLogger.error('Error updating payment detail', e, null, 'SessionService');
      return false;
    }
  }

  /// Admin: Removes a payment detail.
  Future<bool> deletePaymentDetail(String id) async {
    final supa = SupabaseService.clientOrNull;
    if (!AppConfig.isSupabaseConfigured || supa == null) return false;

    try {
      await supa.from('payment_details').delete().eq('id', id);
      await loadPaymentDetails();
      return true;
    } catch (e) {
      AppLogger.error('Error deleting payment detail', e, null, 'SessionService');
      return false;
    }
  }
}

/// Helper model for aggregated procurement batch line items
class ConsolidatedProcurementItem {
  final String productName;
  final String productUrl;
  final String imageUrl;
  final String? selectedOption;
  final double unitPriceUsd;
  final int quantity;
  final double totalUsd;
  final double totalLocal;

  const ConsolidatedProcurementItem({
    required this.productName,
    required this.productUrl,
    required this.imageUrl,
    this.selectedOption,
    required this.unitPriceUsd,
    required this.quantity,
    required this.totalUsd,
    required this.totalLocal,
  });

  ConsolidatedProcurementItem copyWith({
    int? quantity,
    double? totalUsd,
    double? totalLocal,
  }) {
    return ConsolidatedProcurementItem(
      productName: productName,
      productUrl: productUrl,
      imageUrl: imageUrl,
      selectedOption: selectedOption,
      unitPriceUsd: unitPriceUsd,
      quantity: quantity ?? this.quantity,
      totalUsd: totalUsd ?? this.totalUsd,
      totalLocal: totalLocal ?? this.totalLocal,
    );
  }
}
