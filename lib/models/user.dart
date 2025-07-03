class User {
  final String id;
  final String phoneNumber;
  final String name;
  final String? email;
  final String? profilePicture;
  final String? city;
  final String? state;
  final String? country;
  final bool isVerified;
  final bool isProfileComplete;
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
    required this.isVerified,
    required this.isProfileComplete,
    required this.balance,
    required this.totalExpenses,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      name: json['name'],
      email: json['email'],
      profilePicture: json['profilePicture'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      isVerified: json['isVerified'] ?? false,
      isProfileComplete: json['isProfileComplete'] ?? false,
      balance: (json['balance'] ?? 0).toDouble(),
      totalExpenses: (json['totalExpenses'] ?? 0).toDouble(),
    );
  }
}
