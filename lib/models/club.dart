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
  final List<ClubMember> owners;
  final LatestMessage? latestMessage;

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
    this.owners = const [],
    this.latestMessage,
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
      membersCount: json['_count']?['members'] ?? json['membersCount'] ?? json['memberCount'],
      owners: (json['owners'] as List?)
          ?.map((owner) => ClubMember.fromJson(owner as Map<String, dynamic>))
          .toList() ?? [],
      latestMessage: json['latestMessage'] != null 
          ? LatestMessage.fromJson(json['latestMessage'])
          : null,
    );
  }

  Club copyWith({
    String? id,
    String? name,
    String? description,
    String? logo,
    String? website,
    String? contactEmail,
    String? contactPhone,
    String? city,
    String? state,
    String? country,
    bool? isVerified,
    double? membershipFee,
    String? membershipFeeDescription,
    String? membershipFeeCurrency,
    String? upiId,
    String? upiIdDescription,
    String? upiIdCurrency,
    bool? isActive,
    int? membersCount,
    List<ClubMember>? owners,
    LatestMessage? latestMessage,
  }) {
    return Club(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logo: logo ?? this.logo,
      website: website ?? this.website,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      isVerified: isVerified ?? this.isVerified,
      membershipFee: membershipFee ?? this.membershipFee,
      membershipFeeDescription: membershipFeeDescription ?? this.membershipFeeDescription,
      membershipFeeCurrency: membershipFeeCurrency ?? this.membershipFeeCurrency,
      upiId: upiId ?? this.upiId,
      upiIdDescription: upiIdDescription ?? this.upiIdDescription,
      upiIdCurrency: upiIdCurrency ?? this.upiIdCurrency,
      isActive: isActive ?? this.isActive,
      membersCount: membersCount ?? this.membersCount,
      owners: owners ?? this.owners,
      latestMessage: latestMessage ?? this.latestMessage,
    );
  }
}

class LatestMessage {
  final String id;
  final MessageContent content;
  final DateTime createdAt;
  final String senderName;
  final String senderId;
  final bool isRead;

  LatestMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.senderName,
    required this.senderId,
    required this.isRead,
  });

  factory LatestMessage.fromJson(Map<String, dynamic> json) {
    // Handle isRead with proper null safety
    bool isReadValue = true; // Default to read if not specified
    if (json['isRead'] != null) {
      if (json['isRead'] is bool) {
        isReadValue = json['isRead'];
      } else if (json['isRead'] is String) {
        isReadValue = json['isRead'].toLowerCase() == 'true';
      }
    }

    return LatestMessage(
      id: json['id'] ?? '',
      content: MessageContent.fromJson(json['content'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      senderName: json['senderName'] ?? '',
      senderId: json['senderId'] ?? '',
      isRead: isReadValue,
    );
  }

  LatestMessage copyWith({
    String? id,
    MessageContent? content,
    DateTime? createdAt,
    String? senderName,
    String? senderId,
    bool? isRead,
  }) {
    return LatestMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderId: senderId ?? this.senderId,
      isRead: isRead ?? this.isRead,
    );
  }
}

class MessageContent {
  final String body;
  final String type;

  MessageContent({
    required this.body,
    required this.type,
  });

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(
      body: json['body'] ?? '',
      type: json['type'] ?? 'text',
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

  ClubMembership copyWith({
    String? role,
    bool? approved,
    bool? isActive,
    bool? isBanned,
    double? balance,
    double? totalExpenses,
    int? points,
    Club? club,
  }) {
    return ClubMembership(
      role: role ?? this.role,
      approved: approved ?? this.approved,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      balance: balance ?? this.balance,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      points: points ?? this.points,
      club: club ?? this.club,
    );
  }

  /// Helper method to check if club has unread messages
  bool get hasUnreadMessage {
    return club.latestMessage?.isRead == false;
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
