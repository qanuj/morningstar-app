class MessageReaction {
  final String emoji;
  final String userId;
  final String userName;
  final DateTime createdAt;

  MessageReaction({
    required this.emoji,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      emoji: json['emoji'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
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
          userId == other.userId;

  @override
  int get hashCode => emoji.hashCode ^ userId.hashCode;
}