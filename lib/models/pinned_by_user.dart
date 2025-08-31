class PinnedByUser {
  final String id;
  final String name;
  final String? profilePicture;

  PinnedByUser({
    required this.id,
    required this.name,
    this.profilePicture,
  });

  factory PinnedByUser.fromJson(Map<String, dynamic> json) {
    return PinnedByUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePicture': profilePicture,
    };
  }
}