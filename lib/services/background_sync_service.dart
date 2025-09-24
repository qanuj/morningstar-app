import 'dart:async';
import '../models/club_message.dart';
import '../providers/club_provider.dart';
import 'auth_service.dart';
import 'chat_api_service.dart';
import 'message_storage_service.dart';

/// Background sync service for real-time message updates without push notifications
/// Handles RSVP, Vote, Match, Practice, Reactions, Pinned messages, etc.
class BackgroundSyncService {
  static Timer? _syncTimer;
  static bool _isInitialized = false;
  static bool _isSyncing = false;
  static ClubProvider? _clubProvider;
  static final Map<String, DateTime> _lastSyncTimes = {};
  static final Map<String, DateTime> _lastUpdatedAtTimes = {};
  static final Map<String, String?> _lastMessageIds = {};
  static final Map<String, Function(Map<String, dynamic>)> _messageCallbacks =
      {};
  static final Map<String, List<Function(Map<String, dynamic>)>>
  _matchCallbacks = {};

  // Sync configuration
  static const Duration _syncInterval = Duration(
    seconds: 30,
  ); // Sync every 30 seconds
  static const Duration _activeSyncInterval = Duration(
    seconds: 10,
  ); // More frequent when active
  static bool _isAppActive = true;

  /// Initialize the background sync service
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('🔄 Background sync service already initialized');
      return;
    }

    try {
      // Check if user is authenticated
      final user = await AuthService.getCurrentUser();
      if (user.isEmpty) {
        print('⚠️ Cannot initialize background sync: user not authenticated');
        return;
      }

      _isInitialized = true;
      _startSyncTimer();

      print('✅ Background sync service initialized');
    } catch (e) {
      print('❌ Failed to initialize background sync service: $e');
    }
  }

  /// Start the sync timer
  static void _startSyncTimer() {
    _syncTimer?.cancel();

    final interval = _isAppActive ? _activeSyncInterval : _syncInterval;
    _syncTimer = Timer.periodic(interval, (timer) async {
      if (!_isSyncing) {
        await _performSync();
      }
    });

    print(
      '🔄 Background sync timer started with ${interval.inSeconds}s interval',
    );
  }

  /// Set app active state to adjust sync frequency
  static void setAppActiveState(bool isActive) {
    if (_isAppActive != isActive) {
      _isAppActive = isActive;
      if (_isInitialized) {
        _startSyncTimer();
        print(
          '🔄 Sync interval adjusted for app state: ${isActive ? 'active' : 'background'}',
        );
      }
    }
  }

  /// Perform background sync for all active clubs
  static Future<void> _performSync() async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      // Get user's clubs from provider
      if (_clubProvider == null) {
        print('⚠️ Club provider not set, skipping sync');
        return;
      }

      final clubs = _clubProvider!.clubs;
      if (clubs.isEmpty) {
        print('ℹ️ No clubs to sync');
        return;
      }

      print('🔄 Starting background sync for ${clubs.length} clubs');

      // Sync messages for each club
      final syncTasks = clubs
          .map((club) => _syncClubMessages(club.club.id))
          .toList();
      await Future.wait(syncTasks);

      print('✅ Background sync completed');
    } catch (e) {
      print('❌ Background sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync messages for a specific club
  static Future<void> _syncClubMessages(String clubId) async {
    try {
      final lastSyncTime = _lastSyncTimes[clubId];
      final lastUpdatedAt = _lastUpdatedAtTimes[clubId];

      // Use efficient message fetching with updatedAt timestamp
      final response = await ChatApiService.getMessagesEfficient(
        clubId,
        lastUpdatedAt: lastUpdatedAt?.toIso8601String(),
        forceFullSync: lastSyncTime == null,
        limit: 50, // Increased limit since we're using updatedAt filtering
      );

      if (response == null || response['success'] != true) {
        print('⚠️ Failed to sync messages for club $clubId');
        return;
      }

      final messagesData = response['data'];
      if (messagesData?['messages'] == null) {
        print('ℹ️ No new messages for club $clubId');
        return;
      }

      final newMessages = (messagesData['messages'] as List)
          .map((m) => ClubMessage.fromJson(m))
          .toList();

      if (newMessages.isEmpty) {
        print('ℹ️ No new/updated messages for club $clubId');
        return;
      }

      print('📨 Found ${newMessages.length} new messages for club $clubId');

      // Process new messages
      await _processNewMessages(clubId, newMessages);

      // Update sync tracking
      _lastSyncTimes[clubId] = DateTime.now();
      if (newMessages.isNotEmpty) {
        _lastMessageIds[clubId] = newMessages.first.id;
        // Track the latest updatedAt timestamp for efficient future syncs
        final latestUpdatedAt = newMessages
            .map((m) => m.updatedAt ?? m.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        _lastUpdatedAtTimes[clubId] = latestUpdatedAt;
      }
    } catch (e) {
      print('❌ Error syncing club $clubId: $e');
    }
  }

  /// Process new messages and trigger appropriate callbacks
  static Future<void> _processNewMessages(
    String clubId,
    List<ClubMessage> newMessages,
  ) async {
    for (final message in newMessages) {
      try {
        // Store message locally
        await MessageStorageService.addMessage(clubId, message);

        // Update club provider with latest message
        if (_clubProvider != null) {
          _clubProvider!.updateClubLatestMessage(
            clubId: clubId,
            messageId: message.id,
            messageContent: _getMessageDisplayText(message),
            senderName: message.senderName,
            senderId: message.senderId,
            createdAt: message.createdAt,
            isRead: false,
          );
        }

        // Handle special message types
        await _handleSpecialMessageTypes(clubId, message);

        // Trigger club message callback
        if (_messageCallbacks.containsKey(clubId)) {
          final messageData = _messageToCallbackData(message);
          _messageCallbacks[clubId]!(messageData);
        }
      } catch (e) {
        print('❌ Error processing message ${message.id}: $e');
      }
    }
  }

  /// Handle special message types (RSVP, Vote, Match, Practice, Reactions, etc.)
  static Future<void> _handleSpecialMessageTypes(
    String clubId,
    ClubMessage message,
  ) async {
    final contentType = message.messageType;

    switch (contentType) {
      case 'match':
        await _handleMatchMessage(clubId, message);
        break;
      case 'practice':
        await _handlePracticeMessage(clubId, message);
        break;
      case 'poll':
        await _handlePollMessage(clubId, message);
        break;
      case 'rsvp_update':
        await _handleRsvpUpdate(clubId, message);
        break;
      default:
        // Handle regular message updates (reactions, pins, etc.)
        await _handleMessageUpdate(clubId, message);
    }
  }

  /// Handle match-related messages
  static Future<void> _handleMatchMessage(
    String clubId,
    ClubMessage message,
  ) async {
    final matchId = message.matchId;
    if (matchId != null) {
      // Trigger match update callbacks
      final callbacks = _matchCallbacks[matchId];
      if (callbacks != null) {
        final matchData = _messageToCallbackData(message);
        for (final callback in callbacks) {
          try {
            callback(matchData);
          } catch (e) {
            print('❌ Error in match callback: $e');
          }
        }
      }
    }
  }

  /// Handle practice-related messages
  static Future<void> _handlePracticeMessage(
    String clubId,
    ClubMessage message,
  ) async {
    // Similar to match handling but for practice sessions
    print('🏃 Processing practice message: ${message.id}');
  }

  /// Handle poll messages
  static Future<void> _handlePollMessage(
    String clubId,
    ClubMessage message,
  ) async {
    print('📊 Processing poll message: ${message.id}');
  }

  /// Handle RSVP updates
  static Future<void> _handleRsvpUpdate(
    String clubId,
    ClubMessage message,
  ) async {
    final matchId = message.matchId;
    if (matchId != null) {
      // Trigger match RSVP callbacks
      final callbacks = _matchCallbacks[matchId];
      if (callbacks != null) {
        final rsvpData = _messageToCallbackData(message);
        rsvpData['type'] = 'match_rsvp'; // Ensure type is set for compatibility

        for (final callback in callbacks) {
          try {
            callback(rsvpData);
          } catch (e) {
            print('❌ Error in RSVP callback: $e');
          }
        }
      }
    }
  }

  /// Handle general message updates (reactions, pins, edits)
  static Future<void> _handleMessageUpdate(
    String clubId,
    ClubMessage message,
  ) async {
    // Check for reactions
    if (message.reactions.isNotEmpty) {
      print('😀 Processing message with reactions: ${message.id}');
    }

    // Check for pinned status
    if (message.pin.isPinned) {
      print('📌 Processing pinned message: ${message.id}');
    }

    // Check for edited status - assume edited if different from original
    print('✏️ Processing message update: ${message.id}');
  }

  /// Convert ClubMessage to callback data format for compatibility
  static Map<String, dynamic> _messageToCallbackData(ClubMessage message) {
    return {
      'type': 'club_message',
      'clubId': message.clubId,
      'messageId': message.id,
      'messageContent': _getMessageDisplayText(message),
      'senderName': message.senderName,
      'senderId': message.senderId,
      'createdAt': message.createdAt.toIso8601String(),
      'content': message.content,
      'reactions': message.reactions.map((r) => r.toJson()).toList(),
      'isPinned': message.pin.isPinned,
      'isEdited': false, // Add logic to determine if edited
    };
  }

  /// Get display text for a message based on its type and content
  static String _getMessageDisplayText(ClubMessage message) {
    switch (message.messageType) {
      case 'text':
        return message.content;
      case 'image':
        return '📷 Photo';
      case 'audio':
        return '🎤 Audio message';
      case 'document':
        return '📄 Document';
      case 'match':
        return '🏏 Match details';
      case 'practice':
        return '🏃 Practice session';
      case 'poll':
        return '📊 Poll';
      case 'gif':
        return '🎬 GIF';
      default:
        return message.content.isNotEmpty ? message.content : 'Message';
    }
  }

  /// Manual sync trigger for immediate updates
  static Future<void> triggerSync() async {
    if (!_isInitialized) {
      print('⚠️ Background sync not initialized');
      return;
    }

    print('🔄 Manual sync triggered');
    await _performSync();
  }

  /// Set club provider reference
  static void setClubProvider(ClubProvider clubProvider) {
    _clubProvider = clubProvider;
    print('✅ Club provider set for background sync');
  }

  /// Register callback for club message updates
  static void setClubMessageCallback(
    String clubId,
    Function(Map<String, dynamic>) callback,
  ) {
    _messageCallbacks[clubId] = callback;
    print('✅ Club message callback registered for background sync: $clubId');
  }

  /// Clear club message callback
  static void clearClubMessageCallback(String clubId) {
    _messageCallbacks.remove(clubId);
    print('🗑️ Club message callback cleared for background sync: $clubId');
  }

  /// Register callback for match updates
  static void addMatchUpdateCallback(
    String matchId,
    Function(Map<String, dynamic>) callback,
  ) {
    final callbacks = _matchCallbacks.putIfAbsent(matchId, () => []);
    callbacks.add(callback);
    print('✅ Match update callback registered for background sync: $matchId');
  }

  /// Remove match update callback
  static void removeMatchUpdateCallback(
    String matchId,
    Function(Map<String, dynamic>) callback,
  ) {
    final callbacks = _matchCallbacks[matchId];
    if (callbacks != null) {
      callbacks.remove(callback);
      if (callbacks.isEmpty) {
        _matchCallbacks.remove(matchId);
      }
    }
    print('🗑️ Match update callback removed for background sync: $matchId');
  }

  /// Clear all callbacks
  static void clearAllCallbacks() {
    _messageCallbacks.clear();
    _matchCallbacks.clear();
    print('🗑️ All background sync callbacks cleared');
  }

  /// Stop the background sync service
  static void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isInitialized = false;
    _isSyncing = false;
    _lastSyncTimes.clear();
    _lastUpdatedAtTimes.clear();
    _lastMessageIds.clear();
    clearAllCallbacks();

    print('🛑 Background sync service stopped');
  }

  /// Dispose of the service
  static void dispose() {
    stop();
    _clubProvider = null;
    print('🗑️ Background sync service disposed');
  }

  /// Get sync status for debugging
  static Map<String, dynamic> getSyncStatus() {
    return {
      'isInitialized': _isInitialized,
      'isSyncing': _isSyncing,
      'isAppActive': _isAppActive,
      'lastSyncTimes': _lastSyncTimes.map(
        (k, v) => MapEntry(k, v.toIso8601String()),
      ),
      'lastUpdatedAtTimes': _lastUpdatedAtTimes.map(
        (k, v) => MapEntry(k, v.toIso8601String()),
      ),
      'trackedClubs': _lastSyncTimes.keys.toList(),
      'activeCallbacks': {
        'clubMessages': _messageCallbacks.keys.toList(),
        'matchUpdates': _matchCallbacks.keys.toList(),
      },
    };
  }
}
