import 'message_status.dart';
import 'reaction_data.dart';

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
  final Map<String, dynamic>? richContent; // JSON content for rich messages
  final List<String>? attachments;
  final MessageStatus status;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MessageModel? replyTo;
  final List<ReactionData>? reactions;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    this.richContent,
    this.attachments,
    this.status = MessageStatus.sent,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.replyTo,
    this.reactions,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderAvatar: json['senderAvatar'],
      content: json['content'] ?? '',
      type: _parseMessageType(json['type']),
      richContent: json['richContent'] as Map<String, dynamic>?,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      status: _parseMessageStatus(json['status']),
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      replyTo: json['replyTo'] != null
          ? MessageModel.fromJson(json['replyTo'])
          : null,
      reactions: json['reactions'] != null
          ? (json['reactions'] as List)
              .map((r) => ReactionData.fromJson(r))
              .toList()
          : null,
    );
  }

  static MessageType _parseMessageType(dynamic type) {
    if (type == null) return MessageType.text;
    
    final typeStr = type.toString();
    switch (typeStr) {
      case 'text': return MessageType.text;
      case 'image': return MessageType.image;
      case 'text_with_images': return MessageType.textWithImages;
      case 'link': return MessageType.link;
      case 'emoji': return MessageType.emoji;
      case 'gif': return MessageType.gif;
      case 'document': return MessageType.document;
      case 'voice': return MessageType.voice;
      case 'video': return MessageType.video;
      case 'location': return MessageType.location;
      case 'file': return MessageType.file;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }

  static MessageStatus _parseMessageStatus(dynamic status) {
    if (status == null) return MessageStatus.sent;
    
    final statusStr = status.toString();
    switch (statusStr) {
      case 'sending': return MessageStatus.sending;
      case 'sent': return MessageStatus.sent;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      case 'failed': return MessageStatus.failed;
      default: return MessageStatus.sent;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': _messageTypeToString(type),
      'richContent': richContent,
      'attachments': attachments,
      'status': _messageStatusToString(status),
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'replyTo': replyTo?.toJson(),
      'reactions': reactions?.map((r) => r.toJson()).toList(),
    };
  }

  String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.text: return 'text';
      case MessageType.image: return 'image';
      case MessageType.textWithImages: return 'text_with_images';
      case MessageType.link: return 'link';
      case MessageType.emoji: return 'emoji';
      case MessageType.gif: return 'gif';
      case MessageType.document: return 'document';
      case MessageType.voice: return 'voice';
      case MessageType.video: return 'video';
      case MessageType.location: return 'location';
      case MessageType.file: return 'file';
      case MessageType.system: return 'system';
    }
  }

  String _messageStatusToString(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending: return 'sending';
      case MessageStatus.sent: return 'sent';
      case MessageStatus.delivered: return 'delivered';
      case MessageStatus.read: return 'read';
      case MessageStatus.failed: return 'failed';
    }
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    Map<String, dynamic>? richContent,
    List<String>? attachments,
    MessageStatus? status,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    MessageModel? replyTo,
    List<ReactionData>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      richContent: richContent ?? this.richContent,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
    );
  }

  // Helper methods for rich content
  String? get imageUrl => richContent?['url'] as String?;
  String? get caption => richContent?['caption'] as String?;
  List<String>? get images => richContent?['images'] != null 
      ? List<String>.from(richContent!['images']) 
      : null;
  String? get linkUrl => richContent?['url'] as String?;
  String? get linkTitle => richContent?['title'] as String?;
  String? get linkDescription => richContent?['description'] as String?;
  String? get linkThumbnail => richContent?['thumbnail'] as String?;
  String? get documentUrl => richContent?['url'] as String?;
  String? get documentName => richContent?['name'] as String?;
  String? get documentSize => richContent?['size'] as String?;
  int? get voiceDuration => richContent?['duration'] as int?;
  String? get voiceUrl => richContent?['url'] as String?;
  double? get locationLat => richContent?['latitude'] as double?;
  double? get locationLng => richContent?['longitude'] as double?;
  String? get locationName => richContent?['name'] as String?;
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
  textWithImages,
  link,
  emoji,
  gif,
  document,
  voice,
  video,
  location,
  file,
  system, // System messages (user joined, etc.)
}


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
      emoji: json['emoji'],
      userId: json['userId'],
      userName: json['userName'],
      createdAt: DateTime.parse(json['createdAt']),
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