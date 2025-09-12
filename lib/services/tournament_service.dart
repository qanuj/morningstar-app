import '../services/api_service.dart';

class Tournament {
  final String id;
  final String name;
  final String description;
  final String location;
  final String city;
  final String venue;
  final DateTime startDate;
  final DateTime endDate;
  final bool isOwned;
  final TournamentOrganizer organizer;
  final String? teamName;
  final String registrationStatus;

  Tournament({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.city,
    required this.venue,
    required this.startDate,
    required this.endDate,
    required this.isOwned,
    required this.organizer,
    this.teamName,
    required this.registrationStatus,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      city: json['city'] ?? '',
      venue: json['venue'] ?? '',
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
      isOwned: json['isOwned'] ?? false,
      organizer: TournamentOrganizer.fromJson(json['organizer'] ?? {}),
      teamName: json['teamName'],
      registrationStatus: json['registrationStatus'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location,
      'city': city,
      'venue': venue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isOwned': isOwned,
      'organizer': organizer.toJson(),
      'teamName': teamName,
      'registrationStatus': registrationStatus,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tournament &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TournamentOrganizer {
  final String id;
  final String name;
  final String? logo;

  TournamentOrganizer({
    required this.id,
    required this.name,
    this.logo,
  });

  factory TournamentOrganizer.fromJson(Map<String, dynamic> json) {
    return TournamentOrganizer(
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TournamentOrganizer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TournamentService {
  /// Get tournaments for a club (owned tournaments)
  static Future<List<Tournament>> getClubTournaments(String clubId) async {
    try {
      final response = await ApiService.get('/clubs/$clubId/tournaments');

      if (response['tournaments'] is List) {
        return (response['tournaments'] as List)
            .map((json) => Tournament.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return (response as List)
            .map((json) => Tournament.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching club tournaments: $e');
      return [];
    }
  }

  /// Get participating tournaments for a club
  static Future<List<Tournament>> getParticipatingTournaments(String clubId) async {
    try {
      final response = await ApiService.get('/clubs/$clubId/participating-tournaments');

      if (response['data'] is List) {
        return (response['data'] as List)
            .map((json) => Tournament.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return (response as List)
            .map((json) => Tournament.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching participating tournaments: $e');
      return [];
    }
  }
}