// lib/services/match_service.dart
import '../models/match.dart';
import 'api_service.dart';

class MatchService {
  /// Transform user match data from /matches?me=true API to MatchListItem format
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
      'canRsvp': matchMap['canRsvp'] ?? true, // Enable RSVP for user matches
      'availableSpots': matchMap['availableSpots'] ?? 0,
      'confirmedPlayers': matchMap['confirmedPlayers'] ?? 0,
      // Use the club field from API response
      'club': matchMap['club'] ?? {
        'id': matchMap['clubId'],
        'name': 'Unknown Club',
        'logo': null,
        'city': matchMap['city'],
        'membershipFeeCurrency': 'USD',
      },
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
      
      print('🔍 MatchService Debug: Fetching user matches from: $endpoint');
      
      final response = await ApiService.get(endpoint);
      final matchesData = response['matches'] ?? response['data'] ?? response;

      if (matchesData is List) {
        print('🔍 MatchService Debug: Number of matches received = ${matchesData.length}');
        if (matchesData.isNotEmpty) {
          print('🔍 MatchService Debug: First match structure = ${matchesData[0]}');
        }
        
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

        print('🔍 MatchService Debug: Fetching club matches for clubId = $clubId');
        print('🔍 MatchService Debug: upcomingOnly parameter = $upcomingOnly');
        print(
          '🔍 MatchService Debug: Final endpoint = /matches?${params.join('&')}',
        );

        endpoint = '/matches?${params.join('&')}';
      } else {
        // For user matches, use the RSVP endpoint
        endpoint = '/rsvp';
      }

      final response = await ApiService.get(endpoint);
      
      // Handle different response formats based on endpoint
      List<dynamic> matchesData;
      if (clubId != null) {
        // Club-specific matches endpoint returns { matches: [...] }
        matchesData = response['matches'] ?? [];
        print('🔍 MatchService Debug: Club matches response structure = ${response.keys.toList()}');
        print('🔍 MatchService Debug: Number of club matches received = ${matchesData.length}');
      } else {
        // User RSVP endpoint returns { data: [...] } or direct array
        matchesData = response['data'] ?? response ?? [];
      }

      if (matchesData is List) {
        if (matchesData.isNotEmpty && clubId != null) {
          print('🔍 MatchService Debug: First club match structure = ${matchesData[0]}');
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
          print('❌ MatchService Error parsing club matches: $e');
          if (matchesData.isNotEmpty) {
            print('🔍 MatchService Debug: Sample match data causing error: ${matchesData[0]}');
          }
          return [];
        }
      }

      return [];
    } catch (e) {
      print('❌ MatchService Error fetching matches: $e');
      throw Exception('Failed to fetch matches: $e');
    }
  }

  /// Get detailed match information
  static Future<Map<String, dynamic>> getMatchDetail(String matchId) async {
    try {
      final response = await ApiService.get('/rsvp?matchId=$matchId');
      return response['match'] ?? {};
    } catch (e) {
      throw Exception('Failed to fetch match details: $e');
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

      // Debug logging for match creation
      print('🔍 MatchService Debug: Request data = $data');

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
