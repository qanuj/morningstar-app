import 'city.dart';

class Venue {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? cityId;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? googleMapsLink;
  final String? description;
  final String? contactPhone;
  final String? contactEmail;
  final bool isActive;
  final DateTime? createdAt;
  final City? cityRelation;

  Venue({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.cityId,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.googleMapsLink,
    this.description,
    this.contactPhone,
    this.contactEmail,
    required this.isActive,
    this.createdAt,
    this.cityRelation,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      city: json['city'],
      cityId: json['cityId'],
      state: json['state'],
      country: json['country'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      googleMapsLink: json['googleMapsLink'],
      description: json['description'],
      contactPhone: json['contactPhone'],
      contactEmail: json['contactEmail'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      cityRelation: json['cityRelation'] != null
          ? City.fromJson(json['cityRelation'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'cityId': cityId,
      'state': state,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'googleMapsLink': googleMapsLink,
      'description': description,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'cityRelation': cityRelation?.toJson(),
    };
  }

  String get fullAddress {
    // Use cityRelation data if available, otherwise fallback to direct fields
    final cityName = cityRelation?.name ?? city;
    final stateName = cityRelation?.state ?? state;
    final countryName = cityRelation?.country ?? country;

    final parts = [address, cityName, stateName, countryName]
        .where((part) => part != null && part.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}