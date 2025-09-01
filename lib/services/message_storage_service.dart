import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club_message.dart';
import 'media_storage_service.dart';

class MessageStorageService {
  static const String _messagesKeyPrefix = 'club_messages_';
  static const String _lastSyncKeyPrefix = 'last_sync_';

  static String _getMessagesKey(String clubId) => '$_messagesKeyPrefix$clubId';
  static String _getLastSyncKey(String clubId) => '$_lastSyncKeyPrefix$clubId';

  /// Clear cached messages for a specific club (useful for model migrations)
  static Future<void> clearCachedMessages(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = _getMessagesKey(clubId);
      final lastSyncKey = _getLastSyncKey(clubId);
      
      await prefs.remove(messagesKey);
      await prefs.remove(lastSyncKey);
      
      print('🗑️ Cleared cached messages for club $clubId');
    } catch (e) {
      print('❌ Error clearing cached messages: $e');
    }
  }

  /// Save messages to local storage for a specific club
  static Future<void> saveMessages(String clubId, List<ClubMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = _getMessagesKey(clubId);
      final lastSyncKey = _getLastSyncKey(clubId);
      
      // Convert messages to JSON
      final messagesJson = messages.map((message) => message.toJson()).toList();
      final messagesString = jsonEncode(messagesJson);
      
      // Save messages and last sync time
      await prefs.setString(messagesKey, messagesString);
      await prefs.setString(lastSyncKey, DateTime.now().toIso8601String());
      
      print('💾 Saved ${messages.length} messages for club $clubId');
    } catch (e) {
      print('❌ Error saving messages to local storage: $e');
    }
  }

  /// Load messages from local storage for a specific club
  static Future<List<ClubMessage>> loadMessages(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = _getMessagesKey(clubId);
      
      final messagesString = prefs.getString(messagesKey);
      if (messagesString == null) {
        print('📭 No cached messages found for club $clubId');
        return [];
      }
      
      // Parse JSON to messages
      final List<dynamic> messagesJson = jsonDecode(messagesString);
      final messages = messagesJson
          .map((json) => ClubMessage.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('📬 Loaded ${messages.length} cached messages for club $clubId');
      return messages;
    } catch (e) {
      print('❌ Error loading messages from local storage: $e');
      return [];
    }
  }

  /// Get the last sync time for a specific club
  static Future<DateTime?> getLastSyncTime(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncKey = _getLastSyncKey(clubId);
      
      final lastSyncString = prefs.getString(lastSyncKey);
      if (lastSyncString == null) return null;
      
      return DateTime.parse(lastSyncString);
    } catch (e) {
      print('❌ Error getting last sync time: $e');
      return null;
    }
  }

  /// Check if messages need syncing (older than specified duration)
  static Future<bool> needsSync(String clubId, {Duration maxAge = const Duration(minutes: 5)}) async {
    final lastSync = await getLastSyncTime(clubId);
    if (lastSync == null) return true;
    
    final now = DateTime.now();
    final needsSync = now.difference(lastSync) > maxAge;
    
    print('🔄 Club $clubId needs sync: $needsSync (last sync: ${lastSync.toLocal()})');
    return needsSync;
  }

  /// Update a specific message in local storage (for pin/unpin operations)
  static Future<void> updateMessage(String clubId, ClubMessage updatedMessage) async {
    try {
      final messages = await loadMessages(clubId);
      final messageIndex = messages.indexWhere((m) => m.id == updatedMessage.id);
      
      if (messageIndex != -1) {
        messages[messageIndex] = updatedMessage;
        await saveMessages(clubId, messages);
        print('📝 Updated message ${updatedMessage.id} in local storage');
      } else {
        print('⚠️ Message ${updatedMessage.id} not found in local storage');
      }
    } catch (e) {
      print('❌ Error updating message in local storage: $e');
    }
  }

  /// Add a new message to local storage (for sent messages)
  static Future<void> addMessage(String clubId, ClubMessage newMessage) async {
    try {
      final messages = await loadMessages(clubId);
      
      // Check if message already exists (avoid duplicates)
      final existingIndex = messages.indexWhere((m) => m.id == newMessage.id);
      if (existingIndex != -1) {
        // Update existing message
        messages[existingIndex] = newMessage;
      } else {
        // Add new message
        messages.add(newMessage);
      }
      
      // Sort by creation time
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      await saveMessages(clubId, messages);
      print('➕ Added/updated message ${newMessage.id} in local storage');
    } catch (e) {
      print('❌ Error adding message to local storage: $e');
    }
  }

  /// Clear all messages for a specific club
  static Future<void> clearMessages(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = _getMessagesKey(clubId);
      final lastSyncKey = _getLastSyncKey(clubId);
      
      await prefs.remove(messagesKey);
      await prefs.remove(lastSyncKey);
      
      print('🗑️ Cleared all messages for club $clubId');
    } catch (e) {
      print('❌ Error clearing messages: $e');
    }
  }

  /// Save messages with media download
  static Future<void> saveMessagesWithMedia(String clubId, List<ClubMessage> messages) async {
    try {
      print('💾 Saving ${messages.length} messages with media for club $clubId');
      
      // Save messages first
      await saveMessages(clubId, messages);
      
      // Extract and download media in background
      _downloadMediaInBackground(clubId, messages);
    } catch (e) {
      print('❌ Error saving messages with media: $e');
    }
  }

  /// Download media files in background
  static Future<void> _downloadMediaInBackground(String clubId, List<ClubMessage> messages) async {
    try {
      final mediaUrls = <Map<String, dynamic>>[];
      
      for (final message in messages) {
        // Extract images
        for (final picture in message.pictures) {
          mediaUrls.add({
            'url': picture.url,
            'type': 'image',
            'messageId': message.id,
          });
        }
        
        // Extract documents
        for (final document in message.documents) {
          mediaUrls.add({
            'url': document.url,
            'type': 'document',
            'messageId': message.id,
            'filename': document.filename,
          });
        }
        
        // Extract audio
        if (message.audio != null) {
          mediaUrls.add({
            'url': message.audio!.url,
            'type': 'audio',
            'messageId': message.id,
            'duration': message.audio!.duration,
          });
        }
        
        // Extract GIFs
        if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
          mediaUrls.add({
            'url': message.gifUrl!,
            'type': 'gif',
            'messageId': message.id,
          });
        }
      }
      
      if (mediaUrls.isNotEmpty) {
        // Download media asynchronously
        MediaStorageService.downloadAllMediaForClub(clubId, mediaUrls);
      }
    } catch (e) {
      print('❌ Error downloading media in background: $e');
    }
  }

  /// Compare local and server messages to find differences
  static Map<String, dynamic> compareMessages(
    List<ClubMessage> localMessages, 
    List<ClubMessage> serverMessages
  ) {
    final localMap = {for (var msg in localMessages) msg.id: msg};
    final serverMap = {for (var msg in serverMessages) msg.id: msg};
    
    // Find new messages on server
    final newMessages = serverMessages
        .where((msg) => !localMap.containsKey(msg.id))
        .toList();
    
    // Find updated messages (compare timestamps or content)
    final updatedMessages = <ClubMessage>[];
    for (final serverMsg in serverMessages) {
      final localMsg = localMap[serverMsg.id];
      if (localMsg != null && _hasMessageChanged(localMsg, serverMsg)) {
        updatedMessages.add(serverMsg);
      }
    }
    
    // Find deleted messages (in local but not on server)
    final deletedMessageIds = localMessages
        .where((msg) => !serverMap.containsKey(msg.id))
        .map((msg) => msg.id)
        .toList();
    
    return {
      'new': newMessages,
      'updated': updatedMessages,
      'deleted': deletedMessageIds,
      'needsUpdate': newMessages.isNotEmpty || 
                     updatedMessages.isNotEmpty || 
                     deletedMessageIds.isNotEmpty,
    };
  }

  /// Check if a message has changed
  static bool _hasMessageChanged(ClubMessage local, ClubMessage server) {
    // Compare key fields that might change
    return local.content != server.content ||
           local.pin.isPinned != server.pin.isPinned ||
           local.pin.pinStart != server.pin.pinStart ||
           local.starred.isStarred != server.starred.isStarred ||
           local.deleted != server.deleted ||
           local.reactions.length != server.reactions.length;
  }

  /// Merge server messages with local data (preserving read/delivered status)
  static List<ClubMessage> mergeMessagesWithLocalData(
    List<ClubMessage> serverMessages,
    List<ClubMessage> localMessages,
  ) {
    final localMap = {for (var msg in localMessages) msg.id: msg};
    final mergedMessages = <ClubMessage>[];
    
    for (final serverMsg in serverMessages) {
      final localMsg = localMap[serverMsg.id];
      
      if (localMsg != null) {
        // Preserve local read/delivered status
        final merged = serverMsg.copyWith(
          deliveredAt: localMsg.deliveredAt,
          readAt: localMsg.readAt,
        );
        mergedMessages.add(merged);
      } else {
        // New message from server
        mergedMessages.add(serverMsg);
      }
    }
    
    return mergedMessages;
  }

  /// Get last message timestamp for efficient sync
  static Future<DateTime?> getLastMessageTimestamp(String clubId) async {
    try {
      final messages = await loadMessages(clubId);
      if (messages.isEmpty) return null;
      
      // Sort messages by creation time and get the latest
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return messages.first.createdAt;
    } catch (e) {
      print('❌ Error getting last message timestamp: $e');
      return null;
    }
  }

  /// Set offline mode flag
  static Future<void> setOfflineMode(String clubId, bool isOffline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('offline_mode_$clubId', isOffline);
    } catch (e) {
      print('❌ Error setting offline mode: $e');
    }
  }

  /// Check if in offline mode
  static Future<bool> isOfflineMode(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('offline_mode_$clubId') ?? false;
    } catch (e) {
      print('❌ Error checking offline mode: $e');
      return false;
    }
  }

  /// Get storage info for debugging
  static Future<Map<String, dynamic>> getStorageInfo(String clubId) async {
    try {
      final messages = await loadMessages(clubId);
      final lastSync = await getLastSyncTime(clubId);
      final needsSync = await MessageStorageService.needsSync(clubId);
      final lastMessage = await getLastMessageTimestamp(clubId);
      final isOffline = await isOfflineMode(clubId);
      final mediaStats = await MediaStorageService.getStorageStats(clubId);
      final deliveredIds = await getDeliveredMessageIds(clubId);
      final readIds = await getReadMessageIds(clubId);
      
      return {
        'messageCount': messages.length,
        'lastSync': lastSync?.toLocal().toString(),
        'needsSync': needsSync,
        'isOfflineMode': isOffline,
        'lastMessageAt': lastMessage?.toLocal().toString(),
        'oldestMessage': messages.isNotEmpty 
            ? messages.first.createdAt.toLocal().toString() 
            : null,
        'newestMessage': messages.isNotEmpty 
            ? messages.last.createdAt.toLocal().toString() 
            : null,
        'deliveredCount': deliveredIds.length,
        'readCount': readIds.length,
        'media': mediaStats,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Mark a message as delivered (persistent)
  static Future<void> markAsDelivered(String clubId, String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'delivered_${clubId}_$messageId';
      await prefs.setBool(key, true);
      print('📧 Marked message $messageId as delivered');
    } catch (e) {
      print('❌ Error marking message as delivered: $e');
    }
  }

  /// Mark a message as read (persistent)
  static Future<void> markAsRead(String clubId, String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'read_${clubId}_$messageId';
      await prefs.setBool(key, true);
      print('👁️ Marked message $messageId as read');
    } catch (e) {
      print('❌ Error marking message as read: $e');
    }
  }

  /// Check if a message has been marked as delivered
  static Future<bool> isMarkedAsDelivered(String clubId, String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'delivered_${clubId}_$messageId';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      print('❌ Error checking delivered status: $e');
      return false;
    }
  }

  /// Check if a message has been marked as read
  static Future<bool> isMarkedAsRead(String clubId, String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'read_${clubId}_$messageId';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      print('❌ Error checking read status: $e');
      return false;
    }
  }

  /// Get all delivered message IDs for a club
  static Future<Set<String>> getDeliveredMessageIds(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final prefix = 'delivered_${clubId}_';
      
      return keys
          .where((key) => key.startsWith(prefix) && prefs.getBool(key) == true)
          .map((key) => key.substring(prefix.length))
          .toSet();
    } catch (e) {
      print('❌ Error getting delivered message IDs: $e');
      return <String>{};
    }
  }

  /// Get all read message IDs for a club
  static Future<Set<String>> getReadMessageIds(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final prefix = 'read_${clubId}_';
      
      return keys
          .where((key) => key.startsWith(prefix) && prefs.getBool(key) == true)
          .map((key) => key.substring(prefix.length))
          .toSet();
    } catch (e) {
      print('❌ Error getting read message IDs: $e');
      return <String>{};
    }
  }

  /// Clear delivered/read status for a specific club
  static Future<void> clearStatusFlags(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Remove all delivered and read flags for this club
      final keysToRemove = keys
          .where((key) => 
              key.startsWith('delivered_${clubId}_') || 
              key.startsWith('read_${clubId}_'))
          .toList();
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      print('🗑️ Cleared ${keysToRemove.length} status flags for club $clubId');
    } catch (e) {
      print('❌ Error clearing status flags: $e');
    }
  }

  /// Clear all club data including media and status flags
  static Future<void> clearClubData(String clubId) async {
    try {
      print('🗑️ Clearing all data for club $clubId');
      
      // Clear messages
      await clearMessages(clubId);
      
      // Clear media
      await MediaStorageService.clearClubMedia(clubId);
      
      // Clear status flags
      await clearStatusFlags(clubId);
      
      // Clear offline mode flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_mode_$clubId');
      
      print('✅ All data cleared for club $clubId');
    } catch (e) {
      print('❌ Error clearing club data: $e');
    }
  }
}