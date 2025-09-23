import '../models/poll.dart';
import 'api_service.dart';

class PollService {
  /// Fetch polls for user's clubs
  static Future<List<Poll>> getPolls({
    String? clubId,
    bool includeExpired = false,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      if (clubId != null) 'clubId': clubId,
      if (includeExpired) 'includeExpired': 'true',
      'limit': limit.toString(),
    };

    final response = await ApiService.get('/polls', queryParams: queryParams);
    final pollsData = response['data'] ?? response;

    if (pollsData is List) {
      return pollsData.map((poll) => Poll.fromJson(poll)).toList();
    }

    return [];
  }

  /// Create a new poll
  static Future<Poll> createPoll({
    required String clubId,
    required String question,
    required List<String> options,
    DateTime? expiresAt,
  }) async {
    final data = {
      'clubId': clubId,
      'question': question,
      'options': options,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    };

    final response = await ApiService.post('/polls', data);
    return Poll.fromJson(response);
  }

  /// Vote on a poll option
  static Future<void> voteOnPoll({
    required String pollId,
    required String optionId,
  }) async {
    await ApiService.post('/polls/$pollId/vote', {
      'optionId': optionId,
    });
  }

  /// Remove vote from a poll
  static Future<void> removeVote({
    required String pollId,
  }) async {
    await ApiService.delete('/polls/$pollId/vote');
  }
}