// lib/models/team.dart
import 'club.dart';

class Team {
  final String id;
  final String name;
  final String? logo;
  final String sport;
  final bool isPrimary;
  final String provider;
  final String providerId;
  final DateTime createdAt;
  final bool isVerified;
  final String? city;
  final String? state;
  final String? country;
  final List<ClubMember> owners;
  final Club? club; // Optional club reference
  final String? clubId; // Optional club ID reference

  Team({
    required this.id,
    required this.name,
    this.logo,
    required this.sport,
    required this.isPrimary,
    required this.provider,
    required this.providerId,
    required this.createdAt,
    required this.isVerified,
    this.city,
    this.state,
    this.country,
    this.owners = const [],
    this.club,
    this.clubId,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'],
      sport: json['sport'] ?? '',
      isPrimary: json['isPrimary'] ?? false,
      provider: json['provider'] ?? '',
      providerId: json['providerId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isVerified: json['isVerified'] ?? false,
      city: json['city'],
      state: json['state'],
      country: json['country'],
      owners:
          (json['owners'] as List?)
              ?.map(
                (owner) => ClubMember.fromJson(owner as Map<String, dynamic>),
              )
              .toList() ??
          [],
      club: json['club'] != null ? Club.fromJson(json['club']) : null,
      clubId: json['clubId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
      'sport': sport,
      'isPrimary': isPrimary,
      'provider': provider,
      'providerId': providerId,
      'createdAt': createdAt.toIso8601String(),
      'isVerified': isVerified,
      'city': city,
      'state': state,
      'country': country,
      'clubId': clubId,
      'owners': owners
          .map(
            (owner) => {
              'id': owner.id,
              'name': owner.name,
              'profilePicture': owner.profilePicture,
            },
          )
          .toList(),
      if (club != null)
        'club': {'id': club!.id, 'name': club!.name, 'logo': club!.logo},
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? logo,
    String? sport,
    bool? isPrimary,
    String? provider,
    String? providerId,
    DateTime? createdAt,
    bool? isVerified,
    String? city,
    String? state,
    String? country,
    List<ClubMember>? owners,
    Club? club,
    String? clubId,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      logo: logo ?? this.logo,
      sport: sport ?? this.sport,
      isPrimary: isPrimary ?? this.isPrimary,
      provider: provider ?? this.provider,
      providerId: providerId ?? this.providerId,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      owners: owners ?? this.owners,
      club: club ?? this.club,
      clubId: clubId ?? this.clubId,
    );
  }
}
