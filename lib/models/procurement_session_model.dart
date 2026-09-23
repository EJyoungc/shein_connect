enum SessionStatus {
  open('OPEN'),
  locked('LOCKED'),
  purchased('PURCHASED'),
  inTransit('IN_TRANSIT'),
  readyForPickup('READY_FOR_PICKUP'),
  closed('CLOSED');

  final String dbValue;
  const SessionStatus(this.dbValue);

  static SessionStatus fromDbValue(String? value) {
    for (final status in SessionStatus.values) {
      if (status.dbValue == value) return status;
    }
    return SessionStatus.open;
  }

  String get displayName {
    switch (this) {
      case SessionStatus.open:
        return 'Open for Orders';
      case SessionStatus.locked:
        return 'Session Locked';
      case SessionStatus.purchased:
        return 'Order Placed with SheIn';
      case SessionStatus.inTransit:
        return 'In Transit to Malawi';
      case SessionStatus.readyForPickup:
        return 'Ready for Pickup';
      case SessionStatus.closed:
        return 'Session Completed';
    }
  }

  bool get canAcceptOrders => this == SessionStatus.open;
}

class ProcurementSessionModel {
  final String id;
  final String sessionCode;
  final double exchangeRate;
  final SessionStatus status;
  final double targetAmountUsd;
  final DateTime? createdAt;

  const ProcurementSessionModel({
    required this.id,
    required this.sessionCode,
    required this.exchangeRate,
    this.status = SessionStatus.open,
    this.targetAmountUsd = 0.0,
    this.createdAt,
  });

  factory ProcurementSessionModel.fromJson(Map<String, dynamic> json) {
    return ProcurementSessionModel(
      id: json['id'] as String,
      sessionCode: json['session_code'] as String? ?? '',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1750.0,
      status: SessionStatus.fromDbValue(json['status'] as String?),
      targetAmountUsd: (json['target_amount_usd'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_code': sessionCode,
      'exchange_rate': exchangeRate,
      'status': status.dbValue,
      'target_amount_usd': targetAmountUsd,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  double calculateLocalPrice(double usdPrice) {
    return usdPrice * exchangeRate;
  }
}
