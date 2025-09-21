import 'team.dart';

class Match {
  final String id;
  final String type;
  final String location;
  final String? opponent;
  final String? notes;
  final int spots;
  final DateTime matchDate;
  final bool hideUntilRSVP;
  final DateTime? rsvpAfterDate;
  final DateTime? rsvpBeforeDate;
  final bool notifyMembers;
  final bool isCancelled;
  final String? cancellationReason;
  final bool isSquadReleased;
  final double totalExpensed;
  final double paidAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool canSeeDetails;
  final bool canRsvp;
  final int availableSpots;
  final int confirmedPlayers;
  final ClubModel club;
  final MatchRSVP? userRsvp;
  final List<MatchRSVP>? finalSquad;
  final MatchRSVP? captain;
  final MatchRSVP? wicketKeeper;
  final Team? team;
  final Team? opponentTeam;

  Match({
    required this.id,
    required this.type,
    required this.location,
    this.opponent,
    this.notes,
    required this.spots,
    required this.matchDate,
    required this.hideUntilRSVP,
    this.rsvpAfterDate,
    this.rsvpBeforeDate,
    required this.notifyMembers,
    required this.isCancelled,
    this.cancellationReason,
    required this.isSquadReleased,
    required this.totalExpensed,
    required this.paidAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.canSeeDetails,
    required this.canRsvp,
    required this.availableSpots,
    required this.confirmedPlayers,
    required this.club,
    this.userRsvp,
    this.finalSquad,
    this.captain,
    this.wicketKeeper,
    this.team,
    this.opponentTeam,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'],
      type: json['type'],
      location: json['location'],
      opponent: json['opponent'],
      notes: json['notes'],
      spots: json['spots'] ?? 13,
      matchDate: DateTime.parse(json['matchDate']),
      hideUntilRSVP: json['hideUntilRSVP'] ?? false,
      rsvpAfterDate: json['rsvpAfterDate'] != null
          ? DateTime.parse(json['rsvpAfterDate'])
          : null,
      rsvpBeforeDate: json['rsvpBeforeDate'] != null
          ? DateTime.parse(json['rsvpBeforeDate'])
          : null,
      notifyMembers: json['notifyMembers'] ?? true,
      isCancelled: json['isCancelled'] ?? false,
      cancellationReason: json['cancellationReason'],
      isSquadReleased: json['isSquadReleased'] ?? false,
      totalExpensed: (json['totalExpensed'] ?? 0).toDouble(),
      paidAmount: (json['paidAmount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      canSeeDetails: json['canSeeDetails'] ?? true,
      canRsvp: json['canRsvp'] ?? false,
      availableSpots: json['availableSpots'] ?? 0,
      confirmedPlayers: json['confirmedPlayers'] ?? 0,
      club: ClubModel.fromJson(json['club']),
      userRsvp: json['userRsvp'] != null
          ? MatchRSVP.fromJson(json['userRsvp'])
          : null,
      finalSquad: json['finalSquad'] != null
          ? (json['finalSquad'] as List)
                .map((s) => MatchRSVP.fromJson(s))
                .toList()
          : null,
      captain: json['captain'] != null
          ? MatchRSVP.fromJson(json['captain'])
          : null,
      wicketKeeper: json['wicketKeeper'] != null
          ? MatchRSVP.fromJson(json['wicketKeeper'])
          : null,
      team: json['team'] != null ? Team.fromJson(json['team']) : null,
      opponentTeam: json['opponentTeam'] != null
          ? Team.fromJson(json['opponentTeam'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'location': location,
      'opponent': opponent,
      'notes': notes,
      'spots': spots,
      'matchDate': matchDate.toIso8601String(),
      'hideUntilRSVP': hideUntilRSVP,
      'rsvpAfterDate': rsvpAfterDate?.toIso8601String(),
      'rsvpBeforeDate': rsvpBeforeDate?.toIso8601String(),
      'notifyMembers': notifyMembers,
      'isCancelled': isCancelled,
      'cancellationReason': cancellationReason,
      'isSquadReleased': isSquadReleased,
      'totalExpensed': totalExpensed,
      'paidAmount': paidAmount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'canSeeDetails': canSeeDetails,
      'canRsvp': canRsvp,
      'availableSpots': availableSpots,
      'confirmedPlayers': confirmedPlayers,
      'club': club.toJson(),
      'userRsvp': userRsvp?.toJson(),
      'finalSquad': finalSquad?.map((s) => s.toJson()).toList(),
      'captain': captain?.toJson(),
      'wicketKeeper': wicketKeeper?.toJson(),
      'team': team?.toJson(),
      'opponentTeam': opponentTeam?.toJson(),
    };
  }
}

class MatchRSVP {
  final String id;
  final String status;
  final String? selectedRole;
  final int? waitlistPosition;
  final bool isConfirmed;
  final bool isCaptain;
  final bool isWicketKeeper;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? user;

  MatchRSVP({
    required this.id,
    required this.status,
    this.selectedRole,
    this.waitlistPosition,
    required this.isConfirmed,
    required this.isCaptain,
    required this.isWicketKeeper,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory MatchRSVP.fromJson(Map<String, dynamic> json) {
    return MatchRSVP(
      id: json['id'],
      status: json['status'],
      selectedRole: json['selectedRole'],
      waitlistPosition: json['waitlistPosition'],
      isConfirmed: json['isConfirmed'] ?? false,
      isCaptain: json['isCaptain'] ?? false,
      isWicketKeeper: json['isWicketKeeper'] ?? false,
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'selectedRole': selectedRole,
      'waitlistPosition': waitlistPosition,
      'isConfirmed': isConfirmed,
      'isCaptain': isCaptain,
      'isWicketKeeper': isWicketKeeper,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'user': user?.toJson(),
    };
  }
}

class UserModel {
  final String id;
  final String name;
  final String? profilePicture;

  UserModel({required this.id, required this.name, this.profilePicture});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'profilePicture': profilePicture};
  }
}

class ClubModel {
  final String id;
  final String name;
  final String? logo;

  ClubModel({required this.id, required this.name, this.logo});

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(id: json['id'], name: json['name'], logo: json['logo']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'logo': logo};
  }
}

class MatchRSVPResponse {
  final Match match;
  final RSVPCounts rsvps;
  final MatchRSVP? userRsvp;
  final RSVPCounts? counts;

  MatchRSVPResponse({
    required this.match,
    required this.rsvps,
    this.userRsvp,
    this.counts,
  });

  factory MatchRSVPResponse.fromJson(Map<String, dynamic> json) {
    RSVPCounts parseCounts(dynamic value) {
      if (value is Map<String, dynamic>) {
        return RSVPCounts.fromJson(value);
      }
      if (value is List) {
        return RSVPCounts.fromList(value);
      }
      return RSVPCounts.empty();
    }

    return MatchRSVPResponse(
      match: Match.fromJson(json['match']),
      rsvps: parseCounts(json['rsvps']),
      userRsvp: json['userRsvp'] != null
          ? MatchRSVP.fromJson(json['userRsvp'])
          : null,
      counts: json['counts'] != null
          ? RSVPCounts.fromJson(json['counts'])
          : null,
    );
  }
}

class RSVPCounts {
  final List<MatchRSVP> confirmed;
  final List<MatchRSVP> waitlisted;
  final List<MatchRSVP> declined;
  final List<MatchRSVP> maybe;
  final List<MatchRSVP> pending;

  RSVPCounts({
    required this.confirmed,
    required this.waitlisted,
    required this.declined,
    required this.maybe,
    required this.pending,
  });

  factory RSVPCounts.fromJson(Map<String, dynamic> json) {
    List<MatchRSVP> parseList(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(MatchRSVP.fromJson)
            .toList();
      }
      return [];
    }

    return RSVPCounts(
      confirmed: parseList(json['confirmed']),
      waitlisted: parseList(json['waitlisted']),
      declined: parseList(json['declined']),
      maybe: parseList(json['maybe']),
      pending: parseList(json['pending']),
    );
  }

  factory RSVPCounts.empty() {
    return RSVPCounts(
      confirmed: const <MatchRSVP>[],
      waitlisted: const <MatchRSVP>[],
      declined: const <MatchRSVP>[],
      maybe: const <MatchRSVP>[],
      pending: const <MatchRSVP>[],
    );
  }

  factory RSVPCounts.fromList(List<dynamic> rsvps) {
    final confirmed = <MatchRSVP>[];
    final waitlisted = <MatchRSVP>[];
    final declined = <MatchRSVP>[];
    final maybe = <MatchRSVP>[];
    final pending = <MatchRSVP>[];

    for (final entry in rsvps.whereType<Map<String, dynamic>>()) {
      final rsvp = MatchRSVP.fromJson(entry);
      final status = rsvp.status.toUpperCase();
      switch (status) {
        case 'YES':
          confirmed.add(rsvp);
          break;
        case 'NO':
          declined.add(rsvp);
          break;
        case 'MAYBE':
          maybe.add(rsvp);
          break;
        case 'WAITLIST':
        case 'WAITLISTED':
        case 'WAITING':
          waitlisted.add(rsvp);
          break;
        default:
          pending.add(rsvp);
      }
    }

    return RSVPCounts(
      confirmed: confirmed,
      waitlisted: waitlisted,
      declined: declined,
      maybe: maybe,
      pending: pending,
    );
  }
}

class MatchDetailData {
  final String id;
  final String clubId;
  final String type;
  final String? opponent;
  final DateTime matchDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isCancelled;
  final String? cancellationReason;
  final String? duration;
  final Map<String, dynamic>? metadata;
  final String? opponentId;
  final String? teamId;
  final String? opponentTeamId;
  final MatchDetailLocation? location;
  final MatchDetailTeam? team;
  final MatchDetailTeam? opponentTeam;
  final List<MatchPreference> matchPreferences;
  final List<MatchRSVP> rsvps;

  MatchDetailData({
    required this.id,
    required this.clubId,
    required this.type,
    required this.matchDate,
    required this.createdAt,
    required this.updatedAt,
    required this.isCancelled,
    this.opponent,
    this.cancellationReason,
    this.duration,
    this.metadata,
    this.opponentId,
    this.teamId,
    this.opponentTeamId,
    this.location,
    this.team,
    this.opponentTeam,
    this.matchPreferences = const [],
    this.rsvps = const [],
  });

  factory MatchDetailData.fromJson(Map<String, dynamic> json) {
    return MatchDetailData(
      id: json['id'] ?? '',
      clubId: json['clubId'] ?? '',
      type: json['type'] ?? '',
      opponent: json['opponent'],
      matchDate: DateTime.parse(json['matchDate']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isCancelled: json['isCancelled'] ?? false,
      cancellationReason: json['cancellationReason'],
      duration: json['duration']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? (json['metadata'] as Map<String, dynamic>)
          : null,
      opponentId: json['opponentId'],
      teamId: json['teamId'],
      opponentTeamId: json['opponentTeamId'],
      location: json['location'] != null
          ? MatchDetailLocation.fromJson(json['location'])
          : null,
      team: json['team'] != null
          ? MatchDetailTeam.fromJson(json['team'])
          : null,
      opponentTeam: json['opponentTeam'] != null
          ? MatchDetailTeam.fromJson(json['opponentTeam'])
          : null,
      matchPreferences:
          (json['matchPreferences'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MatchPreference.fromJson)
              .toList() ??
          const [],
      rsvps: (json['rsvps'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MatchRSVP.fromJson)
              .toList() ??
          const [],
    );
  }
}

class MatchDetailLocation {
  final String id;
  final String name;
  final String? city;
  final String? address;
  final String? contactPerson;
  final String? contactPhone;

  MatchDetailLocation({
    required this.id,
    required this.name,
    this.city,
    this.address,
    this.contactPerson,
    this.contactPhone,
  });

  factory MatchDetailLocation.fromJson(Map<String, dynamic> json) {
    return MatchDetailLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      city: json['city'],
      address: json['address'],
      contactPerson: json['contactPerson'],
      contactPhone: json['contactPhone'],
    );
  }
}

class MatchDetailTeam {
  final String id;
  final String name;
  final String? logo;
  final String? sport;
  final String? clubId;
  final MatchDetailClub? club;
  final List<MatchDetailPlayer> squad;
  final List<MatchDetailPlayer> members;

  MatchDetailTeam({
    required this.id,
    required this.name,
    this.logo,
    this.sport,
    this.clubId,
    this.club,
    this.squad = const [],
    this.members = const [],
  });

  factory MatchDetailTeam.fromJson(Map<String, dynamic> json) {
    return MatchDetailTeam(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'],
      sport: json['sport'],
      clubId: json['clubId'],
      club: json['club'] != null
          ? MatchDetailClub.fromJson(json['club'])
          : null,
      squad:
          (json['squad'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MatchDetailPlayer.fromJson)
              .toList() ??
          const [],
      members:
          (json['members'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MatchDetailPlayer.fromJson)
              .toList() ??
          const [],
    );
  }
}

class MatchDetailClub {
  final String id;
  final String name;
  final String? logo;

  MatchDetailClub({required this.id, required this.name, this.logo});

  factory MatchDetailClub.fromJson(Map<String, dynamic> json) {
    return MatchDetailClub(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'],
    );
  }
}

class MatchDetailPlayer {
  final String id;
  final String name;
  final String? profilePicture;
  final String status;
  final bool isCaptain;
  final bool isWicketKeeper;
  final String? selectedRole;

  MatchDetailPlayer({
    required this.id,
    required this.name,
    this.profilePicture,
    this.status = 'PENDING',
    this.isCaptain = false,
    this.isWicketKeeper = false,
    this.selectedRole,
  });

  factory MatchDetailPlayer.fromJson(Map<String, dynamic> json) {
    return MatchDetailPlayer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      profilePicture: json['profilePicture'],
      status: json['status'] ?? 'PENDING',
      isCaptain: json['isCaptain'] ?? false,
      isWicketKeeper: json['isWicketKeeper'] ?? false,
      selectedRole: json['selectedRole'],
    );
  }
}

class MatchPreference {
  final String id;
  final String matchId;
  final String clubId;
  final String? notes;
  final double totalExpensed;
  final double paidAmount;
  final int spots;
  final bool hideUntilRsvp;
  final bool notifyMembers;
  final DateTime? rsvpAfterDate;
  final DateTime? rsvpBeforeDate;
  final bool isSquadReleased;
  final DateTime createdAt;
  final DateTime updatedAt;

  MatchPreference({
    required this.id,
    required this.matchId,
    required this.clubId,
    this.notes,
    required this.totalExpensed,
    required this.paidAmount,
    required this.spots,
    required this.hideUntilRsvp,
    required this.notifyMembers,
    this.rsvpAfterDate,
    this.rsvpBeforeDate,
    required this.isSquadReleased,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MatchPreference.fromJson(Map<String, dynamic> json) {
    return MatchPreference(
      id: json['id'] ?? '',
      matchId: json['matchId'] ?? '',
      clubId: json['clubId'] ?? '',
      notes: json['notes'],
      totalExpensed: (json['totalExpensed'] ?? 0).toDouble(),
      paidAmount: (json['paidAmount'] ?? 0).toDouble(),
      spots: json['spots'] ?? 0,
      hideUntilRsvp: json['hideUntilRsvp'] ?? false,
      notifyMembers: json['notifyMembers'] ?? false,
      rsvpAfterDate: json['rsvpAfterDate'] != null
          ? DateTime.parse(json['rsvpAfterDate'])
          : null,
      rsvpBeforeDate: json['rsvpBeforeDate'] != null
          ? DateTime.parse(json['rsvpBeforeDate'])
          : null,
      isSquadReleased: json['isSquadReleased'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class MatchDetailUserRsvp {
  final String id;
  final String status;
  final String? teamId;
  final String? userId;
  final bool isCaptain;
  final bool isWicketKeeper;
  final String? selectedRole;

  MatchDetailUserRsvp({
    required this.id,
    required this.status,
    this.teamId,
    this.userId,
    this.isCaptain = false,
    this.isWicketKeeper = false,
    this.selectedRole,
  });

  factory MatchDetailUserRsvp.fromJson(Map<String, dynamic> json) {
    return MatchDetailUserRsvp(
      id: json['id'] ?? '',
      status: json['status'] ?? 'PENDING',
      teamId: json['teamId'],
      userId: json['userId'],
      isCaptain: json['isCaptain'] ?? false,
      isWicketKeeper: json['isWicketKeeper'] ?? false,
      selectedRole: json['selectedRole'],
    );
  }
}
