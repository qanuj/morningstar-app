import '../services/api_service.dart';

class GroundLocation {
  final String id;
  final String name;
  final String city;
  final String? address;

  GroundLocation({
    required this.id,
    required this.name,
    required this.city,
    this.address,
  });

  factory GroundLocation.fromJson(Map<String, dynamic> json) {
    return GroundLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'address': address,
    };
  }
}

class City {
  final String id;
  final String name;
  final String state;
  final String country;

  City({
    required this.id,
    required this.name,
    required this.state,
    required this.country,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
    );
  }

  factory City.fromString(String name) {
    return City(
      id: '',
      name: name,
      state: '',
      country: '',
    );
  }

  String get displayName => '$name, $state';
  String get fullDisplayName => '$name, $state, $country';
}

class GroundService {
  /// Search for ground locations based on query
  static Future<List<GroundLocation>> searchGroundLocations(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final response = await ApiService.get(
        '/ground-locations',
        queryParams: {'search': query.trim()},
      );

      if (response['data'] is List) {
        return (response['data'] as List)
            .map((json) => GroundLocation.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return (response as List)
            .map((json) => GroundLocation.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error searching ground locations: $e');
      return [];
    }
  }

  /// Search for cities based on query
  static Future<List<City>> searchCities(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final response = await ApiService.get(
        '/cities',
        queryParams: {'search': query.trim()},
      );

      if (response['data'] is List) {
        return (response['data'] as List)
            .map((json) => City.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return (response as List)
            .map((json) => City.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error searching cities: $e');
      return [];
    }
  }

  /// Get popular ground locations (without search query)
  static Future<List<GroundLocation>> getPopularGroundLocations() async {
    try {
      final response = await ApiService.get('/ground-locations');

      if (response['data'] is List) {
        return (response['data'] as List)
            .map((json) => GroundLocation.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return (response as List)
            .map((json) => GroundLocation.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching popular ground locations: $e');
      return [];
    }
  }

  /// Get popular cities (without search query)
  static Future<List<City>> getPopularCities() async {
    try {
      final response = await ApiService.get('/cities');

      if (response['data'] is List) {
        return (response['data'] as List)
            .map((json) => City.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return (response as List)
            .map((json) => City.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching popular cities: $e');
      return [];
    }
  }
}