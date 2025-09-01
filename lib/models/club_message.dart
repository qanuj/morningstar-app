import 'message_status.dart';
import 'message_image.dart';
import 'message_document.dart';
import 'message_audio.dart';
import 'link_metadata.dart';
import 'message_reaction.dart';
import 'message_reply.dart';
import 'starred_info.dart';

class PinInfo {
  final bool isPinned;
  final DateTime? pinStart;
  final DateTime? pinEnd;
  final String? pinnedBy;

  PinInfo({this.isPinned = false, this.pinStart, this.pinEnd, this.pinnedBy});

  Map<String, dynamic> toJson() {
    return {
      'isPinned': isPinned,
      'pinStart': pinStart?.toIso8601String(),
      'pinEnd': pinEnd?.toIso8601String(),
      'pinnedBy': pinnedBy,
    };
  }
}

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
  final String?
  messageType; // 'text', 'image', 'link', 'emoji', 'gif', 'document', 'audio'
  final DateTime createdAt;
  final MessageStatus status;
  final String? errorMessage;
  final List<MessageReaction> reactions;
  final MessageReply? replyTo;
  final bool deleted;
  final String? deletedBy;
  final StarredInfo starred;
  final PinInfo pin;
  // Local-only fields for read/delivered tracking
  final DateTime? deliveredAt;
  final DateTime? readAt;

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
    required this.starred,
    this.deliveredAt,
    this.readAt,
    required this.pin,
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
    StarredInfo? starred,
    PinInfo? pin,
    DateTime? deliveredAt,
    DateTime? readAt,
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
      pin: pin ?? this.pin,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
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
      if (json['isDeleted'] == true) {
        isDeleted = true;
        deletedByName = content['deletedBy'] ?? content['deletedByName'];
        messageContent = '';
        messageType = 'deleted';
      } else {
        messageType = content['type'] ?? 'text';
        messageContent = (content['body'] ?? content['text'] ?? '')
            .toString()
            .trim();
      }

      // Handle different message types (only if not deleted)
      if (!isDeleted) {
        switch (messageType) {
          case 'gif':
            gifUrl = content['url'];
            break;
          case 'image':
            if (content['url'] != null) {
              pictures = [
                MessageImage(url: content['url'], caption: content['caption']),
              ];
            }
            break;
          case 'text_with_images':
            if (content['images'] is List) {
              pictures = (content['images'] as List)
                  .map((url) => MessageImage(url: url as String))
                  .toList();
            }
            break;
          case 'text':
            // Handle text messages with images array
            if (content['images'] is List) {
              pictures = (content['images'] as List)
                  .map((url) => MessageImage(url: url as String))
                  .toList();
            }
            break;
          case 'link':
            if (content['url'] != null) {
              linkMeta = [
                LinkMetadata(
                  url: content['url'],
                  title: content['title'],
                  description: content['description'],
                  image: content['thumbnail'],
                ),
              ];
            }
            break;
          case 'document':
            if (content['url'] != null) {
              documents = [
                MessageDocument(
                  url: content['url'],
                  filename: content['name'] ?? 'document',
                  type: content['name']?.split('.').last ?? 'file',
                  size: content['size'],
                ),
              ];
            }
            break;
          case 'audio':
            if (content['url'] != null) {
              audio = MessageAudio.fromJson({
                'url': content['url'],
                'name': content['name'],
                'duration': content['duration'],
                'size': content['size'],
              });
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
          .map(
            (reaction) =>
                MessageReaction.fromJson(reaction as Map<String, dynamic>),
          )
          .toList();
    }

    // Parse reply
    MessageReply? replyTo;
    if (json['replyTo'] is Map<String, dynamic>) {
      replyTo = MessageReply.fromJson(json['replyTo'] as Map<String, dynamic>);
    }

    // Parse pin information
    bool isPinned = false;
    DateTime? pinStart;
    DateTime? pinEnd;
    String? pinnedBy;

    if (json['pin'] is Map<String, dynamic>) {
      final pinData = json['pin'] as Map<String, dynamic>;
      isPinned = pinData['isPinned'] ?? false;

      if (pinData['pinStart'] != null) {
        pinStart = DateTime.parse(pinData['pinStart']);
      }
      if (pinData['pinEnd'] != null) {
        pinEnd = DateTime.parse(pinData['pinEnd']);
      }

      pinnedBy = pinData['pinnedBy'];
    } else {
      // Fallback to old format
      isPinned = _calculatePinnedStatus(json['pinStart'], json['pinEnd']);
      if (json['pinStart'] != null) {
        pinStart = DateTime.parse(json['pinStart']);
      }
      if (json['pinEnd'] != null) {
        pinEnd = DateTime.parse(json['pinEnd']);
      }
      pinnedBy = json['pinnedBy'];
    }

    // Parse starred information
    StarredInfo starredInfo;
    if (json['starred'] is Map<String, dynamic>) {
      starredInfo = StarredInfo.fromJson(
        json['starred'] as Map<String, dynamic>,
      );
    } else {
      // Fallback to old format
      starredInfo = StarredInfo(
        isStarred: json['starred'] ?? false,
        starredAt: null,
      );
    }

    // Parse message status from server response
    MessageStatus messageStatus = MessageStatus.sent; // Default
    if (json['status'] is Map<String, dynamic>) {
      final statusData = json['status'] as Map<String, dynamic>;
      
      // Check for read status first (highest priority)
      if (statusData['read'] == true) {
        messageStatus = MessageStatus.read;
      } else if (statusData['delivered'] == true) {
        messageStatus = MessageStatus.delivered;
      } else {
        messageStatus = MessageStatus.sent;
      }
    } else if (json['status'] is String) {
      // Handle string status format
      final statusStr = json['status'] as String;
      switch (statusStr) {
        case 'sending':
          messageStatus = MessageStatus.sending;
          break;
        case 'sent':
          messageStatus = MessageStatus.sent;
          break;
        case 'delivered':
          messageStatus = MessageStatus.delivered;
          break;
        case 'read':
          messageStatus = MessageStatus.read;
          break;
        case 'failed':
          messageStatus = MessageStatus.failed;
          break;
        default:
          messageStatus = MessageStatus.sent;
      }
    }
    
    // Also check readBy and deliveredTo arrays for status determination
    // This provides additional validation beyond the status object
    if (json['readBy'] is List && (json['readBy'] as List).isNotEmpty) {
      // If there are any read receipts, prioritize read status
      messageStatus = MessageStatus.read;
    } else if (json['deliveredTo'] is List && (json['deliveredTo'] as List).isNotEmpty) {
      // If there are delivery receipts but no read receipts, use delivered status
      if (messageStatus == MessageStatus.sent) {
        messageStatus = MessageStatus.delivered;
      }
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
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ).toLocal(),
      status: messageStatus, // Use the parsed status
      reactions: reactions,
      replyTo: replyTo,
      deleted: isDeleted,
      deletedBy: deletedByName,
      starred: starredInfo,
      pin: PinInfo(
        isPinned: isPinned,
        pinStart: pinStart,
        pinEnd: pinEnd,
        pinnedBy: pinnedBy,
      ),
      // Local-only fields - not from server JSON
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt']).toLocal()
          : null,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']).toLocal() : null,
    );
  }

  static bool _calculatePinnedStatus(dynamic pinStart, dynamic pinEnd) {
    if (pinStart == null || pinEnd == null) return false;

    try {
      final startTime = DateTime.parse(pinStart);
      final endTime = DateTime.parse(pinEnd);
      final now = DateTime.now();

      return now.isAfter(startTime) && now.isBefore(endTime);
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': id, // For API compatibility
      'clubId': clubId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfilePicture': senderProfilePicture,
      'senderRole': senderRole,
      'content': content,
      'pictures': pictures.map((p) => p.toJson()).toList(),
      'documents': documents.map((d) => d.toJson()).toList(),
      'audio': audio?.toJson(),
      'linkMeta': linkMeta.map((l) => l.toJson()).toList(),
      'gifUrl': gifUrl,
      'messageType': messageType,
      'createdAt': createdAt.toIso8601String(),
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'replyTo': replyTo?.toJson(),
      'deleted': deleted,
      'deletedBy': deletedBy,
      'starred': starred.toJson(),
      'pin': pin.toJson(),
      // Local-only fields for storage
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }
}
