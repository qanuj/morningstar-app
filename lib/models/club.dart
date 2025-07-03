// lib/models/club.dart
class Club {
  final String id;
  final String name;
  final String? description;
  final String? logo;
  final String? website;
  final String? contactEmail;
  final String? contactPhone;
  final String? city;
  final String? state;
  final String? country;
  final bool isVerified;
  final double membershipFee;
  final String? membershipFeeDescription;
  final String membershipFeeCurrency;
  final String? upiId;
  final String? upiIdDescription;
  final String upiIdCurrency;

  Club({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    this.website,
    this.contactEmail,
    this.contactPhone,
    this.city,
    this.state,
    this.country,
    required this.isVerified,
    required this.membershipFee,
    this.membershipFeeDescription,
    required this.membershipFeeCurrency,
    this.upiId,
    this.upiIdDescription,
    required this.upiIdCurrency,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      logo: json['logo'],
      website: json['website'],
      contactEmail: json['contactEmail'],
      contactPhone: json['contactPhone'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      isVerified: json['isVerified'] ?? false,
      membershipFee: (json['membershipFee'] ?? 0).toDouble(),
      membershipFeeDescription: json['membershipFeeDescription'],
      membershipFeeCurrency: json['membershipFeeCurrency'] ?? 'INR',
      upiId: json['upiId'],
      upiIdDescription: json['upiIdDescription'],
      upiIdCurrency: json['upiIdCurrency'] ?? 'INR',
    );
  }
}

class ClubMembership {
  final String id;
  final String role;
  final bool approved;
  final bool isActive;
  final bool isBanned;
  final double balance;
  final double totalExpenses;
  final int points;
  final Club club;

  ClubMembership({
    required this.id,
    required this.role,
    required this.approved,
    required this.isActive,
    required this.isBanned,
    required this.balance,
    required this.totalExpenses,
    required this.points,
    required this.club,
  });

  factory ClubMembership.fromJson(Map<String, dynamic> json) {
    return ClubMembership(
      id: json['id'] ?? '',
      role: json['role'] ?? 'MEMBER',
      approved: json['approved'] ?? false,
      isActive: json['isActive'] ?? false,
      isBanned: json['isBanned'] ?? false,
      balance: (json['balance'] ?? 0).toDouble(),
      totalExpenses: (json['totalExpenses'] ?? 0).toDouble(),
      points: json['points'] ?? 0,
      club: Club.fromJson(json['club'] ?? {}),
    );
  }
}