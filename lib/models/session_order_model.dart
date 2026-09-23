import 'procurement_session_model.dart';

enum PaymentStatus {
  pendingPayment('PENDING_PAYMENT'),
  verifying('VERIFYING'),
  paid('PAID'),
  rejected('REJECTED');

  final String dbValue;
  const PaymentStatus(this.dbValue);

  static PaymentStatus fromDbValue(String? value) {
    for (final s in PaymentStatus.values) {
      if (s.dbValue == value) return s;
    }
    return PaymentStatus.pendingPayment;
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pendingPayment:
        return 'Pending Payment';
      case PaymentStatus.verifying:
        return 'Verifying Receipt';
      case PaymentStatus.paid:
        return 'Payment Confirmed';
      case PaymentStatus.rejected:
        return 'Payment Rejected';
    }
  }
}

class SessionOrderModel {
  final String id;
  final String sessionId;
  final String userId;
  final double totalCostLocal;
  final PaymentStatus paymentStatus;
  final String? proofOfPaymentUrl;
  final DateTime? createdAt;
  final List<OrderItemModel> items;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? sessionCode;
  final SessionStatus? sessionStatus;

  bool get canRemove => sessionStatus == null || sessionStatus == SessionStatus.open;
  bool get isSessionLocked => sessionStatus != null && sessionStatus != SessionStatus.open;

  const SessionOrderModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.totalCostLocal,
    this.paymentStatus = PaymentStatus.pendingPayment,
    this.proofOfPaymentUrl,
    this.createdAt,
    this.items = const [],
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.sessionCode,
    this.sessionStatus,
  });

  factory SessionOrderModel.fromJson(Map<String, dynamic> json, [List<OrderItemModel>? items]) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final session = json['procurement_sessions'] as Map<String, dynamic>?;

    return SessionOrderModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      totalCostLocal: (json['total_cost_local'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: PaymentStatus.fromDbValue(json['payment_status'] as String?),
      proofOfPaymentUrl: json['proof_of_payment_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      items: items ?? [],
      customerName: profile?['full_name'] as String?,
      customerPhone: profile?['phone_number'] as String?,
      customerEmail: profile?['email'] as String?,
      sessionCode: session?['session_code'] as String?,
      sessionStatus: session?['status'] != null ? SessionStatus.fromDbValue(session?['status'] as String?) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'total_cost_local': totalCostLocal,
      'payment_status': paymentStatus.dbValue,
      'proof_of_payment_url': proofOfPaymentUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class OrderItemModel {
  final String id;
  final String orderId;
  final String productName;
  final String productUrl;
  final String imageUrl;
  final double priceUsd;
  final double priceLocal;
  final int quantity;
  final String? selectedOption;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.productUrl,
    required this.imageUrl,
    required this.priceUsd,
    required this.priceLocal,
    this.quantity = 1,
    this.selectedOption,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productName: json['product_name'] as String? ?? '',
      productUrl: json['product_url'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      priceUsd: (json['price_usd'] as num?)?.toDouble() ?? 0.0,
      priceLocal: (json['price_local'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selectedOption: json['selected_option'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_name': productName,
      'product_url': productUrl,
      'image_url': imageUrl,
      'price_usd': priceUsd,
      'price_local': priceLocal,
      'quantity': quantity,
      'selected_option': selectedOption,
    };
  }
}
