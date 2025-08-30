class ConversationModel {
  final String id;
  final String title;
  final String? description;
  final ConversationType type;
  final List<String> participants;
  final MessageModel? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ClubModel? club;
  final bool isActive;

  ConversationModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.participants,
    this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.club,
    required this.isActive,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ConversationType.values.firstWhere(
        (e) => e.toString() == 'ConversationType.${json['type']}',
        orElse: () => ConversationType.group,
      ),
      participants: List<String>.from(json['participants'] ?? []),
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      club: json['club'] != null ? ClubModel.fromJson(json['club']) : null,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'participants': participants,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'club': club?.toJson(),
      'isActive': isActive,
    };
  }

  ConversationModel copyWith({
    String? id,
    String? title,
    String? description,
    ConversationType? type,
    List<String>? participants,
    MessageModel? lastMessage,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    ClubModel? club,
    bool? isActive,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      club: club ?? this.club,
      isActive: isActive ?? this.isActive,
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final List<String>? attachments;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MessageModel? replyTo;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    this.attachments,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.replyTo,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderAvatar: json['senderAvatar'],
      content: json['content'],
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type']}',
        orElse: () => MessageType.text,
      ),
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      replyTo: json['replyTo'] != null
          ? MessageModel.fromJson(json['replyTo'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type.toString().split('.').last,
      'attachments': attachments,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'replyTo': replyTo?.toJson(),
    };
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    List<String>? attachments,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    MessageModel? replyTo,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replyTo: replyTo ?? this.replyTo,
    );
  }
}

enum ConversationType {
  announcement, // Club announcements (read-only for members)
  group,       // Team/group discussions
  general,     // General club chat
  private,     // Direct messages (if implemented)
}

enum MessageType {
  text,
  image,
  file,
  system, // System messages (user joined, etc.)
}

class ClubModel {
  final String id;
  final String name;
  final String? logo;

  ClubModel({
    required this.id,
    required this.name,
    this.logo,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'],
      name: json['name'],
      logo: json['logo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
    };
  }
}