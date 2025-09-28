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
      if (!AuthService.isLoggedIn) {
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
  }

  /// Set app active state to adjust sync frequency
  static void setAppActiveState(bool isActive) {
    if (_isAppActive != isActive) {
      _isAppActive = isActive;
      if (_isInitialized) {
        _startSyncTimer();
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
        return;
      }

      final clubs = _clubProvider!.clubs;
      if (clubs.isEmpty) {
        return;
      }

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

      if (response == null) {
        return;
      }

      // Check if response has messages (same structure as club_chat.dart)
      final messagesData = response['messages'];
      if (messagesData == null) {
        return;
      }

      final newMessages = (messagesData as List)
          .map((m) => ClubMessage.fromJson(m))
          .toList();

      if (newMessages.isEmpty) {
        return;
      }

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

        // Check if this is an updated message (updatedAt different from createdAt)
        final isMessageUpdate =
            message.updatedAt != null &&
            message.updatedAt!.isAfter(message.createdAt);

        print(
          '📝 Message ${message.id}: createdAt=${message.createdAt}, updatedAt=${message.updatedAt}, isUpdate=$isMessageUpdate',
        );

        if (isMessageUpdate) {
          print('🔄 Handling message update for: ${message.id}');
          // Handle as message update (reactions, pins, edits)
          await _handleMessageUpdate(clubId, message);
        } else {
          print('📨 Handling new message: ${message.id}');
          // Handle special message types for new messages
          await _handleSpecialMessageTypes(clubId, message);

          // Trigger club message callback for new messages
          if (_messageCallbacks.containsKey(clubId)) {
            final messageData = _messageToCallbackData(message);
            _messageCallbacks[clubId]!(messageData);
          }
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
    print('🏏 Processing match message: ${message.id}');

    // Extract match data from meta field
    final meta = message.meta;
    if (meta != null && meta.containsKey('matchData')) {
      final matchData = meta['matchData'];
      print('🏏 Match Data: $matchData');

      // Check for match detail updates (time, venue, status changes)
      final hasMatchUpdates =
          meta.containsKey('venue') ||
          meta.containsKey('datetime') ||
          meta.containsKey('status') ||
          meta.containsKey('opponent');

      if (hasMatchUpdates) {
        print('🏏 Detected match details update: ${message.id}');

        // Trigger message callback with match update
        if (_messageCallbacks.containsKey(clubId)) {
          final callbackData = _messageToCallbackData(message);
          callbackData['isUpdate'] = true;
          callbackData['updateType'] = 'match_details';
          callbackData['matchData'] = matchData;
          _messageCallbacks[clubId]!(callbackData);
        }
      }
    }

    final matchId = message.matchId;
    if (matchId != null) {
      // Trigger match update callbacks
      final callbacks = _matchCallbacks[matchId];
      if (callbacks != null) {
        final matchCallbackData = _messageToCallbackData(message);
        for (final callback in callbacks) {
          try {
            callback(matchCallbackData);
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
    print('🏃 Processing practice message: ${message.id}');

    // Extract practice data from meta field
    final meta = message.meta;
    if (meta != null && meta.containsKey('practiceData')) {
      final practiceData = meta['practiceData'];
      print('🏃 Practice Data: $practiceData');

      // Check for practice detail updates (time, venue, status changes)
      final hasPracticeUpdates =
          meta.containsKey('venue') ||
          meta.containsKey('datetime') ||
          meta.containsKey('status') ||
          meta.containsKey('rsvpData');

      if (hasPracticeUpdates) {
        print('🏃 Detected practice details update: ${message.id}');

        // Trigger message callback with practice update
        if (_messageCallbacks.containsKey(clubId)) {
          final callbackData = _messageToCallbackData(message);
          callbackData['isUpdate'] = true;
          callbackData['updateType'] = 'practice_details';
          callbackData['practiceData'] = practiceData;
          callbackData['rsvpData'] = meta['rsvpData'];
          _messageCallbacks[clubId]!(callbackData);
        }
      }
    }
  }

  /// Handle poll messages
  static Future<void> _handlePollMessage(
    String clubId,
    ClubMessage message,
  ) async {
    print('📊 Processing poll message: ${message.id}');

    // Extract poll data from meta field
    final meta = message.meta;
    if (meta != null && meta.containsKey('pollData')) {
      final pollData = meta['pollData'];
      print('📊 Poll Data: $pollData');

      // Check for vote updates
      if (meta.containsKey('votes') || meta.containsKey('voteCounts')) {
        print('🗳️ Detected vote update in poll: ${message.id}');

        // Trigger message callback with vote update
        if (_messageCallbacks.containsKey(clubId)) {
          final callbackData = _messageToCallbackData(message);
          callbackData['isUpdate'] = true;
          callbackData['updateType'] = 'vote';
          callbackData['pollData'] = pollData;
          callbackData['votes'] = meta['votes'];
          callbackData['voteCounts'] = meta['voteCounts'];
          _messageCallbacks[clubId]!(callbackData);
        }
      }
    }
  }

  /// Handle RSVP updates
  static Future<void> _handleRsvpUpdate(
    String clubId,
    ClubMessage message,
  ) async {
    print('📋 Processing RSVP update for message: ${message.id}');

    // Extract RSVP data from meta field
    final meta = message.meta;
    if (meta != null && meta.containsKey('rsvpData')) {
      final rsvpData = meta['rsvpData'];
      print('📋 RSVP Data: $rsvpData');

      // Trigger message callback with RSVP update
      if (_messageCallbacks.containsKey(clubId)) {
        final callbackData = _messageToCallbackData(message);
        callbackData['isUpdate'] = true;
        callbackData['updateType'] = 'rsvp';
        callbackData['rsvpData'] = rsvpData;
        _messageCallbacks[clubId]!(callbackData);
      }
    }

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

  /// Handle general message updates (reactions, pins, edits, meta changes)
  static Future<void> _handleMessageUpdate(
    String clubId,
    ClubMessage message,
  ) async {
    bool hasUpdates = false;
    String updateType = 'general';

    // Check for reactions
    if (message.reactions.isNotEmpty) {
      print('😀 Processing message with reactions: ${message.id}');
      print('😀 Reaction count: ${message.reactions.length}');
      print(
        '😀 Reactions: ${message.reactions.map((r) => '${r.emoji}:${r.count}').join(', ')}',
      );
      hasUpdates = true;
      updateType = 'reaction';
    }

    // Check for pinned status
    if (message.pin.isPinned) {
      print('📌 Processing pinned message: ${message.id}');
      hasUpdates = true;
      updateType = 'pin';
    }

    // Check for meta field updates (votes, RSVPs, match details)
    if (message.meta != null && message.meta!.isNotEmpty) {
      print('� Processing meta field update for message: ${message.id}');
      print('📊 Meta data: ${message.meta}');

      // Detect specific meta update types
      if (message.messageType == 'poll' || message.pollId != null) {
        print('🗳️ Poll vote update detected');
        hasUpdates = true;
        updateType = 'poll_vote';
      } else if (message.messageType == 'match' || message.matchId != null) {
        // Check for RSVP updates in match meta
        final rsvps = message.meta!['rsvps'];
        final matchDetails = message.meta!['match'];

        if (rsvps != null) {
          print('✋ Match RSVP update detected');
          print('✋ RSVP data: $rsvps');
          hasUpdates = true;
          updateType = 'match_rsvp';
        }

        if (matchDetails != null) {
          print('⚽ Match details update detected');
          print('⚽ Match data: $matchDetails');
          hasUpdates = true;
          updateType = 'match_details';
        }
      } else if (message.messageType == 'practice' ||
          message.practiceId != null) {
        // Check for practice RSVP updates
        final rsvps = message.meta!['rsvps'];
        final practiceDetails = message.meta!['practice'];

        if (rsvps != null) {
          print('🏃 Practice RSVP update detected');
          print('🏃 RSVP data: $rsvps');
          hasUpdates = true;
          updateType = 'practice_rsvp';
        }

        if (practiceDetails != null) {
          print('🏃 Practice details update detected');
          hasUpdates = true;
          updateType = 'practice_details';
        }
      } else {
        print('📝 General meta field update detected');
        hasUpdates = true;
        updateType = 'meta_update';
      }
    }

    // Trigger callback if there are any updates
    if (hasUpdates && _messageCallbacks.containsKey(clubId)) {
      print('📞 Triggering $updateType callback for club: $clubId');
      final updateData = _messageToCallbackData(message);
      updateData['isUpdate'] = true;
      updateData['updateType'] = updateType;

      // Include meta data in callback for client processing
      if (message.meta != null) {
        updateData['meta'] = message.meta;
      }

      _messageCallbacks[clubId]!(updateData);
    } else if (!hasUpdates) {
      print('ℹ️ No significant updates detected for message: ${message.id}');
    } else {
      print('⚠️ No message callback registered for club: $clubId');
    }

    print('✏️ Processed message update: ${message.id} (type: $updateType)');
  }

  /// Convert ClubMessage to callback data format for compatibility
  static Map<String, dynamic> _messageToCallbackData(ClubMessage message) {
    final callbackData = {
      'type': 'club_message',
      'clubId': message.clubId,
      'messageId': message.id,
      'messageContent': _getMessageDisplayText(message),
      'senderName': message.senderName,
      'senderId': message.senderId,
      'createdAt': message.createdAt.toIso8601String(),
      'content': message.content,
      'messageType': message.messageType,
      'reactions': message.reactions.map((r) => r.toJson()).toList(),
      'isPinned': message.pin.isPinned,
      'isEdited':
          message.updatedAt != null &&
          message.updatedAt!.isAfter(message.createdAt),
    };

    // Include meta field if present
    if (message.meta != null && message.meta!.isNotEmpty) {
      callbackData['meta'] = message.meta;
    }

    // Include related IDs for specific message types
    if (message.matchId != null) {
      callbackData['matchId'] = message.matchId;
    }

    if (message.practiceId != null) {
      callbackData['practiceId'] = message.practiceId;
    }

    if (message.pollId != null) {
      callbackData['pollId'] = message.pollId;
    }

    // Include updatedAt timestamp for sync tracking
    if (message.updatedAt != null) {
      callbackData['updatedAt'] = message.updatedAt!.toIso8601String();
    }

    return callbackData;
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
    await _performSync();
  }

  /// Set club provider reference
  static void setClubProvider(ClubProvider clubProvider) {
    _clubProvider = clubProvider;
    print('✅ Club provider set for background sync');

    // Try to initialize background sync if not already initialized and user is authenticated
    if (!_isInitialized && AuthService.isLoggedIn) {
      initialize()
          .then((_) {
            print('✅ Background sync initialized after club provider set');
          })
          .catchError((e) {
            print(
              '❌ Failed to initialize background sync after club provider set: $e',
            );
          });
    }
  }

  /// Register callback for club message updates
  static void setClubMessageCallback(
    String clubId,
    Function(Map<String, dynamic>) callback,
  ) {
    _messageCallbacks[clubId] = callback;

    // Initialize sync tracking for this club if not already present
    if (!_lastSyncTimes.containsKey(clubId)) {
      _lastSyncTimes[clubId] = DateTime.now();
    }

    // Start background sync immediately for this club if service is initialized
    if (_isInitialized) {
      _syncClubMessages(clubId).catchError((e) {
        print('❌ Error in immediate sync for club $clubId: $e');
      });
    }
  }

  /// Clear club message callback
  static void clearClubMessageCallback(String clubId) {
    _messageCallbacks.remove(clubId);
  }

  /// Register callback for match updates
  static void addMatchUpdateCallback(
    String matchId,
    Function(Map<String, dynamic>) callback,
  ) {
    final callbacks = _matchCallbacks.putIfAbsent(matchId, () => []);
    callbacks.add(callback);
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
  }

  /// Clear all callbacks
  static void clearAllCallbacks() {
    _messageCallbacks.clear();
    _matchCallbacks.clear();
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

  /// Debug method to test reaction updates
  static void debugReactionSync() {
    print('🧪 Debug Reaction Sync Status:');
    final status = getSyncStatus();
    print('📊 Sync Status: $status');
    print('🔄 Active callbacks: ${status['activeCallbacks']}');
    print('⏰ Last updated times: ${status['lastUpdatedAtTimes']}');
  }
}
