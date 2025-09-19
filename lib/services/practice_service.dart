import '../models/match.dart';
import 'api_service.dart';

class PracticeService {
  /// Create a new practice session
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

  /// Get practice sessions for a club
  static Future<List<MatchListItem>> getPracticeSessions({
    required String clubId,
    bool upcomingOnly = true,
    int limit = 50,
    int offset = 0,
    String? type, // 'practice' or 'match'
  }) async {
    try {
      final params = [
        'clubId=$clubId',
        'upcomingOnly=$upcomingOnly',
        'limit=$limit',
        'offset=$offset',
      ];
      if (type != null) {
        params.add('type=$type');
      }

      final response = await ApiService.get(
        '/practice?${params.join('&')}',
      );

      if (response != null && response['practices'] != null) {
        final practiceData = response['practices'] as List;
        return practiceData
            .map((data) => _transformPracticeToMatchListItem(data))
            .toList();
      }

      return [];
    } catch (e) {
      print('❌ Error fetching practice sessions: $e');
      return [];
    }
  }

  /// Transform practice data to MatchListItem format for compatibility
  static MatchListItem _transformPracticeToMatchListItem(
    Map<String, dynamic> practice,
  ) {
    return MatchListItem(
      id: practice['id'] ?? '',
      clubId: practice['club']?['id'] ?? '',
      type: practice['type'] ?? 'PRACTICE',
      location: practice['venue'] ?? 'TBD',
      opponent: practice['title'] ?? 'Practice Session',
      notes: practice['description'] ?? '',
      spots: practice['maxParticipants'] ?? 20,
      matchDate: DateTime.parse(
        practice['practiceDate'] ?? DateTime.now().toIso8601String(),
      ),
      createdAt: practice['createdAt'] != null
          ? DateTime.parse(practice['createdAt'])
          : DateTime.now(),
      updatedAt: practice['createdAt'] != null
          ? DateTime.parse(practice['createdAt'])
          : DateTime.now(),
      hideUntilRSVP: false,
      rsvpAfterDate: null,
      rsvpBeforeDate: practice['practiceDate'] != null
          ? DateTime.parse(practice['practiceDate'])
          : null,
      notifyMembers: true,
      isCancelled: practice['isCancelled'] ?? false,
      cancellationReason: practice['cancellationReason'],
      isSquadReleased: false,
      totalExpensed: 0.0,
      paidAmount: 0.0,
      club: ClubModel.fromJson(
        practice['club'] ??
            {
              'id': '',
              'name': 'Unknown Club',
              'logo': null,
              'city': null,
              'membershipFeeCurrency': 'USD',
            },
      ),
      canSeeDetails: true,
      canRsvp: practice['canRsvp'] ?? true,
      availableSpots:
          (practice['maxParticipants'] ?? 20) -
          (practice['confirmedPlayers'] ?? 0),
      confirmedPlayers: practice['confirmedPlayers'] ?? 0,
      userRsvp: practice['userRsvp'] != null
          ? MatchRSVPSimple.fromJson(practice['userRsvp'])
          : null,
    );
  }
}
