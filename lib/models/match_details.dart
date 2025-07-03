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
      rsvpAfterDate: json['rsvpAfterDate'] != null ? DateTime.parse(json['rsvpAfterDate']) : null,
      rsvpBeforeDate: json['rsvpBeforeDate'] != null ? DateTime.parse(json['rsvpBeforeDate']) : null,
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
      userRsvp: json['userRsvp'] != null ? MatchRSVP.fromJson(json['userRsvp']) : null,
      finalSquad: json['finalSquad'] != null 
        ? (json['finalSquad'] as List).map((s) => MatchRSVP.fromJson(s)).toList()
        : null,
      captain: json['captain'] != null ? MatchRSVP.fromJson(json['captain']) : null,
      wicketKeeper: json['wicketKeeper'] != null ? MatchRSVP.fromJson(json['wicketKeeper']) : null,
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

  UserModel({
    required this.id,
    required this.name,
    this.profilePicture,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePicture': profilePicture,
    };
  }
}

class ClubModel {
  final String id;
  final String name;
  final String? logo;

  ClubModel({
    required this.id,
    required this.name,
    this.logo,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'],
      name: json['name'],
      logo: json['logo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
    };
  }
}

class MatchRSVPResponse {
  final Match match;
  final RSVPCounts rsvps;
  final MatchRSVP? userRsvp;
  final RSVPCounts counts;

  MatchRSVPResponse({
    required this.match,
    required this.rsvps,
    this.userRsvp,
    required this.counts,
  });

  factory MatchRSVPResponse.fromJson(Map<String, dynamic> json) {
    return MatchRSVPResponse(
      match: Match.fromJson(json['match']),
      rsvps: RSVPCounts.fromJson(json['rsvps']),
      userRsvp: json['userRsvp'] != null ? MatchRSVP.fromJson(json['userRsvp']) : null,
      counts: RSVPCounts.fromJson(json['counts']),
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
    return RSVPCounts(
      confirmed: (json['confirmed'] as List).map((r) => MatchRSVP.fromJson(r)).toList(),
      waitlisted: (json['waitlisted'] as List).map((r) => MatchRSVP.fromJson(r)).toList(),
      declined: (json['declined'] as List).map((r) => MatchRSVP.fromJson(r)).toList(),
      maybe: (json['maybe'] as List).map((r) => MatchRSVP.fromJson(r)).toList(),
      pending: (json['pending'] as List).map((r) => MatchRSVP.fromJson(r)).toList(),
    );
  }
}