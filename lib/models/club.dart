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
  final bool? isActive;
  final int? membersCount;

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
    this.isActive,
    this.membersCount,
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
      upiIdCurrency:
          json['upiIdCurrency'] ?? json['membershipFeeCurrency'] ?? 'INR',
      isActive: json['isActive'],
      membersCount: json['_count']?['members'] ?? json['membersCount'],
    );
  }
}

class ClubMembership {
  final String role;
  final bool approved;
  final bool isActive;
  final bool isBanned;
  final double balance;
  final double totalExpenses;
  final int points;
  final Club club;

  ClubMembership({
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

class ClubMember {
  final String id;
  final String name;
  final String? profilePicture;

  ClubMember({required this.id, required this.name, this.profilePicture});

  factory ClubMember.fromJson(Map<String, dynamic> json) {
    return ClubMember(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      profilePicture: json['profilePicture'],
    );
  }
}

class DetailedClubInfo {
  final String id;
  final String name;
  final String? slug;
  final String? logo;
  final String? description;
  final String url;
  final int membersCount;
  final List<ClubMember> owners;
  final List<ClubMember> admins;
  final String? upiId;
  final String? upiIdDescription;
  final String upiIdCurrency;
  final double? membershipFee;
  final String membershipFeeCurrency;
  final String? membershipFeeDescription;
  final int? defaultPinDurationHours;
  final List<String> pinMessagePermissions;

  DetailedClubInfo({
    required this.id,
    required this.name,
    this.slug,
    this.logo,
    this.description,
    required this.url,
    required this.membersCount,
    required this.owners,
    required this.admins,
    this.upiId,
    this.upiIdDescription,
    required this.upiIdCurrency,
    this.membershipFee,
    required this.membershipFeeCurrency,
    this.membershipFeeDescription,
    this.defaultPinDurationHours,
    required this.pinMessagePermissions,
  });

  factory DetailedClubInfo.fromJson(Map<String, dynamic> json) {
    return DetailedClubInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'],
      logo: json['logo'],
      description: json['description'],
      url: json['url'] ?? '',
      membersCount: json['membersCount'] ?? 0,
      owners: (json['owners'] as List? ?? [])
          .map((owner) => ClubMember.fromJson(owner as Map<String, dynamic>))
          .toList(),
      admins: (json['admins'] as List? ?? [])
          .map((admin) => ClubMember.fromJson(admin as Map<String, dynamic>))
          .toList(),
      upiId: json['upiId'],
      upiIdDescription: json['upiIdDescription'],
      upiIdCurrency: json['upiIdCurrency'] ?? 'INR',
      membershipFee: json['membershipFee']?.toDouble(),
      membershipFeeCurrency: json['membershipFeeCurrency'] ?? 'INR',
      membershipFeeDescription: json['membershipFeeDescription'],
      defaultPinDurationHours: json['defaultPinDurationHours'],
      pinMessagePermissions: List<String>.from(
        json['pinMessagePermissions'] ?? [],
      ),
    );
  }
}
