import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';

class ConversationProvider with ChangeNotifier {

  List<ConversationModel> _conversations = [];
  List<MessageModel> _messages = [];
  ConversationModel? _selectedConversation;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ConversationModel> get conversations => _conversations;
  List<MessageModel> get messages => _messages;
  ConversationModel? get selectedConversation => _selectedConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get total unread count across all conversations
  int get totalUnreadCount {
    return _conversations.fold(0, (sum, conversation) => sum + conversation.unreadCount);
  }

  // Get unread conversations
  List<ConversationModel> get unreadConversations {
    return _conversations.where((conversation) => conversation.unreadCount > 0).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Fetch all conversations for the user
  Future<void> fetchConversations() async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await ApiService.get('/conversations');
      
      if (response['success'] == true) {
        final List<dynamic> conversationData = response['data'] ?? [];
        _conversations = conversationData
            .map((json) => ConversationModel.fromJson(json))
            .toList();
        
        // Sort by last message time (most recent first)
        _conversations.sort((a, b) {
          final aTime = a.lastMessage?.createdAt ?? a.updatedAt;
          final bTime = b.lastMessage?.createdAt ?? b.updatedAt;
          return bTime.compareTo(aTime);
        });
      } else {
        _setError(response['message'] ?? 'Failed to fetch conversations');
      }
    } catch (e) {
      print('Error fetching conversations: $e');
      _setError('Unable to load conversations. Please check your connection.');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch messages for a specific conversation
  Future<void> fetchMessages(String conversationId, {int page = 1, int limit = 50}) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await ApiService.get(
        '/conversations/$conversationId/messages?page=$page&limit=$limit',
      );
      
      if (response['success'] == true) {
        final List<dynamic> messageData = response['data'] ?? [];
        final newMessages = messageData
            .map((json) => MessageModel.fromJson(json))
            .toList();
        
        if (page == 1) {
          _messages = newMessages;
        } else {
          _messages.addAll(newMessages);
        }
        
        // Sort by creation time (oldest first for chat display)
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else {
        _setError(response['message'] ?? 'Failed to fetch messages');
      }
    } catch (e) {
      print('Error fetching messages: $e');
      _setError('Unable to load messages. Please check your connection.');
    } finally {
      _setLoading(false);
    }
  }

  // Send a message
  Future<bool> sendMessage(String conversationId, String content, {MessageType type = MessageType.text}) async {
    try {
      _setError(null);

      final response = await ApiService.post('/conversations/$conversationId/messages', {
        'content': content,
        'type': type.toString().split('.').last,
      });
      
      if (response['success'] == true) {
        final messageData = response['data'];
        final newMessage = MessageModel.fromJson(messageData);
        
        // Add message to local list
        _messages.add(newMessage);
        
        // Update conversation's last message
        final conversationIndex = _conversations.indexWhere((c) => c.id == conversationId);
        if (conversationIndex != -1) {
          _conversations[conversationIndex] = _conversations[conversationIndex].copyWith(
            lastMessage: newMessage,
            updatedAt: newMessage.createdAt,
          );
        }
        
        notifyListeners();
        return true;
      } else {
        _setError(response['message'] ?? 'Failed to send message');
        return false;
      }
    } catch (e) {
      print('Error sending message: $e');
      _setError('Unable to send message. Please check your connection.');
      return false;
    }
  }

  // Send a rich content message
  Future<bool> sendRichMessage(
    String conversationId, 
    MessageType type, 
    Map<String, dynamic> richContent,
    {String? textContent}
  ) async {
    try {
      _setError(null);

      final response = await ApiService.post('/conversations/$conversationId/messages', {
        'content': textContent ?? '',
        'type': _messageTypeToString(type),
        'richContent': richContent,
      });
      
      if (response['success'] == true) {
        final messageData = response['data'];
        final newMessage = MessageModel.fromJson(messageData);
        
        // Add message to local list
        _messages.add(newMessage);
        
        // Update conversation's last message
        final conversationIndex = _conversations.indexWhere((c) => c.id == conversationId);
        if (conversationIndex != -1) {
          _conversations[conversationIndex] = _conversations[conversationIndex].copyWith(
            lastMessage: newMessage,
            updatedAt: newMessage.createdAt,
          );
        }
        
        notifyListeners();
        return true;
      } else {
        _setError(response['message'] ?? 'Failed to send message');
        return false;
      }
    } catch (e) {
      print('Error sending rich message: $e');
      _setError('Unable to send message. Please check your connection.');
      return false;
    }
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

  // Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final response = await ApiService.post('/conversations/$conversationId/mark-read', {});
      
      if (response['success'] == true) {
        // Update local conversation
        final conversationIndex = _conversations.indexWhere((c) => c.id == conversationId);
        if (conversationIndex != -1) {
          _conversations[conversationIndex] = _conversations[conversationIndex].copyWith(
            unreadCount: 0,
          );
        }
        
        // Mark local messages as read
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].conversationId == conversationId) {
            _messages[i] = _messages[i].copyWith(isRead: true);
          }
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error marking conversation as read: $e');
    }
  }

  // Select a conversation
  void selectConversation(ConversationModel conversation) {
    _selectedConversation = conversation;
    _messages.clear(); // Clear previous messages
    notifyListeners();
    
    // Fetch messages for selected conversation
    fetchMessages(conversation.id);
    
    // Mark as read if it has unread messages
    if (conversation.unreadCount > 0) {
      markConversationAsRead(conversation.id);
    }
  }

  // Clear selected conversation
  void clearSelectedConversation() {
    _selectedConversation = null;
    _messages.clear();
    notifyListeners();
  }

  // Refresh conversations (pull to refresh)
  Future<void> refreshConversations() async {
    await fetchConversations();
  }

  // Add a new message from real-time updates (WebSocket, etc.)
  void addIncomingMessage(MessageModel message) {
    // Add to messages if it's for the currently selected conversation
    if (_selectedConversation?.id == message.conversationId) {
      _messages.add(message);
    }
    
    // Update conversation's last message and unread count
    final conversationIndex = _conversations.indexWhere((c) => c.id == message.conversationId);
    if (conversationIndex != -1) {
      final conversation = _conversations[conversationIndex];
      final isCurrentlyViewing = _selectedConversation?.id == message.conversationId;
      
      _conversations[conversationIndex] = conversation.copyWith(
        lastMessage: message,
        updatedAt: message.createdAt,
        unreadCount: isCurrentlyViewing ? 0 : conversation.unreadCount + 1,
      );
      
      // Re-sort conversations
      _conversations.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.updatedAt;
        final bTime = b.lastMessage?.createdAt ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });
    }
    
    notifyListeners();
  }

  // Get conversation by ID
  ConversationModel? getConversationById(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Filter conversations by type
  List<ConversationModel> getConversationsByType(ConversationType type) {
    return _conversations.where((c) => c.type == type).toList();
  }

  // Search conversations
  List<ConversationModel> searchConversations(String query) {
    if (query.isEmpty) return _conversations;
    
    return _conversations.where((c) => 
      c.title.toLowerCase().contains(query.toLowerCase()) ||
      (c.description?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
      (c.lastMessage?.content.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();
  }

  // Clear all data
  void clear() {
    _conversations.clear();
    _messages.clear();
    _selectedConversation = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}