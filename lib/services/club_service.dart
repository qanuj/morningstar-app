import '../models/club.dart';
import 'api_service.dart';

class ClubService {
  /// Search for clubs based on query
  static Future<List<Club>> searchClubs(String query, {String? excludeClubId, int limit = 5}) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final queryParams = {
        'q': query.trim(),
        'limit': limit.toString(),
      };
      
      if (excludeClubId != null && excludeClubId.isNotEmpty) {
        queryParams['excludeClubId'] = excludeClubId;
      }

      final response = await ApiService.get(
        '/clubs/search',
        queryParams: queryParams,
      );

      if (response['data'] is List) {
        return (response['data'] as List)
            .map((json) => Club.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return (response as List)
            .map((json) => Club.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error searching clubs: $e');
      return [];
    }
  }
}