enum PaymentDetailType {
  bank('bank', 'Bank Transfer'),
  airtelMoney('airtel_money', 'Airtel Money'),
  mpamba('mpamba', 'TNM Mpamba');

  final String dbValue;
  final String label;
  const PaymentDetailType(this.dbValue, this.label);

  static PaymentDetailType fromDb(String? val) {
    if (val == 'airtel_money') return PaymentDetailType.airtelMoney;
    if (val == 'mpamba') return PaymentDetailType.mpamba;
    return PaymentDetailType.bank;
  }
}

class PaymentDetailModel {
  final String id;
  final PaymentDetailType type;
  final String accountName;
  final String accountNumber;
  final String? bankName;
  final String? branchName;
  final String? instructions;
  final bool isActive;
  final DateTime? createdAt;

  const PaymentDetailModel({
    required this.id,
    required this.type,
    required this.accountName,
    required this.accountNumber,
    this.bankName,
    this.branchName,
    this.instructions,
    this.isActive = true,
    this.createdAt,
  });

  factory PaymentDetailModel.fromJson(Map<String, dynamic> json) {
    return PaymentDetailModel(
      id: json['id']?.toString() ?? '',
      type: PaymentDetailType.fromDb(json['type']?.toString()),
      accountName: json['account_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      bankName: json['bank_name']?.toString(),
      branchName: json['branch_name']?.toString(),
      instructions: json['instructions']?.toString(),
      isActive: json['is_active'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.dbValue,
      'account_name': accountName,
      'account_number': accountNumber,
      'bank_name': bankName,
      'branch_name': branchName,
      'instructions': instructions,
      'is_active': isActive,
    };
  }

  String get title {
    switch (type) {
      case PaymentDetailType.bank:
        return bankName != null && bankName!.isNotEmpty ? bankName! : 'Bank Transfer';
      case PaymentDetailType.airtelMoney:
        return 'Airtel Money';
      case PaymentDetailType.mpamba:
        return 'TNM Mpamba';
    }
  }
}
