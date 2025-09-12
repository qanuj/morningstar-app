import '../models/venue.dart';
import 'api_service.dart';

class VenueService {
  /// Search for venues based on query using ground-locations API
  static Future<List<Venue>> searchVenues(
    String query, {
    int limit = 20,
    String? city,
    String? state,
  }) async {
    try {
      final queryParams = <String, String>{};

      // Add search query if provided
      if (query.trim().isNotEmpty) {
        queryParams['search'] = query.trim();
      }
      
      if (city != null && city.isNotEmpty) {
        queryParams['city'] = city;
      }

      final response = await ApiService.get(
        '/ground-locations',
        queryParams: queryParams,
      );

      if (response is List) {
        return (response as List)
            .map((json) => Venue.fromJson({
              'id': json['id'],
              'name': json['name'],
              'address': json['address'],
              'city': json['city'],
              'isActive': true,
            }))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error searching venues: $e');
      return [];
    }
  }

  /// Create a new venue using ground-locations
  static Future<Venue?> createVenue({
    required String name,
    String? address,
    String? city,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    String? description,
    String? contactPhone,
    String? contactEmail,
  }) async {
    try {
      final requestBody = {
        'name': name,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        'isActive': true,
      };

      final response = await ApiService.post('/ground-locations', requestBody);
      
      if (response['data'] != null) {
        return Venue.fromJson({
          'id': response['data']['id'],
          'name': response['data']['name'],
          'address': response['data']['address'],
          'city': response['data']['city'],
          'isActive': true,
        });
      } else if (response['id'] != null) {
        return Venue.fromJson({
          'id': response['id'],
          'name': response['name'],
          'address': response['address'],
          'city': response['city'],
          'isActive': true,
        });
      }

      return null;
    } catch (e) {
      print('Error creating venue: $e');
      return null;
    }
  }

  /// Get popular venues (most used) - using general ground-locations
  static Future<List<Venue>> getPopularVenues({int limit = 10}) async {
    try {
      final response = await ApiService.get('/ground-locations');

      if (response is List) {
        // Take first 10 venues as "popular" since the API orders by city and name
        final venues = (response as List)
            .take(limit)
            .map((json) => Venue.fromJson({
              'id': json['id'],
              'name': json['name'],
              'address': json['address'],
              'city': json['city'],
              'isActive': true,
            }))
            .toList();
        return venues;
      }

      return [];
    } catch (e) {
      print('Error fetching popular venues: $e');
      return [];
    }
  }

  /// Get nearby venues based on coordinates
  static Future<List<Venue>> getNearbyVenues({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radiusKm.toString(),
        'limit': limit.toString(),
      };

      final response = await ApiService.get(
        '/venues/nearby',
        queryParams: queryParams,
      );

      if (response['data'] is List) {
        return (response['data'] as List)
            .map((json) => Venue.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return (response as List)
            .map((json) => Venue.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching nearby venues: $e');
      return [];
    }
  }
}