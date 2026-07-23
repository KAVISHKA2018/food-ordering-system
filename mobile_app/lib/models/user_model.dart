class UserModel {
  final int id;
  final String username;
  final String email;
  final String role;
  final String phoneNumber;
  final String createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.phoneNumber,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'] ?? '',
      role: json['role'] ?? 'CUSTOMER',
      phoneNumber: json['phone_number'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  String get roleLabel {
    switch (role) {
      case 'CUSTOMER':
        return 'Customer';
      case 'RESTAURANT_ADMIN':
        return 'Restaurant Admin';
      case 'DELIVERY_STAFF':
        return 'Delivery Staff';
      case 'SYSTEM_ADMIN':
        return 'System Admin';
      default:
        return role;
    }
  }
}