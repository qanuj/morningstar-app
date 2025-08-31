import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club_message.dart';

class MessageStorageService {
  static const String _messagesKeyPrefix = 'club_messages_';
  static const String _lastSyncKeyPrefix = 'last_sync_';

  static String _getMessagesKey(String clubId) => '$_messagesKeyPrefix$clubId';
  static String _getLastSyncKey(String clubId) => '$_lastSyncKeyPrefix$clubId';

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

  /// Get storage info for debugging
  static Future<Map<String, dynamic>> getStorageInfo(String clubId) async {
    try {
      final messages = await loadMessages(clubId);
      final lastSync = await getLastSyncTime(clubId);
      final needsSync = await MessageStorageService.needsSync(clubId);
      
      return {
        'messageCount': messages.length,
        'lastSync': lastSync?.toLocal().toString(),
        'needsSync': needsSync,
        'oldestMessage': messages.isNotEmpty 
            ? messages.first.createdAt.toLocal().toString() 
            : null,
        'newestMessage': messages.isNotEmpty 
            ? messages.last.createdAt.toLocal().toString() 
            : null,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}