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
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown User',
      profilePicture: json['profilePicture']?.toString(),
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

class MessageReaction {
  final String emoji;
  final int count;
  final List<ReactionUser> users;
  
  // Backward compatibility fields
  final String userId;
  final String userName;
  final DateTime createdAt;

  MessageReaction({
    required this.emoji,
    this.count = 0,
    this.users = const [],
    this.userId = '',
    this.userName = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    // Handle new format with users array
    if (json.containsKey('users') && json['users'] is List && json['users'] != null) {
      final usersJson = json['users'] as List;
      final usersList = <ReactionUser>[];
      
      for (var user in usersJson) {
        if (user is Map<String, dynamic>) {
          try {
            usersList.add(ReactionUser.fromJson(user));
          } catch (e) {
            // Skip invalid user data
            continue;
          }
        }
      }
      
      return MessageReaction(
        emoji: json['emoji'] ?? '',
        count: json['count'] ?? usersList.length,
        users: usersList,
        createdAt: json['createdAt'] != null 
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );
    }
    
    // Handle old format for backward compatibility
    final userId = json['userId'] ?? '';
    final userName = json['userName'] ?? '';
    
    return MessageReaction(
      emoji: json['emoji'] ?? '',
      userId: userId,
      userName: userName,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      count: 1,
      users: userId.isNotEmpty && userName.isNotEmpty
          ? [ReactionUser(userId: userId, name: userName)]
          : <ReactionUser>[],
    );
  }

  Map<String, dynamic> toJson() {
    // Use new format if users are available
    if (users.isNotEmpty) {
      return {
        'emoji': emoji,
        'count': count > 0 ? count : users.length,
        'users': users.map((u) => u.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
    }
    
    // Fall back to old format
    return {
      'emoji': emoji,
      'userId': userId,
      'userName': userName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageReaction &&
          runtimeType == other.runtimeType &&
          emoji == other.emoji &&
          (users.isNotEmpty ? users.first.userId : userId) == (other.users.isNotEmpty ? other.users.first.userId : other.userId);

  @override
  int get hashCode => emoji.hashCode ^ (users.isNotEmpty ? users.first.userId.hashCode : userId.hashCode);
}