import '../models/match.dart';
import 'api_service.dart';
import 'match_service.dart';

class PracticeService {
  /// Create a new practice session using dedicated /api/practice endpoint
  /// (Creation uses specialized practice endpoint, fetching uses unified /api/matches)
  static Future<Map<String, dynamic>?> createPractice({
    required String clubId,
    required String title,
    required String description,
    required String practiceType,
    required DateTime practiceDate,
    required String practiceTime,
    required String venue,
    required String duration,
    required int maxParticipants,
    String? locationId,
    String? city,
    String? notes,
    bool notifyMembers = true,
  }) async {
    try {
      final requestData = {
        'clubId': clubId,
        'title': title,
        'description': description,
        'practiceType': practiceType,
        'practiceDate': practiceDate.toIso8601String(),
        'practiceTime': practiceTime,
        'venue': venue,
        'duration': duration,
        'maxParticipants': maxParticipants,
        'locationId': locationId,
        'city': city,
        'notes': notes,
        'notifyMembers': notifyMembers,
      };

      final response = await ApiService.post('/practice', requestData);
      return response;
    } catch (e) {
      print('❌ Error creating practice session: $e');
      return null;
    }
  }

  /// Get practice sessions for a club using unified matches API
  static Future<List<MatchListItem>> getPracticeSessions({
    required String clubId,
    bool includeCancelled = false,
    bool showFullyPaid = false,
    bool upcomingOnly = true,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Use MatchService with type='practice' to get practice sessions
      return await MatchService.getMatches(
        clubId: clubId,
        includeCancelled: includeCancelled,
        showFullyPaid: showFullyPaid,
        upcomingOnly: upcomingOnly,
        limit: limit,
        offset: offset,
        type: 'practice', // Filter for practice sessions only
      );
    } catch (e) {
      print('❌ Error fetching practice sessions: $e');
      return [];
    }
  }

  /// Get user's practice sessions from all clubs using unified matches API
  static Future<List<MatchListItem>> getUserPracticeSessions({
    bool includeCancelled = false,
    bool showFullyPaid = false,
    bool upcomingOnly = true,
  }) async {
    try {
      // Use MatchService.getUserMatches with type='practice' to get user's practice sessions
      return await MatchService.getUserMatches(
        includeCancelled: includeCancelled,
        showFullyPaid: showFullyPaid,
        upcomingOnly: upcomingOnly,
      ).then((matches) =>
        matches.where((match) => match.type == 'PRACTICE').toList()
      );
    } catch (e) {
      print('❌ Error fetching user practice sessions: $e');
      return [];
    }
  }

  /// RSVP to a practice session (delegates to MatchService)
  static Future<Map<String, dynamic>> rsvpToPractice({
    required String practiceId,
    required String status,
    String? selectedRole,
  }) async {
    return await MatchService.rsvpToMatch(
      matchId: practiceId,
      status: status,
      selectedRole: selectedRole,
    );
  }

  /// Cancel RSVP for a practice session (delegates to MatchService)
  static Future<Map<String, dynamic>> cancelPracticeRsvp(String practiceId) async {
    return await MatchService.cancelRsvp(practiceId);
  }
}
