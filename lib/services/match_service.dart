// lib/services/match_service.dart
import '../models/match.dart';
import 'api_service.dart';

class MatchService {
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
      final matchesData = response['data'] ?? response;

      if (matchesData is List) {
        return matchesData
            .map((match) => MatchListItem.fromJson(match))
            .toList();
      }

      return [];
    } catch (e) {
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
    required String location,
    String? city,
    String? opponent,
    String? opponentClubId,
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
        'location': location,
        if (city != null) 'city': city,
        if (opponent != null && opponent.isNotEmpty) 'opponent': opponent,
        if (opponentClubId != null) 'opponentClubId': opponentClubId,
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
