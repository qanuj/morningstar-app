import '../models/venue.dart';
import 'api_service.dart';

class VenueService {
  /// Search for venues based on query using ground-locations API
  static Future<List<Venue>> searchVenues(
    String query, {
    int limit = 20,
    int offset = 0,
    String? city,
    String? state,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      // Add search query if provided
      if (query.trim().isNotEmpty) {
        queryParams['search'] = query.trim();
      }
      
      if (city != null && city.isNotEmpty) {
        queryParams['city'] = city;
      }

      if (state != null && state.isNotEmpty) {
        queryParams['state'] = state;
      }

      final response = await ApiService.get(
        '/ground-locations',
        queryParams: queryParams,
      );

      // Handle both direct List and wrapped {data: []} response formats
      List<dynamic> venueList = [];
      if (response is List) {
        venueList = response as List;
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        venueList = response['data'] as List;
      }

      if (venueList.isNotEmpty) {
        return venueList
            .map((json) => Venue.fromJson({
              'id': json['id'],
              'name': json['name'],
              'address': json['address'],
              'city': json['city'],
              'contactPhone': json['contactPhone'],
              'isActive': json['isPublic'] ?? true, // Map isPublic to isActive
              'createdAt': json['createdAt'],
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
    String? googleMapsLink,
    String? description,
    String? contactPhone,
    String? contactEmail,
  }) async {
    try {
      final requestBody = {
        'name': name,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (country != null) 'country': country,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        if (googleMapsLink != null) 'googleMapsLink': googleMapsLink,
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
  static Future<List<Venue>> getPopularVenues({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        'popular': 'true', // Request popular venues from API
      };

      final response = await ApiService.get(
        '/ground-locations',
        queryParams: queryParams,
      );

      // Handle both direct List and wrapped {data: []} response formats
      List<dynamic> venueList = [];
      if (response is List) {
        venueList = response as List;
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        venueList = response['data'] as List;
      }

      if (venueList.isNotEmpty) {
        final venues = venueList
            .map((json) => Venue.fromJson({
              'id': json['id'],
              'name': json['name'],
              'address': json['address'],
              'city': json['city'],
              'contactPhone': json['contactPhone'],
              'isActive': json['isPublic'] ?? true, // Map isPublic to isActive
              'createdAt': json['createdAt'],
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

  /// Get all venues with pagination
  static Future<List<Venue>> getAllVenues({
    int limit = 20,
    int offset = 0,
    String? city,
    String? state,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (city != null && city.isNotEmpty) {
        queryParams['city'] = city;
      }

      if (state != null && state.isNotEmpty) {
        queryParams['state'] = state;
      }

      print('🔍 VenueService getAllVenues - Making API call with params: $queryParams');

      final response = await ApiService.get(
        '/ground-locations',
        queryParams: queryParams,
      );

      print('🔍 VenueService getAllVenues - Raw response type: ${response.runtimeType}');
      print('🔍 VenueService getAllVenues - Raw response: $response');

      // Handle both direct List and wrapped {data: []} response formats
      List<dynamic> venueList = [];
      if (response is List) {
        venueList = response as List;
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        venueList = response['data'] as List;
      }

      if (venueList.isNotEmpty) {
        final venues = venueList
            .map((json) {
              print('🔍 Processing venue JSON: $json');
              final mappedData = {
                'id': json['id'],
                'name': json['name'],
                'address': json['address'],
                'city': json['city'],
                'contactPhone': json['contactPhone'],
                'isActive': json['isPublic'] ?? true, // Map isPublic to isActive
                'createdAt': json['createdAt'],
              };
              print('🔍 Mapped venue data: $mappedData');
              final venue = Venue.fromJson(mappedData);
              print('🔍 Created venue: ${venue.name} (${venue.id})');
              return venue;
            })
            .toList();
        
        print('🔍 Total venues created: ${venues.length}');
        return venues;
      }

      print('🔍 VenueService getAllVenues - Response is not a List, returning empty array');
      return [];
    } catch (e) {
      print('Error fetching venues: $e');
      print('Stack trace: ${StackTrace.current}');
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