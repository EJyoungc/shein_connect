enum UserRole {
  customer,
  admin;

  static UserRole fromString(String? value) {
    if (value == 'admin') return UserRole.admin;
    return UserRole.customer;
  }
}

class ProfileModel {
  final String id;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.role = UserRole.customer,
    this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'role': role.name,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? fullName,
    String? phoneNumber,
    UserRole? role,
  }) {
    return ProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }
}
