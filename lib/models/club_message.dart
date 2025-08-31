import 'message_status.dart';
import 'message_image.dart';
import 'message_document.dart';
import 'message_audio.dart';
import 'link_metadata.dart';
import 'message_reaction.dart';
import 'message_reply.dart';

class ClubMessage {
  final String id;
  final String clubId;
  final String senderId;
  final String senderName;
  final String? senderProfilePicture;
  final String? senderRole;
  final String content;
  final List<MessageImage> pictures;
  final List<MessageDocument> documents;
  final MessageAudio? audio;
  final List<LinkMetadata> linkMeta;
  final String? gifUrl; // For GIF messages
  final String? messageType; // 'text', 'image', 'link', 'emoji', 'gif', 'document', 'audio'
  final DateTime createdAt;
  final MessageStatus status;
  final String? errorMessage;
  final List<MessageReaction> reactions;
  final MessageReply? replyTo;
  final bool deleted;
  final String? deletedBy;
  final bool starred;
  final bool pinned;
  final DateTime? pinStart;
  final DateTime? pinEnd;

  ClubMessage({
    required this.id,
    required this.clubId,
    required this.senderId,
    required this.senderName,
    this.senderProfilePicture,
    this.senderRole,
    required this.content,
    this.pictures = const [],
    this.documents = const [],
    this.audio,
    this.linkMeta = const [],
    this.gifUrl,
    this.messageType,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.reactions = const [],
    this.replyTo,
    this.deleted = false,
    this.deletedBy,
    this.starred = false,
    this.pinned = false,
    this.pinStart,
    this.pinEnd,
  });

  ClubMessage copyWith({
    MessageStatus? status,
    String? errorMessage,
    List<MessageImage>? pictures,
    List<MessageDocument>? documents,
    MessageAudio? audio,
    List<LinkMetadata>? linkMeta,
    String? gifUrl,
    String? messageType,
    List<MessageReaction>? reactions,
    MessageReply? replyTo,
    bool? deleted,
    String? deletedBy,
    bool? starred,
    bool? pinned,
    DateTime? pinStart,
    DateTime? pinEnd,
  }) {
    return ClubMessage(
      id: id,
      clubId: clubId,
      senderId: senderId,
      senderName: senderName,
      senderProfilePicture: senderProfilePicture,
      senderRole: senderRole,
      content: content,
      pictures: pictures ?? this.pictures,
      documents: documents ?? this.documents,
      audio: audio ?? this.audio,
      linkMeta: linkMeta ?? this.linkMeta,
      gifUrl: gifUrl ?? this.gifUrl,
      messageType: messageType ?? this.messageType,
      createdAt: createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      reactions: reactions ?? this.reactions,
      replyTo: replyTo ?? this.replyTo,
      deleted: deleted ?? this.deleted,
      deletedBy: deletedBy ?? this.deletedBy,
      starred: starred ?? this.starred,
      pinned: pinned ?? this.pinned,
      pinStart: pinStart ?? this.pinStart,
      pinEnd: pinEnd ?? this.pinEnd,
    );
  }

