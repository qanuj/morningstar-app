import 'package:flutter/foundation.dart';
import 'message_status.dart';
import 'message_document.dart';
import 'message_audio.dart';
import 'link_metadata.dart';
import 'message_reaction.dart';
import 'message_reply.dart';
import 'starred_info.dart';
import 'mention.dart';
import 'media_item.dart';

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
  final List<MediaItem>
  media; // Combined images and videos with individual captions
  final MessageDocument? document;
  final MessageAudio? audio;
  final List<LinkMetadata> linkMeta;
  final String? gifUrl; // For GIF messages
  final String?
  messageType; // 'text', 'image', 'link', 'emoji', 'gif', 'document', 'audio', 'match'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final MessageStatus status;
  final String? errorMessage;
  final List<MessageReaction> reactions;
  final int? reactionsCount;
  final MessageReply? replyTo;
  final bool deleted;
  final String? deletedBy;
  final StarredInfo starred;
  final PinInfo pin;
  // Match-specific fields
  final String? matchId; // ID of the associated match
  // Practice-specific fields
  final String? practiceId; // ID of the associated practice session
  // Unified metadata field for all message types
  final Map<String, dynamic>?
  meta; // Additional metadata (match details, practice details, location details, poll details, etc.)
  // Poll-specific fields
  final String? pollId; // ID of the associated poll
  // Local-only fields for read/delivered tracking
  final DateTime? deliveredAt;
  final DateTime? readAt;
  // Read receipts and delivery status arrays
  final List<Map<String, dynamic>> deliveredTo;
  final List<Map<String, dynamic>> readBy;
  // Mention fields
  final List<MentionedUser>? _mentions;
  final bool? _hasMentions;
  final bool? _mentionsCurrentUser;

  // Progress tracking fields (for local messages only)
  final double? uploadProgress; // 0.0 to 1.0 for upload progress
  final double? compressionProgress; // 0.0 to 1.0 for compression progress
  final String?
  processingStatus; // Human readable status like "Compressing...", "Uploading..."

  /// Get mentions list, never null
  List<MentionedUser> get mentions => _mentions ?? [];

  /// Get hasMentions flag
  bool get hasMentions => _hasMentions ?? false;

  /// Get mentionsCurrentUser flag
  bool get mentionsCurrentUser => _mentionsCurrentUser ?? false;

  ClubMessage({
    required this.id,
    required this.clubId,
    required this.senderId,
    required this.senderName,
    this.senderProfilePicture,
    this.senderRole,
    required this.content,
    this.media = const [],
    this.document,
    this.audio,
    this.linkMeta = const [],
    this.gifUrl,
    this.messageType,
    required this.createdAt,
    this.updatedAt,
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.reactions = const [],
    this.reactionsCount,
    this.replyTo,
    this.deleted = false,
    this.deletedBy,
    required this.starred,
    this.matchId,
    this.practiceId,
    this.meta,
    this.pollId,
    this.deliveredAt,
    this.readAt,
    required this.pin,
    this.deliveredTo = const [],
    this.readBy = const [],
    List<MentionedUser>? mentions,
    bool? hasMentions,
    bool? mentionsCurrentUser,
    this.uploadProgress,
    this.compressionProgress,
    this.processingStatus,
  }) : _mentions = mentions ?? [],
       _hasMentions = hasMentions ?? false,
       _mentionsCurrentUser = mentionsCurrentUser ?? false;

  ClubMessage copyWith({
    MessageStatus? status,
    String? errorMessage,
    List<MediaItem>? media,
    List<MessageDocument>? documents,
    MessageAudio? audio,
    List<LinkMetadata>? linkMeta,
    String? gifUrl,
    String? messageType,
    List<MessageReaction>? reactions,
    int? reactionsCount,
    MessageReply? replyTo,
    bool? deleted,
    String? deletedBy,
    StarredInfo? starred,
    String? matchId,
    String? practiceId,
    Map<String, dynamic>? meta,
    String? pollId,
    PinInfo? pin,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? deliveredTo,
    List<Map<String, dynamic>>? readBy,
    List<MentionedUser>? mentions,
    bool? hasMentions,
    bool? mentionsCurrentUser,
    double? uploadProgress,
    double? compressionProgress,
    String? processingStatus,
  }) {
    return ClubMessage(
      id: id,
      clubId: clubId,
      senderId: senderId,
      senderName: senderName,
      senderProfilePicture: senderProfilePicture,
      senderRole: senderRole,
      content: content,
      media: media ?? this.media,
      document: document ?? this.document,
      audio: audio ?? this.audio,
      linkMeta: linkMeta ?? this.linkMeta,
      gifUrl: gifUrl ?? this.gifUrl,
      messageType: messageType ?? this.messageType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      reactions: reactions ?? this.reactions,
      reactionsCount: reactionsCount ?? this.reactionsCount,
      replyTo: replyTo ?? this.replyTo,
      deleted: deleted ?? this.deleted,
      deletedBy: deletedBy ?? this.deletedBy,
      starred: starred ?? this.starred,
      matchId: matchId ?? this.matchId,
      practiceId: practiceId ?? this.practiceId,
      meta: meta ?? this.meta,
      pollId: pollId ?? this.pollId,
      pin: pin ?? this.pin,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      mentions: mentions ?? _mentions,
      hasMentions: hasMentions ?? _hasMentions,
      mentionsCurrentUser: mentionsCurrentUser ?? _mentionsCurrentUser,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      compressionProgress: compressionProgress ?? this.compressionProgress,
      processingStatus: processingStatus ?? this.processingStatus,
    );
  }

  static Map<String, dynamic>? _safeMapFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    } else if (value is String && value.isNotEmpty) {
      // Try to parse as JSON string - but for now just return null
      // since practice details are usually already structured
      return null;
    }
    return null;
  }

  factory ClubMessage.fromJson(Map<String, dynamic> json) {
    // Handle content - it could be a string or an object with type/body
    String messageContent = '';
    String? messageType;
    String? gifUrl;
    List<MediaItem> media = [];
    MessageDocument? document;
    MessageAudio? audio;
    List<LinkMetadata> linkMeta = [];

    // New message type fields
    String? matchId;
    String? practiceId;
    String? pollId;

    // Check for deleted message
    bool isDeleted = false;
    String? deletedByName;

    final content = json['content'];

    // Check if message is deleted at top level first
    if (json['isDeleted'] == true) {
      isDeleted = true;
      // Try to get deletedBy from various possible locations
      if (content is Map<String, dynamic>) {
        deletedByName = content['deletedBy'] ?? content['deletedByName'];
      }
      deletedByName =
          deletedByName ?? json['deletedBy'] ?? json['deletedByName'];
      messageContent = '';
      messageType = 'deleted';
    } else if (content is String) {
      messageContent = content;
      messageType = 'text';
    } else if (content is Map<String, dynamic>) {
      // Check if message is deleted within content
      if (content['isDeleted'] == true || content['type'] == 'deleted') {
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
              media = [MediaItem.fromUrl(content['url'] as String)];
            }
            break;
          case 'text_with_images':
            if (content['images'] is List) {
              media = (content['images'] as List)
                  .map((url) => MediaItem.fromUrl(url as String))
                  .toList();
            }
            break;
          case 'text':
            // Handle new media array format (preferred)
            if (content['media'] is List &&
                (content['media'] as List).isNotEmpty) {
              media = (content['media'] as List)
                  .map(
                    (item) => MediaItem.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
            }
            // Fall back to legacy images array if no media array
            else if (content['images'] is List &&
                (content['images'] as List).isNotEmpty) {
              media = (content['images'] as List)
                  .map((url) => MediaItem.fromUrl(url as String))
                  .toList();
            }
            break;
          case 'link':
            if (content['url'] != null) {
              // Handle both old format (thumbnail) and new format (images array)
              String? linkImage;
              if (content['images'] is List &&
                  (content['images'] as List).isNotEmpty) {
                linkImage = (content['images'] as List).first;
              } else if (content['thumbnail'] != null) {
                linkImage = content['thumbnail'];
              }

              linkMeta = [
                LinkMetadata(
                  url: content['url'],
                  title: content['title'],
                  description: content['description'],
                  image: linkImage,
                  siteName: content['siteName'],
                  favicon: content['favicon'],
                ),
              ];
            }
            break;
          case 'document':
            if (content['url'] != null) {
              document = MessageDocument(
                url: content['url'],
                filename: content['name'] ?? 'document',
                type: content['name']?.split('.').last ?? 'file',
                size: content['size'],
              );
            }
            break;
          case 'audio':
            if (content['url'] != null) {
              audio = MessageAudio.fromJson({
                'url': content['url'],
                'filename':
                    content['name'] ?? content['filename'] ?? 'audio.m4a',
                'duration': content['duration'],
                'size': content['size'],
              });
              print(
                '🔍 ClubMessage.fromJson: Parsed audio from server: ${audio.filename}, duration: ${audio.duration}s',
              );
            }
            break;
        }
      }

      // Extract type-specific data from content for new message types
      if (messageType == 'match') {
        // Extract match-specific fields from content
        matchId = content['matchId'] as String?;
        // Meta is now a top-level field in the response
      } else if (messageType == 'practice') {
        // Extract practice-specific fields from content
        practiceId = content['practiceId'] as String?;
        // Meta is now a top-level field in the response
      } else if (messageType == 'poll') {
        // Extract poll-specific fields from content
        pollId = content['pollId'] as String?;
        // Meta is now a top-level field in the response
      }

      // Parse images array (as URLs) - for text messages and other non-link types
      if (content['images'] is List && messageType != 'link' && media.isEmpty) {
        media = (content['images'] as List)
            .map((url) => MediaItem.fromUrl(url as String))
            .toList();
      }

      // Parse pictures array (for backward compatibility)
      if (content['pictures'] is List && media.isEmpty) {
        final picturesList = content['pictures'] as List;
        media = picturesList
            .map((pic) {
              if (pic is String) {
                return MediaItem.fromUrl(pic);
              } else if (pic is Map<String, dynamic> && pic['url'] != null) {
                return MediaItem.fromUrl(pic['url'] as String);
              }
              return null;
            })
            .where((item) => item != null)
            .cast<MediaItem>()
            .toList();
      }

      // Note: meta field is deprecated - we only use the new linkSchema format now
    }

    // Parse top-level media array (preferred - from local storage)
    if (json['media'] is List && media.isEmpty) {
      media = (json['media'] as List)
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Parse top-level images array (for cache compatibility)
    if (json['images'] is List && media.isEmpty) {
      media = (json['images'] as List)
          .map((url) => MediaItem.fromUrl(url as String))
          .toList();
    }

    // Parse top-level audio object (for cache compatibility)
    if (json['audio'] is Map<String, dynamic> && audio == null) {
      audio = MessageAudio.fromJson(json['audio'] as Map<String, dynamic>);
      // Override messageType to audio if we found audio data
      messageType = 'audio';
    }
    // Parse top-level document object (for cache compatibility)
    if (json['document'] is Map<String, dynamic> && document == null) {
      document = MessageDocument.fromJson(
        json['document'] as Map<String, dynamic>,
      );
      // Override messageType to document if we found document data
      messageType = 'document';
    }

    // Check for top-level messageType field (for API consistency)
    if (json['messageType'] != null && !isDeleted) {
      messageType = json['messageType'];
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
    DateTime? deliveredAt;
    DateTime? readAt;

    if (json['status'] is Map<String, dynamic>) {
      final statusData = json['status'] as Map<String, dynamic>;

      // Parse timestamps from status object
      if (statusData['deliveredAt'] != null) {
        try {
          deliveredAt = DateTime.parse(statusData['deliveredAt']).toLocal();
        } catch (e) {
          debugPrint('⚠️ Error parsing deliveredAt: $e');
        }
      }

      if (statusData['readAt'] != null) {
        try {
          readAt = DateTime.parse(statusData['readAt']).toLocal();
        } catch (e) {
          debugPrint('⚠️ Error parsing readAt: $e');
        }
      }

      // Check for read status first (highest priority)
      if (statusData['read'] == true) {
        messageStatus = MessageStatus.read;
      } else if (statusData['delivered'] == true) {
        messageStatus = MessageStatus.delivered;
      } else {
        messageStatus = MessageStatus.sent;
      }
    } else if (json['status'] is String) {
      // Handle string status format (from cache)
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
    // Only override cache status if we have explicit receipt arrays from API
    if (json['readBy'] is List && (json['readBy'] as List).isNotEmpty) {
      // If there are any read receipts, prioritize read status
      messageStatus = MessageStatus.read;
    } else if (json['deliveredTo'] is List &&
        (json['deliveredTo'] as List).isNotEmpty) {
      // If there are delivery receipts but no read receipts, use delivered status
      // Only override if current status is sent (don't downgrade read to delivered)
      if (messageStatus == MessageStatus.sent) {
        messageStatus = MessageStatus.delivered;
      }
    }

    // Parse deliveredTo and readBy arrays
    List<Map<String, dynamic>> deliveredToList = [];
    List<Map<String, dynamic>> readByList = [];

    if (json['deliveredTo'] is List) {
      deliveredToList = (json['deliveredTo'] as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }

    if (json['readBy'] is List) {
      readByList = (json['readBy'] as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }

    // Parse mentions with defensive programming
    List<MentionedUser> mentions = [];
    bool hasMentions = false;
    bool mentionsCurrentUser = false;

    try {
      if (json['mentions'] is List && (json['mentions'] as List).isNotEmpty) {
        mentions = (json['mentions'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MentionedUser.fromJson)
            .toList();
        hasMentions = mentions.isNotEmpty;
      }
    } catch (e) {
      print('❌ Error parsing mentions in ClubMessage.fromJson: $e');
      mentions = [];
      hasMentions = false;
    }

    if (json['hasMentions'] is bool) {
      hasMentions = json['hasMentions'] as bool;
    }

    if (json['mentionsCurrentUser'] is bool) {
      mentionsCurrentUser = json['mentionsCurrentUser'] as bool;
    }

    return ClubMessage(
      id: json['messageId'] ?? json['id'] ?? '',
      clubId: json['clubId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: senderName,
      senderProfilePicture: senderProfilePicture,
      senderRole: senderRole,
      content: messageContent,
      media: media,
      document: document,
      audio: audio,
      linkMeta: linkMeta,
      gifUrl: gifUrl,
      messageType: messageType,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ).toLocal(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String).toLocal()
          : null,
      status: messageStatus, // Use the parsed status
      errorMessage: json['errorMessage'],
      reactions: reactions,
      reactionsCount: json['reactionsCount'] as int?,
      replyTo: replyTo,
      deleted: isDeleted,
      deletedBy: deletedByName,
      starred: starredInfo,
      matchId: matchId ?? (json['matchId'] as String?),
      practiceId: practiceId ?? (json['practiceId'] as String?),
      pollId: pollId ?? (json['pollId'] as String?),
      // Meta is now a top-level field in the message response
      meta: _safeMapFromJson(json['meta']),
      pin: PinInfo(
        isPinned: isPinned,
        pinStart: pinStart,
        pinEnd: pinEnd,
        pinnedBy: pinnedBy,
      ),
      // Use parsed timestamps from status object or fallback to direct fields
      deliveredAt:
          deliveredAt ??
          (json['deliveredAt'] != null
              ? DateTime.parse(json['deliveredAt']).toLocal()
              : null),
      readAt:
          readAt ??
          (json['readAt'] != null
              ? DateTime.parse(json['readAt']).toLocal()
              : null),
      deliveredTo: deliveredToList,
      readBy: readByList,
      mentions: mentions,
      hasMentions: hasMentions,
      mentionsCurrentUser: mentionsCurrentUser,
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
    // For link messages, format content as linkSchema structure
    dynamic contentJson;
    if (messageType == 'link' && linkMeta.isNotEmpty) {
      final linkData = linkMeta.first;
      contentJson = {
        'type': 'link',
        'url': linkData.url,
        'body': content,
        if (linkData.title != null) 'title': linkData.title,
        if (linkData.description != null) 'description': linkData.description,
        if (linkData.siteName != null) 'siteName': linkData.siteName,
        if (linkData.favicon != null) 'favicon': linkData.favicon,
        if (linkData.image != null) 'images': [linkData.image!],
      };
    } else if (messageType == 'emoji') {
      // For emoji messages, format content as emojiSchema structure
      contentJson = {'type': 'emoji', 'body': content};
    } else {
      contentJson = content;
    }

    return {
      'id': id,
      'messageId': id, // For API compatibility
      'clubId': clubId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfilePicture': senderProfilePicture,
      'senderRole': senderRole,
      'content': contentJson,
      'images': media
          .map((item) => item.url)
          .toList(), // Convert back to string array for API compatibility
      'media': media
          .map((item) => item.toJson())
          .toList(), // Full media objects for local storage
      'document': document?.toJson(),
      'audio': audio?.toJson(),
      'linkMeta': linkMeta.map((l) => l.toJson()).toList(),
      'gifUrl': gifUrl,
      'messageType': messageType,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString().split('.').last, // Convert enum to string
      'errorMessage': errorMessage,
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'replyTo': replyTo?.toJson(),
      'deleted': deleted,
      'deletedBy': deletedBy,
      'starred': starred.toJson(),
      'pin': pin.toJson(),
      'matchId': matchId,
      'practiceId': practiceId,
      'pollId': pollId,
      'meta': meta,
      // Local-only fields for storage
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }
}
