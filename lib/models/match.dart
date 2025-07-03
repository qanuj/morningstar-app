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
    );
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

  MatchRSVP({
    required this.id,
    required this.status,
    this.selectedRole,
    this.waitlistPosition,
    required this.isConfirmed,
    required this.isCaptain,
    required this.isWicketKeeper,
    this.notes,
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
    );
  }
}
