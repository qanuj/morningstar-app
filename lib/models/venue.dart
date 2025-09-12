class Venue {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? contactPhone;
  final String? contactEmail;
  final bool isActive;
  final DateTime? createdAt;

  Venue({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.description,
    this.contactPhone,
    this.contactEmail,
    required this.isActive,
    this.createdAt,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      description: json['description'],
      contactPhone: json['contactPhone'],
      contactEmail: json['contactEmail'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  String get fullAddress {
    final parts = [address, city, state, country]
        .where((part) => part != null && part.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}