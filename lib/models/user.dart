// lib/models/user.dart
class User {
  final String id;
  final String phoneNumber;
  final String name;
  final String? email;
  final String? profilePicture;
  final String? city;
  final String? state;
  final String? country;
  final String? emergencyContact;
  final String? bio;
  final String? gender;
  final DateTime? dateOfBirth;
  final String role;
  final bool isProfileComplete;
  final String? telegramChatId;
  final String? telegramChatName;
  final DateTime? lastActive;
  final DateTime createdAt;
  final String? totpSecret;
  
  // Keep legacy fields for backward compatibility
  final bool isVerified;
  final double balance;
  final double totalExpenses;

  User({
    required this.id,
    required this.phoneNumber,
    required this.name,
    this.email,
    this.profilePicture,
    this.city,
    this.state,
    this.country,
    this.emergencyContact,
    this.bio,
    this.gender,
    this.dateOfBirth,
    required this.role,
    required this.isProfileComplete,
    this.telegramChatId,
    this.telegramChatName,
    this.lastActive,
    required this.createdAt,
    this.totpSecret,
    // Legacy fields
    this.isVerified = true,
    this.balance = 0.0,
    this.totalExpenses = 0.0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      profilePicture: json['profilePicture'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      emergencyContact: json['emergencyContact'],
      bio: json['bio'],
      gender: json['gender'],
      dateOfBirth: json['dob'] != null ? DateTime.tryParse(json['dob']) : null,
      role: json['role'] ?? 'USER',
      isProfileComplete: json['isProfileComplete'] ?? false,
      telegramChatId: json['telegramChatId'],
      telegramChatName: json['telegramChatName'],
      lastActive: json['lastActive'] != null ? DateTime.tryParse(json['lastActive']) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() : DateTime.now(),
      totpSecret: json['totpSecret'],
      // Legacy fields - keep for backward compatibility
      isVerified: json['isVerified'] ?? true, // Assume verified if not specified
      balance: (json['balance'] ?? 0).toDouble(),
      totalExpenses: (json['totalExpenses'] ?? 0).toDouble(),
    );
  }

  factory User.fromApiResponse(Map<String, dynamic> apiResponse) {
    // Handle the API response structure with nested user object
    final userJson = apiResponse['user'] ?? apiResponse;
    return User.fromJson(userJson);
  }
}