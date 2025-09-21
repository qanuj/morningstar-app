import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/message_reaction.dart';
import 'api_service.dart';
import 'match_service.dart';

/// Service class for handling all chat-related API operations
class ChatApiService {
  // Private constructor to prevent instantiation
  ChatApiService._();

  // Message Operations

  /// Fetch messages for a conversation/club
  static Future<Map<String, dynamic>?> getMessages(String clubId) async {
    try {
      final response = await ApiService.get('/conversations/$clubId/messages');
      return response;
    } catch (e) {
      print('❌ Error fetching messages: $e');
      return null;
    }
  }

  /// Fetch messages efficiently with sync support (Telegram-style)
  static Future<Map<String, dynamic>?> getMessagesEfficient(
    String clubId, {
    String? lastMessageId,
    bool forceFullSync = false,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'syncMode': forceFullSync ? 'full' : 'incremental',
        'limit': limit.toString(),
      };

      if (lastMessageId != null && !forceFullSync) {
        queryParams['lastMessageId'] = lastMessageId;
      }

      final response = await ApiService.get(
        '/conversations/$clubId/messages',
        queryParams: queryParams,
      );
      return response;
    } catch (e) {
      print('❌ Error fetching messages efficiently: $e');
      return null;
    }
  }

  /// Send any type of message - handles content formatting based on message type
  static Future<Map<String, dynamic>?> sendMessage(
    String clubId,
    Map<String, dynamic> messageData,
  ) async {
    try {
      // Format the content based on message type
      final formattedData = _formatMessageContent(messageData);

      final response = await ApiService.post(
        '/conversations/$clubId/messages',
        formattedData,
      );
      return response;
    } catch (e) {
      print('❌ Error sending message: $e');
      return null;
    }
  }

  /// Format message content based on message type and data
  static Map<String, dynamic> _formatMessageContent(
    Map<String, dynamic> messageData,
  ) {
    // Extract the raw message data
    final content = messageData['content'];
    final messageType = content?['type'] ?? 'text';
    final replyToId = messageData['replyToId'];

    Map<String, dynamic> contentMap;

    switch (messageType) {
      case 'practice':
        contentMap = {
          'type': 'practice',
          'body': content['body'] ?? ' ',
          'practiceId': content['practiceId'],
          'meta': content['practiceDetails'] ?? content['meta'],
        };
        break;

      case 'match':
        contentMap = {
          'type': 'match',
          'body': content['body'] ?? ' ',
          'matchId': content['matchId'],
          'meta': content['matchDetails'] ?? content['meta'],
        };
        break;

      case 'poll':
        contentMap = {
          'type': 'poll',
          'body': content['body'] ?? ' ',
          'pollId': content['pollId'],
          'meta': content['pollDetails'] ?? content['meta'],
        };
        break;

      case 'location':
        contentMap = {
          'type': 'location',
          'body': content['body'] ?? ' ',
          'meta': content['locationDetails'] ?? content['meta'],
        };
        break;

      case 'link':
        contentMap = {
          'type': 'link',
          'url': content['url'],
          'body': content['body'] ?? ' ',
        };
        // Add optional fields only if they exist
        if (content['title'] != null &&
            content['title'].toString().isNotEmpty) {
          contentMap['title'] = content['title'];
        }
        if (content['description'] != null &&
            content['description'].toString().isNotEmpty) {
          contentMap['description'] = content['description'];
        }
        if (content['images'] != null &&
            content['images'] is List &&
            (content['images'] as List).isNotEmpty) {
          contentMap['images'] = content['images'];
        }
        break;

      case 'document':
        contentMap = {
          'type': 'document',
          'url': content['url'],
          'name': content['name'],
          'size': content['size'],
        };
        break;

      case 'audio':
        contentMap = {
          'type': 'audio',
          'url': content['url'],
          'duration': content['duration'],
          'size': content['size']?.toString(),
        };
        break;

      case 'text':
      case 'emoji':
      default:
        // Text messages (including with media attachments)
        contentMap = {
          'type': messageType,
          'body': content['body'] ?? content['content'] ?? ' ',
        };

        // Add media arrays if present
        if (content['images'] != null &&
            content['images'] is List &&
            (content['images'] as List).isNotEmpty) {
          contentMap['images'] = content['images'];
        }
        if (content['videos'] != null &&
            content['videos'] is List &&
            (content['videos'] as List).isNotEmpty) {
          contentMap['videos'] = content['videos'];
        }
        break;
    }

    final requestData = {'content': contentMap};

    // Add replyToId if present
    if (replyToId != null) {
      requestData['replyToId'] = replyToId;
    }

    print('🔍 ChatApiService: Formatted content for $messageType: $contentMap');
    return requestData;
  }

  // Message Status Operations

  /// Mark a message as delivered
  static Future<bool> markAsDelivered(String clubId, String messageId) async {
    try {
      await ApiService.post(
        '/conversations/$clubId/messages/$messageId/delivered',
        {},
      );
      return true;
    } catch (e) {
      print('❌ Error marking message as delivered: $e');
      return false;
    }
  }

  /// Mark a message as read
  static Future<bool> markAsRead(String clubId, String messageId) async {
    try {
      await ApiService.post(
        '/conversations/$clubId/messages/$messageId/read',
        {},
      );
      return true;
    } catch (e) {
      print('❌ Error marking message as read: $e');
      return false;
    }
  }

  /// Get message status
  static Future<Map<String, dynamic>> getMessageStatus(
    String clubId,
    String messageId,
  ) async {
    try {
      final response = await ApiService.get(
        '/conversations/$clubId/messages/$messageId/status',
      );
      return response;
    } catch (e) {
      print('❌ Error getting message status: $e');
      throw Exception('Failed to get message status: $e');
    }
  }

  /// Update message status (generic method for different endpoints)
  static Future<bool> updateMessageStatus(
    String clubId,
    String messageId,
    String endpoint,
  ) async {
    try {
      await ApiService.post(
        '/conversations/$clubId/messages/$messageId$endpoint',
        {},
      );
      return true;
    } catch (e) {
      print('❌ Error updating message status: $e');
      return false;
    }
  }

  // Message Management Operations

  /// Delete messages
  static Future<bool> deleteMessages(
    String clubId,
    List<String> messageIds,
  ) async {
    try {
      await ApiService.delete(
        '/conversations/$clubId/messages/delete',
        messageIds,
      );
      return true;
    } catch (e) {
      print('❌ Error deleting messages: $e');
      return false;
    }
  }

  /// Add reaction to message
  static Future<bool> addReaction(
    String clubId,
    String messageId,
    MessageReaction reaction,
  ) async {
    try {
      await ApiService.post(
        '/conversations/$clubId/messages/$messageId/reactions',
        reaction.toJson(),
      );
      return true;
    } catch (e) {
      print('❌ Error adding reaction: $e');
      return false;
    }
  }

  /// Remove all reactions from message by current user
  static Future<bool> removeReaction(String clubId, String messageId) async {
    try {
      await ApiService.delete(
        '/conversations/$clubId/messages/$messageId/reactions',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error removing reaction: $e');
      return false;
    }
  }

  /// Update existing reaction emoji
  static Future<bool> updateReaction(
    String clubId,
    String messageId,
    String emoji,
  ) async {
    try {
      await ApiService.put(
        '/conversations/$clubId/messages/$messageId/reactions',
        {'emoji': emoji},
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error updating reaction: $e');
      return false;
    }
  }

  /// Star a message
  static Future<bool> starMessage(String clubId, String messageId) async {
    try {
      await ApiService.post(
        '/conversations/$clubId/messages/$messageId/star',
        {},
      );
      return true;
    } catch (e) {
      print('❌ Error starring message: $e');
      return false;
    }
  }

  /// Unstar a message
  static Future<bool> unstarMessage(String clubId, String messageId) async {
    try {
      await ApiService.delete(
        '/conversations/$clubId/messages/$messageId/star',
      );
      return true;
    } catch (e) {
      print('❌ Error unstarring message: $e');
      return false;
    }
  }

  /// Delete a single message
  static Future<bool> deleteMessage(String clubId, String messageId) async {
    try {
      await ApiService.delete('/conversations/$clubId/messages/$messageId');
      return true;
    } catch (e) {
      print('❌ Error deleting message: $e');
      return false;
    }
  }

  /// Pin a message
  static Future<bool> pinMessage(
    String clubId,
    String messageId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      await ApiService.post(
        '/conversations/$clubId/messages/$messageId/pin',
        requestData,
      );
      return true;
    } catch (e) {
      print('❌ Error pinning message: $e');
      return false;
    }
  }

  /// Unpin a message
  static Future<bool> unpinMessage(String clubId, String messageId) async {
    try {
      await ApiService.delete('/conversations/$clubId/messages/$messageId/pin');
      return true;
    } catch (e) {
      print('❌ Error unpinning message: $e');
      return false;
    }
  }

  // File Operations

  /// Upload a file and return the URL - delegates to ApiService
  static Future<String?> uploadFile(PlatformFile file) async {
    return await ApiService.uploadFile(file);
  }

  // Utility Methods

  /// Fetch image from URL for paste functionality
  static Future<List<int>?> fetchImageFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('❌ Error fetching image: $e');
      return null;
    }
  }

  // Match Message Operations

  /// RSVP to a match from a chat message
  static Future<bool> rsvpToMatch(
    String clubId,
    String messageId,
    String matchId,
    String status, // Expected: 'YES', 'NO', 'MAYBE', 'PENDING'
  ) async {
    try {
      final response = await MatchService.rsvpToMatch(
        matchId: matchId,
        status: status,
      );

      final isSuccess = response['success'] == true || response['rsvp'] != null;
      return isSuccess;
    } catch (e) {
      print('❌ Error RSVP to match: $e');
      return false;
    }
  }

  /// Get RSVP status for a match message
  static Future<Map<String, dynamic>?> getMatchRSVPStatus(
    String clubId,
    String messageId,
    String matchId,
  ) async {
    try {
      final response = await ApiService.get(
        '/conversations/$clubId/messages/$messageId/match/rsvp?matchId=$matchId',
      );
      return response;
    } catch (e) {
      print('❌ Error getting match RSVP status: $e');
      return null;
    }
  }

  // Soft Delete Operations (Telegram-style)

  /// Soft delete messages (user-specific, like Telegram)
  static Future<bool> softDeleteMessages(
    String clubId,
    List<String> messageIds,
  ) async {
    try {
      await ApiService.put('/conversations/$clubId/messages', {
        'messageIds': messageIds,
        'action': 'soft_delete',
      });
      return true;
    } catch (e) {
      print('❌ Error soft deleting messages: $e');
      return false;
    }
  }

  /// Restore soft deleted messages
  static Future<bool> restoreMessages(
    String clubId,
    List<String> messageIds,
  ) async {
    try {
      await ApiService.put('/conversations/$clubId/messages', {
        'messageIds': messageIds,
        'action': 'restore',
      });
      return true;
    } catch (e) {
      print('❌ Error restoring messages: $e');
      return false;
    }
  }
}
