// lib/services/match_service.dart
import '../models/match.dart';
import 'api_service.dart';

class MatchService {
  /// Transform match data from API to MatchListItem format
  static Map<String, dynamic> _transformUserMatch(dynamic match) {
    final matchMap = match as Map<String, dynamic>;

    return {
      ...matchMap,
      // Ensure location is a string (API returns it as location field)
      'location': matchMap['location'] ?? '',
      // Add missing fields with defaults
      'spots': matchMap['spots'] ?? 13,
      'hideUntilRSVP': matchMap['hideUntilRSVP'] ?? false,
      'notifyMembers': matchMap['notifyMembers'] ?? true,
      'isSquadReleased': matchMap['isSquadReleased'] ?? false,
      'totalExpensed': matchMap['totalExpensed'] ?? 0.0,
      'paidAmount': matchMap['paidAmount'] ?? 0.0,
      'canSeeDetails': matchMap['canSeeDetails'] ?? true,
      'canRsvp': matchMap['canRsvp'] ?? true, // Enable RSVP for matches
      'availableSpots': matchMap['availableSpots'] ?? matchMap['spots'] ?? 13,
      'isCancelled': matchMap['isCancelled'] ?? false,
      'cancellationReason': matchMap['cancellationReason'],
      'confirmedPlayers': matchMap['confirmedPlayers'] ?? 0,
      // Use the club field from API response, handle both user and club match formats
      'club':
          matchMap['club'] ??
          {
            'id': matchMap['clubId'] ?? matchMap['club']?['id'] ?? '',
            'name': matchMap['club']?['name'] ?? 'Unknown Club',
            'logo': matchMap['club']?['logo'],
            'city': matchMap['city'] ?? matchMap['club']?['city'],
            'membershipFeeCurrency':
                matchMap['club']?['membershipFeeCurrency'] ?? 'USD',
          },
      'team': matchMap['team'] ?? matchMap['homeTeam'],
      'opponentTeam': matchMap['opponentTeam'] ?? matchMap['awayTeam'],
      // Handle opponentClub format from club-specific matches
      'opponent': matchMap['opponent'] ?? matchMap['opponentClub']?['name'],
      // Add default timestamps if missing
      'createdAt': matchMap['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': matchMap['updatedAt'] ?? DateTime.now().toIso8601String(),
    };
  }

  /// Fetch user's matches from /matches endpoint with me=true
  static Future<List<MatchListItem>> getUserMatches({
    bool includeCancelled = false,
    bool showFullyPaid = false,
    bool upcomingOnly = false,
  }) async {
    try {
      final params = <String>[];
      params.add('me=true');
      params.add('includeCancelled=${includeCancelled ? 'true' : 'false'}');
      params.add('showFullyPaid=${showFullyPaid ? 'true' : 'false'}');
      params.add('upcomingOnly=${upcomingOnly ? 'true' : 'false'}');

      final endpoint = '/matches?${params.join('&')}';

      final response = await ApiService.get(endpoint);
      final matchesData = response['matches'] ?? response['data'] ?? response;

      if (matchesData is List) {
        try {
          return matchesData
              .map((match) => _transformUserMatch(match))
              .map((match) => MatchListItem.fromJson(match))
              .toList();
        } catch (e) {
          print('❌ MatchService Error parsing matches: $e');
          return [];
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch user matches: $e');
    }
  }

  /// Fetch matches for a specific club or all user's matches
  static Future<List<MatchListItem>> getMatches({
    String? clubId,
    bool includeCancelled = false,
    bool showFullyPaid = false,
    bool upcomingOnly = false,
    int limit = 50,
    int offset = 0,
    String? type, // 'match' or 'practice'
  }) async {
    try {
      String endpoint;

      // If we have a specific club, use the admin matches endpoint
      if (clubId != null) {
        final params = <String>[];
        params.add('clubId=$clubId');
        params.add('includeCancelled=${includeCancelled ? 'true' : 'false'}');
        params.add('showFullyPaid=${showFullyPaid ? 'true' : 'false'}');
        params.add('upcomingOnly=${upcomingOnly ? 'true' : 'false'}');
        params.add('limit=$limit');
        params.add('offset=$offset');
        if (type != null) {
          params.add('type=$type');
        }

        endpoint = '/matches?${params.join('&')}';
      } else {
        // For user matches, use the RSVP endpoint
        final userParams = ['me=true', 'limit=$limit', 'offset=$offset'];
        if (type != null) {
          userParams.add('type=$type');
        }
        endpoint = '/matches?${userParams.join('&')}';
      }

      final response = await ApiService.get(endpoint);

      // Handle different response formats based on endpoint
      List<dynamic> matchesData;
      if (clubId != null) {
        // Club-specific matches endpoint returns { matches: [...] }
        matchesData = response['matches'] ?? [];
      } else {
        // User RSVP endpoint returns { data: [...] } or direct array
        matchesData = response['data'] ?? response ?? [];
      }

      try {
        if (clubId != null) {
          // For club matches, transform them similar to user matches
          return matchesData
              .map((match) => _transformUserMatch(match))
              .map((match) => MatchListItem.fromJson(match))
              .toList();
        } else {
          // For user matches from RSVP endpoint, parse directly
          return matchesData
              .map((match) => MatchListItem.fromJson(match))
              .toList();
        }
      } catch (e) {
        print('❌ MatchService Error parsing matches: $e');
        return [];
      }
    } catch (e) {
      print('❌ MatchService Error fetching matches: $e');
      throw Exception('Failed to fetch matches: $e');
    }
  }

  /// Get detailed match information from the matches endpoint
  static Future<Map<String, dynamic>> getMatchDetail(String matchId) async {
    try {
      final response = await ApiService.get('/matches/$matchId');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch match details: $e');
    }
  }

  /// Fetch a single match for a specific club to access opponent/team metadata
  static Future<Map<String, dynamic>?> getClubMatch({
    required String clubId,
    required String matchId,
  }) async {
    try {
      final params = <String>[
        'clubId=$clubId',
        'includeCancelled=true',
        'showFullyPaid=true',
        'upcomingOnly=false',
        'limit=100',
      ];

      final response = await ApiService.get('/matches?${params.join('&')}');
      final matches = response['matches'];

      if (matches is List) {
        for (final match in matches) {
          if (match is Map<String, dynamic> && match['id'] == matchId) {
            return match;
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ MatchService Error fetching club match: $e');
      return null;
    }
  }

  /// Create a new match (admin/owner only)
  static Future<Map<String, dynamic>> createMatch({
    required String clubId,
    required String type,
    required String locationId,
    String? city,
    String? opponent,
    String? opponentClubId,
    String? teamId,
    String? opponentTeamId,
    String? notes,
    required DateTime matchDate,
    int spots = 13,
    bool hideUntilRSVP = false,
    DateTime? rsvpAfterDate,
    DateTime? rsvpBeforeDate,
    bool notifyMembers = true,
    String? tournamentId,
    String? bookingId,
  }) async {
    try {
      final data = {
        'clubId': clubId,
        'type': type,
        'locationId': locationId,
        if (city != null) 'city': city,
        if (opponent != null && opponent.isNotEmpty) 'opponent': opponent,
        if (opponentClubId != null) 'opponentClubId': opponentClubId,
        if (teamId != null) 'teamId': teamId,
        if (opponentTeamId != null) 'opponentTeamId': opponentTeamId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'matchDate': matchDate.toIso8601String(),
        'spots': spots,
        'hideUntilRSVP': hideUntilRSVP,
        if (rsvpAfterDate != null)
          'rsvpAfterDate': rsvpAfterDate.toIso8601String(),
        if (rsvpBeforeDate != null)
          'rsvpBeforeDate': rsvpBeforeDate.toIso8601String(),
        'notifyMembers': notifyMembers,
        if (tournamentId != null) 'tournamentId': tournamentId,
        if (bookingId != null) 'bookingId': bookingId,
      };

      final response = await ApiService.post('/matches', data);
      return response;
    } catch (e) {
      throw Exception('Failed to create match: $e');
    }
  }

  /// RSVP to a match
  static Future<Map<String, dynamic>> rsvpToMatch({
    required String matchId,
    required String status,
    String? selectedRole,
  }) async {
    try {
      final data = {
        'matchId': matchId,
        'status': status,
        if (selectedRole != null) 'selectedRole': selectedRole,
      };

      final response = await ApiService.post('/rsvp', data);
      return response;
    } catch (e) {
      throw Exception('Failed to RSVP to match: $e');
    }
  }

  /// Cancel RSVP for a match
  static Future<Map<String, dynamic>> cancelRsvp(String matchId) async {
    try {
      final response = await ApiService.delete('/rsvp?matchId=$matchId');
      return response;
    } catch (e) {
      throw Exception('Failed to cancel RSVP: $e');
    }
  }

  /// Check if user can create matches for a club (admin/owner role check)
  static Future<bool> canCreateMatches(String clubId) async {
    try {
      return true;
      // final response = await ApiService.get('/profile');
      // final userData = response['user'];
      // final clubs = userData['clubs'] as List?;

      // if (clubs == null) return false;

      // // Check if user has admin or owner role in the specified club
      // return clubs.any((club) {
      //   return club['clubId'] == clubId &&
      //          (club['role'] == 'ADMIN' || club['role'] == 'OWNER');
      // });
    } catch (e) {
      return false; // Default to false if we can't verify permissions
    }
  }

  /// Get available match types
  static List<String> getMatchTypes() {
    return [
      'League',
      'Friendly',
      'Practice',
      'Tournament',
      'Cup',
      'Championship',
    ];
  }

  /// Get available player roles
  static List<String> getPlayerRoles() {
    return [
      'Any Position',
      'Batsman',
      'Bowler',
      'All-rounder',
      'Wicket Keeper',
      'Captain',
    ];
  }
}
