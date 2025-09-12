import '../models/club.dart';
import 'api_service.dart';

class ClubService {
  /// Search for clubs based on query
  static Future<List<Club>> searchClubs(
    String query, {
    String? excludeClubId, 
    int limit = 20,
    bool includeUserClubs = true,
    bool onlyUserClubs = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      // Add query only if provided
      if (query.trim().isNotEmpty) {
        queryParams['q'] = query.trim();
      }
      
      if (excludeClubId != null && excludeClubId.isNotEmpty) {
        queryParams['excludeClubId'] = excludeClubId;
      }

      if (!includeUserClubs) {
        queryParams['includeUserClubs'] = 'false';
      }

      if (onlyUserClubs) {
        queryParams['onlyUserClubs'] = 'true';
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

  /// Get user's clubs only
  static Future<List<Club>> getUserClubs({int limit = 20}) async {
    return searchClubs('', onlyUserClubs: true, limit: limit);
  }

  /// Get opponent clubs (excluding user's clubs)
  static Future<List<Club>> getOpponentClubs({
    String? excludeClubId, 
    int limit = 20
  }) async {
    return searchClubs(
      '', 
      excludeClubId: excludeClubId,
      includeUserClubs: false, 
      limit: limit
    );
  }

  /// Search all clubs with query
  static Future<List<Club>> searchAllClubs(
    String query, {
    String? excludeClubId,
    int limit = 20
  }) async {
    return searchClubs(
      query, 
      excludeClubId: excludeClubId,
      includeUserClubs: true, 
      limit: limit
    );
  }
}