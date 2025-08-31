class ReactionData {
  final String emoji;
  final int count;
  final List<ReactionUser> users;

  ReactionData({
    required this.emoji,
    required this.count,
    required this.users,
  });

  factory ReactionData.fromJson(Map<String, dynamic> json) {
    return ReactionData(
      emoji: json['emoji'] ?? '',
      count: json['count'] ?? 0,
      users: (json['users'] as List<dynamic>?)
          ?.map((userJson) => ReactionUser.fromJson(userJson))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emoji': emoji,
      'count': count,
      'users': users.map((user) => user.toJson()).toList(),
    };
  }
}

class ReactionUser {
  final String userId;
  final String name;
  final String? profilePicture;

  ReactionUser({
    required this.userId,
    required this.name,
    this.profilePicture,
  });

  factory ReactionUser.fromJson(Map<String, dynamic> json) {
    return ReactionUser(
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'profilePicture': profilePicture,
    };
  }
}