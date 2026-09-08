class UserModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String phoneNumber;
  final String nic;
  final String address;
  final String? profilePicture;
  final bool pinEnabled;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.phoneNumber,
    required this.nic,
    required this.address,
    this.profilePicture,
    required this.pinEnabled,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      role: json['role'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      nic: json['nic'] ?? '',
      address: json['address'] ?? '',
      profilePicture: json['profile_picture'],
      pinEnabled: json['pin_enabled'] ?? false,
    );
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
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