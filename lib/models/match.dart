import 'team.dart';

class MatchListItem {
  final String id;
  final String clubId;
  final String type;
  final String location;
  final String? opponent;
  final String? notes;
  final int spots;
  final DateTime matchDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hideUntilRSVP;
  final DateTime? rsvpAfterDate;
  final DateTime? rsvpBeforeDate;
  final bool notifyMembers;
  final bool isCancelled;
  final String? cancellationReason;
  final bool isSquadReleased;
  final double totalExpensed;
  final double paidAmount;
  final ClubModel club;
  final bool canSeeDetails;
  final bool canRsvp;
  final int availableSpots;
  final int confirmedPlayers;
  final MatchRSVPSimple? userRsvp;
  final Team? team;
  final Team? opponentTeam;

  MatchListItem({
    required this.id,
    required this.clubId,
    required this.type,
    required this.location,
    this.opponent,
    this.notes,
    required this.spots,
    required this.matchDate,
    required this.createdAt,
    required this.updatedAt,
    required this.hideUntilRSVP,
    this.rsvpAfterDate,
    this.rsvpBeforeDate,
    required this.notifyMembers,
    required this.isCancelled,
    this.cancellationReason,
    required this.isSquadReleased,
    required this.totalExpensed,
    required this.paidAmount,
    required this.club,
    required this.canSeeDetails,
    required this.canRsvp,
    required this.availableSpots,
    required this.confirmedPlayers,
    this.userRsvp,
    this.team,
    this.opponentTeam,
  });

  factory MatchListItem.fromJson(Map<String, dynamic> json) {
    return MatchListItem(
      id: json['id'] ?? '',
      clubId: json['club']?['id'] ?? '', // Extract from club object
      type: json['type'] ?? '',
      location: json['location'] ?? '',
      opponent: json['opponent'] ?? json['opponentClub']?['name'], // Use opponent or opponentClub name
      notes: json['notes'],
      spots: json['spots'] ?? 13,
      matchDate: DateTime.parse(json['matchDate']),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
      hideUntilRSVP: json['hideUntilRSVP'] ?? false,
      rsvpAfterDate: json['rsvpAfterDate'] != null ? DateTime.parse(json['rsvpAfterDate']) : null,
      rsvpBeforeDate: json['rsvpBeforeDate'] != null ? DateTime.parse(json['rsvpBeforeDate']) : null,
      notifyMembers: json['notifyMembers'] ?? true,
      isCancelled: json['isCancelled'] ?? false,
      cancellationReason: json['cancellationReason'],
      isSquadReleased: json['isSquadReleased'] ?? false,
      totalExpensed: (json['totalExpensed'] ?? 0).toDouble(),
      paidAmount: (json['paidAmount'] ?? 0).toDouble(),
      club: ClubModel.fromJson(json['club'] ?? {}),
      canSeeDetails: json['canSeeDetails'] ?? true,
      canRsvp: json['canRsvp'] ?? true,
      availableSpots: json['availableSpots'] ?? (json['spots'] ?? 13),
      confirmedPlayers: json['confirmedPlayers'] ?? 0,
      userRsvp: json['userRsvp'] != null ? MatchRSVPSimple.fromJson(json['userRsvp']) : null,
      team: json['team'] != null ? Team.fromJson(json['team']) : null,
      opponentTeam: json['opponentTeam'] != null ? Team.fromJson(json['opponentTeam']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clubId': clubId,
      'type': type,
      'location': location,
      'opponent': opponent,
      'notes': notes,
      'spots': spots,
      'matchDate': matchDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hideUntilRSVP': hideUntilRSVP,
      'rsvpAfterDate': rsvpAfterDate?.toIso8601String(),
      'rsvpBeforeDate': rsvpBeforeDate?.toIso8601String(),
      'notifyMembers': notifyMembers,
      'isCancelled': isCancelled,
      'cancellationReason': cancellationReason,
      'isSquadReleased': isSquadReleased,
      'totalExpensed': totalExpensed,
      'paidAmount': paidAmount,
      'club': club.toJson(),
      'canSeeDetails': canSeeDetails,
      'canRsvp': canRsvp,
      'availableSpots': availableSpots,
      'confirmedPlayers': confirmedPlayers,
      'userRsvp': userRsvp?.toJson(),
      'team': team?.toJson(),
      'opponentTeam': opponentTeam?.toJson(),
    };
  }
}

class MatchRSVPSimple {
  final String id;
  final String status;
  final String? selectedRole;
  final bool isConfirmed;
  final int? waitlistPosition;
  final String? teamId;

  MatchRSVPSimple({
    required this.id,
    required this.status,
    this.selectedRole,
    required this.isConfirmed,
    this.waitlistPosition,
    this.teamId,
  });

  factory MatchRSVPSimple.fromJson(Map<String, dynamic> json) {
    return MatchRSVPSimple(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      selectedRole: json['selectedRole'],
      isConfirmed: json['isConfirmed'] ?? false,
      waitlistPosition: json['waitlistPosition'],
      teamId: json['teamId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'selectedRole': selectedRole,
      'isConfirmed': isConfirmed,
      'waitlistPosition': waitlistPosition,
      'teamId': teamId,
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
      id: json['id'] ?? '',
      name: json['name'] ?? '',
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
