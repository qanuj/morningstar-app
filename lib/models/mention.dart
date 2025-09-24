class Mention {
  final String id;
  final String name;
  final String? profilePicture;
  final String role; // 'OWNER', 'ADMIN', 'MEMBER'

  const Mention({
    required this.id,
    required this.name,
    this.profilePicture,
    required this.role,
  });

  factory Mention.fromJson(Map<String, dynamic> json) {
    return Mention(
      id: json['id'] as String,
      name: json['name'] as String,
      profilePicture: json['profilePicture'] as String?,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePicture': profilePicture,
      'role': role,
    };
  }

  bool get isOwner => role == 'OWNER';
  bool get isAdmin => role == 'ADMIN';
  bool get isMember => role == 'MEMBER';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mention && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Mention(id: $id, name: $name, role: $role)';
  }
}

/// Class to represent a mentioned user in a message response
class MentionedUser {
  final String id;
  final String name;
  final String? profilePicture;
  final String role;

  const MentionedUser({
    required this.id,
    required this.name,
    this.profilePicture,
    required this.role,
  });

  factory MentionedUser.fromJson(Map<String, dynamic> json) {
    return MentionedUser(
      id: json['id'] as String,
      name: json['name'] as String,
      profilePicture: json['profilePicture'] as String?,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePicture': profilePicture,
      'role': role,
    };
  }

  bool get isOwner => role == 'OWNER';
  bool get isAdmin => role == 'ADMIN';
  bool get isMember => role == 'MEMBER';

  /// Convert to Mention for UI usage
  Mention toMention() {
    return Mention(
      id: id,
      name: name,
      profilePicture: profilePicture,
      role: role,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MentionedUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MentionedUser(id: $id, name: $name, role: $role)';
  }
}