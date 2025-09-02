import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/club_message.dart';
import '../models/message_reaction.dart';
import 'api_service.dart';

/// Service class for handling all chat-related API operations
class ChatApiService {
  // Private constructor to prevent instantiation
  ChatApiService._();

  // Message Operations
  
  /// Fetch messages for a conversation/club
  static Future<Map<String, dynamic>?> getMessages(String clubId) async {
    try {
      final response = await ApiService.get(
        '/conversations/$clubId/messages',
      );
      return response;
    } catch (e) {
      print('❌ Error fetching messages: $e');
      return null;
    }
  }

  /// Send a text message
  static Future<Map<String, dynamic>?> sendMessage(
    String clubId,
    Map<String, dynamic> messageData,
  ) async {
    try {
      final response = await ApiService.post(
        '/conversations/$clubId/messages',
        messageData,
      );
      return response;
    } catch (e) {
      print('❌ Error sending message: $e');
      return null;
    }
  }

  /// Send a message with uploaded media
  static Future<Map<String, dynamic>?> sendMessageWithMedia(
    String clubId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      final response = await ApiService.post(
        '/conversations/$clubId/messages',
        requestData,
      );
      return response;
    } catch (e) {
      print('❌ Error sending message with media: $e');
      return null;
    }
  }

  /// Send a message with documents
  static Future<Map<String, dynamic>?> sendMessageWithDocuments(
    String clubId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      final response = await ApiService.post(
        '/conversations/$clubId/messages',
        requestData,
      );
      return response;
    } catch (e) {
      print('❌ Error sending message with documents: $e');
      return null;
    }
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
  static Future<Map<String, dynamic>?> getMessageStatus(
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
      return null;
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
      await ApiService.delete(
        '/conversations/$clubId/messages/$messageId/pin',
      );
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
}