  factory ClubMessage.fromJson(Map<String, dynamic> json) {
    // Handle content - it could be a string or an object with type/body
    String messageContent = '';
    String? messageType;
    String? gifUrl;
    List<MessageImage> pictures = [];
    List<MessageDocument> documents = [];
    MessageAudio? audio;
    List<LinkMetadata> linkMeta = [];
    
    // Check for deleted message
    bool isDeleted = false;
    String? deletedByName;
    
    final content = json['content'];
    if (content is String) {
      messageContent = content;
      messageType = 'text';
    } else if (content is Map<String, dynamic>) {
      // Check if message is deleted
      if (content['deleted'] == true) {
        isDeleted = true;
        deletedByName = content['deletedBy'] ?? content['deletedByName'];
        messageContent = '';
        messageType = 'deleted';
      } else {
        messageType = content['type'] ?? 'text';
        messageContent = content['body'] ?? content['text'] ?? '';
      }
      
      // Handle different message types (only if not deleted)
      if (!isDeleted) {
        switch (messageType) {
        case 'gif':
          gifUrl = content['url'];
          break;
        case 'image':
          if (content['url'] != null) {
            pictures = [MessageImage(url: content['url'], caption: content['caption'])];
          }
          break;
        case 'text_with_images':
          if (content['images'] is List) {
            pictures = (content['images'] as List)
                .map((url) => MessageImage(url: url as String))
                .toList();
          }
          break;
        case 'link':
          if (content['url'] != null) {
            linkMeta = [LinkMetadata(
              url: content['url'],
              title: content['title'],
              description: content['description'],
              image: content['thumbnail'],
            )];
          }
          break;
        case 'document':
          if (content['url'] != null) {
            documents = [MessageDocument(
              url: content['url'],
              filename: content['name'] ?? 'document',
              type: content['name']?.split('.').last ?? 'file',
              size: content['size'],
            )];
          }
          break;
        case 'audio':
          if (content['url'] != null) {
            audio = MessageAudio(
              url: content['url'],
              filename: content['name'] ?? 'audio',
              duration: content['duration'],
              size: content['size'],
            );
          }
          break;
        }
      }
      
      // Parse pictures array (for existing format compatibility)
      if (content['pictures'] is List) {
        pictures = (content['pictures'] as List)
            .map((pic) => MessageImage.fromJson(pic as Map<String, dynamic>))
            .toList();
      }
      
      // Parse documents array (for existing format compatibility)
      if (content['documents'] is List) {
        documents = (content['documents'] as List)
            .map((doc) => MessageDocument.fromJson(doc as Map<String, dynamic>))
            .toList();
      }
      
      // Parse link metadata array (for existing format compatibility)
      if (content['meta'] is List) {
        linkMeta = (content['meta'] as List)
            .map((meta) => LinkMetadata.fromJson(meta as Map<String, dynamic>))
            .toList();
      }
    }
    
    // Extract sender info from nested objects if available
    String senderName = 'Unknown';
    String? senderProfilePicture;
    String? senderRole;
    
    if (json.containsKey('sender') && json['sender'] is Map) {
      final senderData = json['sender'] as Map<String, dynamic>;
      senderName = senderData['name'] ?? senderName;
      senderProfilePicture = senderData['profilePicture'];
      senderRole = senderData['clubRole'] ?? 'MEMBER';
    } else {
      senderName = json['senderName'] ?? senderName;
      senderProfilePicture = json['senderProfilePicture'];
      senderRole = json['senderRole'] ?? json['clubRole'];
    }
    
    // Parse reactions
    List<MessageReaction> reactions = [];
    if (json['reactions'] is List) {
      reactions = (json['reactions'] as List)
          .map((reaction) => MessageReaction.fromJson(reaction as Map<String, dynamic>))
          .toList();
    }
    
    // Parse reply
    MessageReply? replyTo;
    if (json['replyTo'] is Map<String, dynamic>) {
      replyTo = MessageReply.fromJson(json['replyTo'] as Map<String, dynamic>);
    }
    
    return ClubMessage(
      id: json['messageId'] ?? json['id'] ?? '',
      clubId: json['clubId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: senderName,
      senderProfilePicture: senderProfilePicture,
      senderRole: senderRole,
      content: messageContent,
      pictures: pictures,
      documents: documents,
      audio: audio,
      linkMeta: linkMeta,
      gifUrl: gifUrl,
      messageType: messageType,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      reactions: reactions,
      replyTo: replyTo,
      deleted: isDeleted,
      deletedBy: deletedByName,
      starred: json['starred'] ?? false,
      pinned: json['pinned'] ?? false,
      pinStart: json['pinStart'] != null ? DateTime.parse(json['pinStart']) : null,
      pinEnd: json['pinEnd'] != null ? DateTime.parse(json['pinEnd']) : null,
    );
  }
}