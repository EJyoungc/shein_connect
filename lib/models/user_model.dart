class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final String gender;
  final String? password;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.gender,
    this.password,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'mobile': mobile,
        'gender': gender,
        'password': password,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        password: json['password'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? mobile,
    String? gender,
    String? password,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      gender: gender ?? this.gender,
      password: password ?? this.password,
      createdAt: createdAt,
    );
  }
}
