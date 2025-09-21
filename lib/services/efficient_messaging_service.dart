import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club_message.dart';
import '../models/message_status.dart';
import '../services/chat_api_service.dart';
import '../services/api_service.dart';

/// Efficient messaging service that works like Telegram
/// - Only fetches new messages since last sync
/// - Tracks user-specific sync state on server
/// - Supports soft delete (local only)
/// - Automatically marks messages as delivered/read
class EfficientMessagingService {
  static const String _lastSyncPrefix = 'efficient_sync_';
  static const String _deletedPrefix = 'deleted_messages_';

  /// Get sync key for a club
  static String _getSyncKey(String clubId) => '$_lastSyncPrefix$clubId';

  /// Get deleted messages key for a club
  static String _getDeletedKey(String clubId) => '$_deletedPrefix$clubId';

  /// Fetch new messages efficiently (only new ones since last sync)
  static Future<List<ClubMessage>> fetchNewMessages(String clubId, {
    bool forceFullSync = false,
  }) async {
    try {
      // Get last message ID from local storage
      String? lastMessageId;
      if (!forceFullSync) {
        lastMessageId = await _getLastMessageId(clubId);
      }

      // Build query parameters for sync
      final queryParams = <String, String>{
        'syncMode': forceFullSync ? 'full' : 'incremental',
        'limit': '50',
      };

      if (lastMessageId != null && !forceFullSync) {
        queryParams['lastMessageId'] = lastMessageId;
      }

      print('🔄 Fetching messages efficiently');
      print('📱 Last message ID: $lastMessageId');
      print('🎯 Sync mode: ${forceFullSync ? "full" : "incremental"}');

      // Use ChatApiService for efficient message fetching
      final data = await ChatApiService.getMessagesEfficient(
        clubId,
        lastMessageId: lastMessageId,
        forceFullSync: forceFullSync,
        limit: 50,
      );

      if (data == null) {
        throw Exception('Failed to fetch messages from server');
      }

      final messagesData = data['messages'] as List<dynamic>;
      final syncInfo = data['syncInfo'];

      print('✅ Received ${messagesData.length} messages');
      if (syncInfo != null) {
        print('📊 Sync info: hasMore=${syncInfo['hasMore']}, messageCount=${syncInfo['messageCount']}');
      }

      // Convert to ClubMessage objects
      final messages = messagesData
          .map((json) => ClubMessage.fromJson(json))
          .toList();

      // Update last sync state if we got new messages
      if (messages.isNotEmpty) {
        final newestMessage = messages.last; // API returns in chronological order
        await _saveLastMessageId(clubId, newestMessage.id);
        print('💾 Saved last message ID: ${newestMessage.id}');
      }

      // Filter out user-deleted messages
      final filteredMessages = await filterDeletedMessages(clubId, messages);
      print('🎯 Returning ${filteredMessages.length} messages after filtering');

      return filteredMessages;
    } catch (e) {
      print('❌ Error in fetchNewMessages: $e');
      rethrow;
    }
  }

  /// Soft delete messages (local only, like Telegram)
  static Future<bool> softDeleteMessages(String clubId, List<String> messageIds) async {
    try {
      // Use ChatApiService for soft delete
      final success = await ChatApiService.softDeleteMessages(clubId, messageIds);

      if (success) {
        // Also update local deleted list for immediate UI feedback
        final deletedIds = await _getDeletedMessageIds(clubId);
        final newDeletedIds = [...deletedIds, ...messageIds].toSet().toList();
        await _saveDeletedMessageIds(clubId, newDeletedIds);

        print('🗑️ Soft deleted ${messageIds.length} messages');
      }

      return success;
    } catch (e) {
      print('❌ Error in softDeleteMessages: $e');
      return false;
    }
  }

  /// Restore soft deleted messages
  static Future<bool> restoreMessages(String clubId, List<String> messageIds) async {
    try {
      // Use ChatApiService for restore
      final success = await ChatApiService.restoreMessages(clubId, messageIds);

      if (success) {
        // Also update local deleted list
        final deletedIds = await _getDeletedMessageIds(clubId);
        final newDeletedIds = deletedIds.where((id) => !messageIds.contains(id)).toList();
        await _saveDeletedMessageIds(clubId, newDeletedIds);

        print('↩️ Restored ${messageIds.length} messages');
      }

      return success;
    } catch (e) {
      print('❌ Error in restoreMessages: $e');
      return false;
    }
  }

  /// Mark messages as delivered using existing ChatApiService
  static Future<bool> markAsDelivered(String clubId, List<String> messageIds) async {
    try {
      // Use existing ChatApiService to mark each message as delivered
      final results = await Future.wait(
        messageIds.map((messageId) async {
          try {
            return await ChatApiService.markAsDelivered(clubId, messageId);
          } catch (e) {
            print('❌ Failed to mark message $messageId as delivered: $e');
            return false;
          }
        }),
      );

      final successCount = results.where((success) => success).length;
      print('📧 Marked $successCount/${messageIds.length} messages as delivered');

      return successCount > 0;
    } catch (e) {
      print('❌ Error in markAsDelivered: $e');
      return false;
    }
  }

  /// Mark messages as read using existing ChatApiService
  static Future<bool> markAsRead(String clubId, List<String> messageIds) async {
    try {
      // Use existing ChatApiService to mark each message as read
      final results = await Future.wait(
        messageIds.map((messageId) async {
          try {
            return await ChatApiService.markAsRead(clubId, messageId);
          } catch (e) {
            print('❌ Failed to mark message $messageId as read: $e');
            return false;
          }
        }),
      );

      final successCount = results.where((success) => success).length;
      print('👁️ Marked $successCount/${messageIds.length} messages as read');

      return successCount > 0;
    } catch (e) {
      print('❌ Error in markAsRead: $e');
      return false;
    }
  }

  /// Clear all sync state for a club (useful for logout or reset)
  static Future<void> clearSyncState(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getSyncKey(clubId));
      await prefs.remove(_getDeletedKey(clubId));
      print('🗑️ Cleared sync state for club $clubId');
    } catch (e) {
      print('❌ Error clearing sync state: $e');
    }
  }

  /// Get last message ID from local storage
  static Future<String?> _getLastMessageId(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_getSyncKey(clubId));
    } catch (e) {
      print('❌ Error getting last message ID: $e');
      return null;
    }
  }

  /// Save last message ID to local storage
  static Future<void> _saveLastMessageId(String clubId, String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getSyncKey(clubId), messageId);
    } catch (e) {
      print('❌ Error saving last message ID: $e');
    }
  }

  /// Get locally deleted message IDs
  static Future<List<String>> _getDeletedMessageIds(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsString = prefs.getString(_getDeletedKey(clubId));
      if (idsString == null) return [];

      final ids = jsonDecode(idsString) as List<dynamic>;
      return ids.cast<String>();
    } catch (e) {
      print('❌ Error getting deleted message IDs: $e');
      return [];
    }
  }

  /// Save locally deleted message IDs
  static Future<void> _saveDeletedMessageIds(String clubId, List<String> messageIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getDeletedKey(clubId), jsonEncode(messageIds));
    } catch (e) {
      print('❌ Error saving deleted message IDs: $e');
    }
  }

  /// Filter out user-deleted messages
  static Future<List<ClubMessage>> filterDeletedMessages(String clubId, List<ClubMessage> messages) async {
    try {
      final deletedIds = await _getDeletedMessageIds(clubId);
      if (deletedIds.isEmpty) return messages;

      final filteredMessages = messages.where((message) => !deletedIds.contains(message.id)).toList();

      if (filteredMessages.length != messages.length) {
        print('🎯 Filtered out ${messages.length - filteredMessages.length} deleted messages');
      }

      return filteredMessages;
    } catch (e) {
      print('❌ Error filtering deleted messages: $e');
      return messages;
    }
  }

  /// Get sync statistics for debugging
  static Future<Map<String, dynamic>> getSyncStats(String clubId) async {
    try {
      final lastMessageId = await _getLastMessageId(clubId);
      final deletedIds = await _getDeletedMessageIds(clubId);

      return {
        'clubId': clubId,
        'lastMessageId': lastMessageId,
        'deletedCount': deletedIds.length,
        'hasLocalState': lastMessageId != null || deletedIds.isNotEmpty,
      };
    } catch (e) {
      return {
        'clubId': clubId,
        'error': e.toString(),
      };
    }
  }
}