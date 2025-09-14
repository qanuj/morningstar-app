import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../../providers/user_provider.dart';
import '../../models/club.dart';
import '../../models/club_message.dart';
import '../../models/match.dart';
import '../../models/message_status.dart';
import '../../models/starred_info.dart';
import '../../models/message_reply.dart';
import '../../models/message_reaction.dart';
import '../../services/chat_api_service.dart';
import '../../services/message_storage_service.dart';
import '../../services/media_storage_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/club_info_dialog.dart';
import '../../widgets/audio_recording_widget.dart';
import '../../widgets/pinned_messages_section.dart';
import '../../widgets/message_visibility_detector.dart';
import '../../widgets/chat_app_bar.dart';
import '../../widgets/message_bubble_wrapper.dart';
import '../../widgets/message_input.dart';
import '../../widgets/chat_header.dart';
import '../manage/manage_club.dart';
import '../../providers/club_provider.dart';
import '../../models/shared_content.dart';
import '../../widgets/dialogs/match_selection_dialog.dart';
import '../../widgets/dialogs/practice_selection_dialog.dart';
import '../matches/create_match_screen.dart';
import '../practices/create_practice_screen.dart';

class ClubChatScreen extends StatefulWidget {
  final Club club;
  final SharedContent? sharedContent;
  final String? initialMessage;

  const ClubChatScreen({
    super.key, 
    required this.club,
    this.sharedContent,
    this.initialMessage,
  });

  @override
  ClubChatScreenState createState() => ClubChatScreenState();
}

class ClubChatScreenState extends State<ClubChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ClubMessage> _messages = [];
  bool _isLoading = true;
  // _isComposing removed - now handled internally by MessageInput
  String? _error;
  late AnimationController _refreshAnimationController;
  DetailedClubInfo? _detailedClubInfo;
  final FocusNode _textFieldFocusNode = FocusNode();
  MessageReply? _replyingTo;

  // Slide-to-reply state
  double _slideOffset = 0.0;
  bool _isSliding = false;
  String? _slidingMessageId;

  // Audio recording widget key
  final GlobalKey<AudioRecordingWidgetState> _audioRecordingKey =
      GlobalKey<AudioRecordingWidgetState>();

  // Message selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = <String>{};

  // Message status tracking
  final Set<String> _deliveredMessages = <String>{};
  final Set<String> _seenMessages = <String>{};

  // Permission caching
  bool? _cachedCanPinMessages;

  // Map to store pending file uploads by message ID
  final Map<String, List<PlatformFile>> _pendingUploads = {};

  // Highlighted message state
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  // Bottom refresh debounce timer
  Timer? _bottomRefreshTimer;

  // Audio recording pull gesture state
  bool _isPullingForAudio = false;
  double _audioRecordingPullProgress = 0.0;
  static const double _audioRecordingPullThreshold = 100.0;
  bool _canActivateRecording = false; // Only true if tapped in bottom 20%
  bool _isInRecordingMode = false; // True during entire recording flow


  @override
  void initState() {
    super.initState();
    // Initialize refresh animation controller
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Clear cached messages to handle model migration (pin/starred structure changes)
    MessageStorageService.clearCachedMessages(widget.club.id);
    // Load persistent delivered/read status flags
    _loadPersistentStatusFlags();
    // Remove the listener since we handle it in onChanged now
    _loadMessages();
    
    // Setup push notification callback instead of polling
    _setupPushNotificationCallback();

    // Add focus listener to trigger UI updates
    _textFieldFocusNode.addListener(() {
      setState(() {});
    });

    // Handle shared content if provided
    _handleSharedContent();
  }

  /// Load delivered and read message IDs from persistent storage
  Future<void> _loadPersistentStatusFlags() async {
    try {
      final deliveredIds = await MessageStorageService.getDeliveredMessageIds(
        widget.club.id,
      );
      final readIds = await MessageStorageService.getReadMessageIds(
        widget.club.id,
      );

      setState(() {
        _deliveredMessages.addAll(deliveredIds);
        _seenMessages.addAll(readIds);
      });

      debugPrint(
        '📱 Loaded ${deliveredIds.length} delivered and ${readIds.length} read message flags',
      );
    } catch (e) {
      debugPrint('❌ Error loading persistent status flags: $e');
    }
  }

  /// Handle shared content if provided
  void _handleSharedContent() {
    if (widget.sharedContent != null || widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Set initial message if provided
        if (widget.initialMessage != null) {
          _messageController.text = widget.initialMessage!;
        }

        // TODO: Handle shared content (images, text, URLs) 
        // This would involve:
        // 1. If shared content is text/URL, append it to the message controller
        // 2. If shared content is images, prepare them for attachment
        // 3. Show a preview of shared content in the message input area

        if (widget.sharedContent != null) {
          final sharedContent = widget.sharedContent!;
          
          // Handle text/URL content
          if (sharedContent.hasText) {
            final existingText = _messageController.text;
            final sharedText = sharedContent.text!;
            
            if (existingText.isNotEmpty) {
              _messageController.text = '$existingText\n\n$sharedText';
            } else {
              _messageController.text = sharedText;
            }
          }
          
          // For images, we would need to modify the MessageInput widget
          // to show shared image previews. This is a more complex change
          // that would require updating the MessageInput widget.
        }
      });
    }
  }

  /// Setup push notification callback for real-time message updates
  void _setupPushNotificationCallback() {
    debugPrint('🔔 Setting up push notification callback for club: ${widget.club.id}');
    
    NotificationService.setClubMessageCallback(widget.club.id, (Map<String, dynamic> data) {
      debugPrint('💬 Received push notification data: $data');
      
      // This callback is already club-specific, so we can directly refresh
      debugPrint('✅ Push notification received for current club, refreshing messages');
      
      // Use a slight delay to ensure the server has processed the message
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadMessages(forceSync: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _bottomRefreshTimer?.cancel();
    _refreshAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    
    // Clear push notification callback for this club
    NotificationService.clearClubMessageCallback(widget.club.id);
    
    super.dispose();
  }

  Future<void> _loadMessages({bool forceSync = false}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Start refresh animation
      _refreshAnimationController.repeat();

      // Always load from local storage first for offline-first experience
      debugPrint('📱 Loading messages from local storage...');
      final cachedMessages = await MessageStorageService.loadMessages(
        widget.club.id,
      );

      if (cachedMessages.isNotEmpty) {
        setState(() {
          _messages = cachedMessages;
          _isLoading = false;
        });

        // Stop refresh animation and reset to 0
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();

        // Mark new messages as delivered if not already in cache
        _markNewMessagesAsDelivered();

        // Only sync if explicitly requested or if not in offline mode
        final isOfflineMode = await MessageStorageService.isOfflineMode(
          widget.club.id,
        );
        if (forceSync ||
            (!isOfflineMode &&
                await MessageStorageService.needsSync(widget.club.id))) {
          _syncMessagesFromServer(forceSync: forceSync);
        }
      } else {
        // No local data available, must sync with server
        await _syncMessagesFromServer(forceSync: true);
      }
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      // Try to load from server directly if local storage fails
      try {
        await _syncMessagesFromServer(forceSync: true);
      } catch (syncError) {
        debugPrint('❌ Error syncing from server: $syncError');
        _error = 'Unable to load messages. Please check your connection.';
        setState(() => _isLoading = false);

        // Stop refresh animation on error and reset to 0
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
      }
    }
  }

  // Mark messages as delivered when they are received (API called only once per message)
  Future<void> _markReceivedMessagesAsDelivered() async {
    // Prevent concurrent execution
    if (_isMarkingDelivered) {
      debugPrint('⏸️ Already marking messages as delivered, skipping');
      return;
    }

    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.user?.id;
    if (currentUserId == null) return;

    _isMarkingDelivered = true;

    try {
      // Get messages that need to be marked as delivered
      final messagesToMark = _messages
          .where(
            (message) =>
                message.senderId != currentUserId &&
                !_deliveredMessages.contains(message.id) &&
                message.status != MessageStatus.delivered &&
                message.status != MessageStatus.read,
          )
          .toList();

      if (messagesToMark.isEmpty) {
        debugPrint('📱 No messages need delivery marking');
        return;
      }

      debugPrint('📧 Marking ${messagesToMark.length} messages as delivered');

      for (final message in messagesToMark) {
        // Skip if already in memory cache or currently being processed
        if (_deliveredMessages.contains(message.id) ||
            _processingDelivery.contains(message.id)) {
          debugPrint(
            '⏭️ Skipping message ${message.id} - already processed or in progress',
          );
          continue;
        }

        // Add to processing set immediately to prevent duplicates
        _processingDelivery.add(message.id);

        try {
          // Check persistent storage to ensure API is called only once
          final alreadyMarked = await MessageStorageService.isMarkedAsDelivered(
            widget.club.id,
            message.id,
          );

          if (alreadyMarked) {
            // Already marked in persistent storage but not in memory - sync memory state
            _deliveredMessages.add(message.id);
            _updateMessageStatus(message.id, MessageStatus.delivered);
            debugPrint(
              '📝 Synced message ${message.id} from storage to memory cache',
            );
            continue;
          }

          // Final check before API call
          if (_deliveredMessages.contains(message.id)) {
            debugPrint(
              '⏭️ Message ${message.id} was marked during processing, skipping API call',
            );
            continue;
          }

          debugPrint(
            '🔵 Making POST request to: conversations/${widget.club.id}/messages/${message.id}/delivered',
          );
          final success = await ChatApiService.markAsDelivered(
            widget.club.id,
            message.id,
          );

          if (success) {
            // Mark in both memory and persistent storage immediately
            _deliveredMessages.add(message.id);
            await MessageStorageService.markAsDelivered(
              widget.club.id,
              message.id,
            );
            // Update message status locally
            _updateMessageStatus(message.id, MessageStatus.delivered);
            debugPrint(
              '✅ Successfully marked message ${message.id} as delivered',
            );
          }
        } catch (e) {
          debugPrint('❌ Error marking message ${message.id} as delivered: $e');
        } finally {
          // Always remove from processing set
          _processingDelivery.remove(message.id);
        }
      }
    } finally {
      _isMarkingDelivered = false;
    }
  }

  // Sync delivery status from server messages to prevent duplicate API calls
  void _syncDeliveryStatusFromServer(List<ClubMessage> serverMessages) {
    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.user?.id;
    if (currentUserId == null) return;

    int syncedCount = 0;

    for (final message in serverMessages) {
      // For messages from OTHER users: track our delivery/read status to avoid duplicate API calls
      if (message.senderId != currentUserId) {
        if (message.status == MessageStatus.delivered ||
            message.deliveredAt != null) {
          if (!_deliveredMessages.contains(message.id)) {
            _deliveredMessages.add(message.id);
            syncedCount++;
          }
        }

        if (message.status == MessageStatus.read || message.readAt != null) {
          if (!_seenMessages.contains(message.id)) {
            _seenMessages.add(message.id);
          }
        }
      }

      // Note: For messages sent BY current user, the server status reflects
      // whether OTHER users have read/delivered them. This status should be
      // used directly from the server message without local tracking.
    }

    if (syncedCount > 0) {
      debugPrint(
        '📝 Synced delivery status for $syncedCount messages from server',
      );
    }
  }

  // Mark messages as seen when they come into view (API called only once per message)
  Future<void> _markMessageAsSeen(String messageId) async {
    debugPrint('👀 _markMessageAsSeen called for message: $messageId');

    if (_seenMessages.contains(messageId)) {
      debugPrint('⏭️ Message $messageId already marked as seen');
      return;
    }

    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.user?.id;
    if (currentUserId == null) {
      debugPrint('❌ No current user ID for marking message as seen');
      return;
    }

    // Find the message
    final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) {
      debugPrint('❌ Message $messageId not found in messages list');
      return;
    }

    final message = _messages[messageIndex];

    // Only mark messages from other users as seen
    if (message.senderId == currentUserId) {
      debugPrint('⏭️ Skipping own message $messageId for read marking');
      return;
    }

    debugPrint(
      '📖 Processing read marking for message $messageId from ${message.senderName}',
    );

    // Check if message already has readAt timestamp (from server status)
    if (message.status == MessageStatus.read || message.readAt != null) {
      // Message is already marked as read, just update local state
      _seenMessages.add(messageId);
      _updateMessageStatus(messageId, MessageStatus.read);
      return;
    }

    // Double-check with persistent storage to ensure API is called only once
    final alreadyMarked = await MessageStorageService.isMarkedAsRead(
      widget.club.id,
      messageId,
    );
    if (alreadyMarked) {
      // Already marked in persistent storage but not in memory - sync memory state
      _seenMessages.add(messageId);
      _updateMessageStatus(messageId, MessageStatus.read);
      return;
    }

    try {
      final success = await ChatApiService.markAsRead(
        widget.club.id,
        message.id,
      );

      if (success) {
        // Mark in both memory and persistent storage
        _seenMessages.add(messageId);
        await MessageStorageService.markAsRead(widget.club.id, messageId);
        // Update message status locally
        _updateMessageStatus(messageId, MessageStatus.read);
      }
    } catch (e) {
      debugPrint('❌ Error marking message $messageId as seen: $e');
    }
  }

  // Update message status locally
  void _updateMessageStatus(String messageId, MessageStatus newStatus) {
    setState(() {
      final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          status: newStatus,
        );
      }
    });
  }

  // Mark messages as delivered when loaded and not already in cache
  Future<void> _markNewMessagesAsDelivered() async {
    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.user?.id;
    if (currentUserId == null) return;

    final messagesToMarkAsDelivered = <ClubMessage>[];

    // Find messages from other users that don't have deliveredAt set and aren't from current user
    for (final message in _messages) {
      if (message.senderId != currentUserId && // Not own message
          message.deliveredAt == null && // No deliveredAt timestamp
          !_deliveredMessages.contains(message.id) && // Not in memory cache
          !_processingDelivery.contains(message.id)) {
        // Not currently being processed

        // Check if message status indicates it needs delivery marking
        if (message.status == MessageStatus.sent) {
          messagesToMarkAsDelivered.add(message);
        }
      }
    }

    if (messagesToMarkAsDelivered.isNotEmpty) {
      debugPrint(
        '📝 Found ${messagesToMarkAsDelivered.length} new messages to mark as delivered',
      );

      // Mark messages as delivered with delivery timestamp
      for (final message in messagesToMarkAsDelivered) {
        await _markSingleMessageAsDelivered(message);
      }
    }
  }

  // Helper method to mark a single message as delivered
  Future<void> _markSingleMessageAsDelivered(ClubMessage message) async {
    if (_processingDelivery.contains(message.id)) {
      debugPrint(
        '⏸️ Message ${message.id} already being processed for delivery',
      );
      return;
    }

    _processingDelivery.add(message.id);

    try {
      debugPrint('📡 Marking message ${message.id} as delivered...');

      final success = await ChatApiService.markAsDelivered(
        widget.club.id,
        message.id,
      );

      if (success) {
        // Update local state with current timestamp
        final now = DateTime.now();

        _deliveredMessages.add(message.id);
        await MessageStorageService.markAsDelivered(widget.club.id, message.id);

        // Update message with delivered status and timestamp
        setState(() {
          final messageIndex = _messages.indexWhere(
            (msg) => msg.id == message.id,
          );
          if (messageIndex != -1) {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.delivered,
              deliveredAt: now,
            );
          }
        });

        debugPrint('✅ Successfully marked message ${message.id} as delivered');
      }
    } catch (e) {
      debugPrint('❌ Error marking message ${message.id} as delivered: $e');
    } finally {
      _processingDelivery.remove(message.id);
    }
  }

  // Note: Old scroll-based detection replaced with widget-based visibility detection

  /// Apply incremental changes to the message list without full reload
  Future<void> _applyIncrementalChanges(
    Map<String, dynamic> comparison,
    List<ClubMessage> serverMessages, {
    bool showNotifications = true,
  }) async {
    final newMessages = (comparison['new'] as List? ?? []).cast<ClubMessage>();
    final updatedMessages = (comparison['updated'] as List? ?? [])
        .cast<ClubMessage>();
    final deletedMessageIds = (comparison['deleted'] as List? ?? [])
        .cast<String>();

    // Create a working copy of current messages
    final updatedMessagesList = List<ClubMessage>.from(_messages);
    bool hasChanges = false;

    // 1. Remove deleted messages
    if (deletedMessageIds.isNotEmpty) {
      debugPrint('🗑️ Removing ${deletedMessageIds.length} deleted messages');
      updatedMessagesList.removeWhere(
        (msg) => deletedMessageIds.contains(msg.id),
      );
      hasChanges = true;
    }

    // 2. Update existing messages
    if (updatedMessages.isNotEmpty) {
      debugPrint('📝 Updating ${updatedMessages.length} existing messages');
      for (final updatedMsg in updatedMessages) {
        final index = updatedMessagesList.indexWhere(
          (msg) => msg.id == updatedMsg.id,
        );
        if (index != -1) {
          // Use server status as authoritative source after refresh
          // Only preserve local status if it's higher priority and timestamps are missing
          final currentMsg = updatedMessagesList[index];
          final serverStatus = updatedMsg.status;
          final localStatus = currentMsg.status;

          debugPrint(
            '🔍 Message ${updatedMsg.id}: local=${localStatus.toString().split('.').last} → server=${serverStatus.toString().split('.').last}',
          );

          // Use server timestamps if available, otherwise keep local timestamps
          final finalDeliveredAt =
              updatedMsg.deliveredAt ?? currentMsg.deliveredAt;
          final finalReadAt = updatedMsg.readAt ?? currentMsg.readAt;

          // Use server status as authoritative (it includes latest read/delivered info from all users)
          updatedMessagesList[index] = updatedMsg.copyWith(
            deliveredAt: finalDeliveredAt,
            readAt: finalReadAt,
          );
          hasChanges = true;

          debugPrint(
            '✅ Updated message ${updatedMsg.id} with server status: ${serverStatus.toString().split('.').last}',
          );
        }
      }
    }

    // 3. Add new messages
    if (newMessages.isNotEmpty) {
      debugPrint('➕ Adding ${newMessages.length} new messages');
      updatedMessagesList.addAll(newMessages);
      hasChanges = true;
      // Highlight new messages temporarily
      // for (final newMsg in newMessages) {
      //   _highlightMessage(newMsg.id);
      // }
    }

    if (hasChanges) {
      setState(() {
        _messages = updatedMessagesList;
        _isLoading = false;
      });

      // Stop refresh animation and reset to 0
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();

      // Auto-scroll to newest message if new messages were added
      // if (newMessages.isNotEmpty) {
      //   _scrollToBottom();
      // }

      debugPrint('✅ Applied incremental changes successfully');

      // Mark new messages as delivered after sync
      if (newMessages.isNotEmpty) {
        _markNewMessagesAsDelivered();
      }
    } else {
      setState(() => _isLoading = false);

      // Stop refresh animation and reset to 0
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();
    }
  }

  Future<void> _syncMessagesFromServer({bool forceSync = false}) async {
    try {
      debugPrint('🔄 Syncing messages from server...');
      debugPrint('📱 Local messages before sync:');
      for (final msg in _messages) {
        debugPrint(
          '   ${msg.id}: status = ${msg.status.toString().split('.').last}',
        );
      }

      final response = await ChatApiService.getMessages(widget.club.id);

      if (response != null &&
          (response['success'] == true || response['messages'] != null)) {
        final List<dynamic> messageData = response['messages'] ?? [];
        final serverMessages = <ClubMessage>[];

        for (final json in messageData) {
          try {
            if (json is Map<String, dynamic>) {
              final message = ClubMessage.fromJson(json);
              debugPrint(
                '📡 Server message ${message.id}: status = ${message.status.toString().split('.').last}',
              );
              serverMessages.add(message);
            }
          } catch (e) {
            debugPrint('❌ Error parsing message: $e');
            debugPrint('❌ Problem JSON: $json');
            // Skip this message but continue processing others
            continue;
          }
        }

        // Compare messages to identify changes
        final comparison = MessageStorageService.compareMessages(
          _messages,
          serverMessages,
        );

        debugPrint(
          '📊 Comparison result: needsUpdate=${comparison['needsUpdate']}, new=${(comparison['new'] as List).length}, updated=${(comparison['updated'] as List).length}, deleted=${(comparison['deleted'] as List).length}',
        );

        if (comparison['needsUpdate'] as bool) {
          // Apply incremental changes instead of full reload
          await _applyIncrementalChanges(
            comparison,
            serverMessages,
            showNotifications: forceSync,
          );
        } else {
          setState(() => _isLoading = false);

          // Stop refresh animation
          _refreshAnimationController.stop();
          // Show user that refresh completed but no new changes (only for explicit refresh)
          // No new updates
        }

        // Merge server messages with local read/delivered status for storage
        final mergedMessages =
            await MessageStorageService.mergeMessagesWithLocalData(
              widget.club.id,
              serverMessages,
              _messages, // Use current UI state instead of old local data
            );

        // Save merged messages with media download (background operation)
        MessageStorageService.saveMessagesWithMedia(
          widget.club.id,
          mergedMessages,
        );

        // Parse detailed club info from API response
        if (response['club'] != null) {
          _detailedClubInfo = DetailedClubInfo.fromJson(
            response['club'] as Map<String, dynamic>,
          );
          // Update permissions after club info is loaded
          _updatePermissions();
        }

        // Messages from server should already be in correct chronological order
        // No sorting needed to prevent UI jumping

        // Sync delivery status from server before trying to mark new ones
        _syncDeliveryStatusFromServer(serverMessages);

        // Mark messages as delivered/read using existing methods
        _markReceivedMessagesAsDelivered();

        debugPrint('✅ Sync completed successfully');
      } else {
        final errorMessage = response?['message'];
        _error = errorMessage is String
            ? errorMessage
            : 'Failed to load messages';
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('❌ Error syncing messages from server: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to sync messages: $e';
        });

        // Stop refresh animation on sync error and reset to 0
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
      }
    }
  }

  // Removed duplicate _mergeMessagesWithLocalData function - now using MessageStorageService.mergeMessagesWithLocalData

  void _showMoreOptions() async {
    final isOfflineMode = await MessageStorageService.isOfflineMode(
      widget.club.id,
    );

    if (mounted) {
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isOfflineMode ? Icons.wifi_off : Icons.wifi,
                  color: isOfflineMode ? Colors.orange : Colors.green,
                ),
                title: Text(
                  isOfflineMode ? 'Offline Mode: ON' : 'Offline Mode: OFF',
                ),
                subtitle: Text(
                  isOfflineMode
                      ? 'No background sync, tap refresh to update'
                      : 'Background sync enabled',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleOfflineMode(!isOfflineMode);
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Storage Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showStorageInfo();
                },
              ),
              ListTile(
                leading: Icon(Icons.download),
                title: Text('Download All Media'),
                subtitle: Text(
                  'Download images, audio, and documents for offline use',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAllMedia();
                },
              ),
              ListTile(
                leading: Icon(Icons.clear_all),
                title: Text('Clear Local Data'),
                subtitle: Text('Clear messages and downloaded media'),
                onTap: () {
                  Navigator.pop(context);
                  _clearLocalData();
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _toggleOfflineMode(bool enabled) async {
    await MessageStorageService.setOfflineMode(widget.club.id, enabled);
  }

  Future<void> _downloadAllMedia() async {
    try {
      // Extract media URLs from current messages
      final mediaUrls = <Map<String, dynamic>>[];
      for (final message in _messages) {
        // Images
        for (final image in message.images) {
          mediaUrls.add({
            'url': image,
            'type': 'image',
            'messageId': message.id,
          });
        }

        // Document: don't download automatically.

        // Audio
        if (message.audio != null) {
          mediaUrls.add({
            'url': message.audio!.url,
            'type': 'audio',
            'messageId': message.id,
          });
        }

        // GIFs
        if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
          mediaUrls.add({
            'url': message.gifUrl!,
            'type': 'gif',
            'messageId': message.id,
          });
        }
      }

      if (mediaUrls.isNotEmpty) {
        await MediaStorageService.downloadAllMediaForClub(
          widget.club.id,
          mediaUrls,
        );
      }
    } catch (e) {
      // Ignore errors during media download
    }
  }

  Future<void> _showStorageInfo() async {
    final storageInfo = await MessageStorageService.getStorageInfo(
      widget.club.id,
    );

    final mediaInfo = storageInfo['media'] as Map<String, dynamic>? ?? {};

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Storage Information'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📱 OFFLINE STATUS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Offline Mode: ${storageInfo['isOfflineMode'] ? 'ON' : 'OFF'}',
                ),
                SizedBox(height: 16),

                Text(
                  '💬 MESSAGES',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Count: ${storageInfo['messageCount']}'),
                Text('Last Sync: ${storageInfo['lastSync'] ?? 'Never'}'),
                Text('Needs Sync: ${storageInfo['needsSync']}'),
                if (storageInfo['lastMessageAt'] != null)
                  Text('Latest: ${storageInfo['lastMessageAt']}'),
                SizedBox(height: 8),
                Text(
                  '📧 Delivered: ${storageInfo['deliveredCount'] ?? 0}',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                ),
                Text(
                  '👁️ Read: ${storageInfo['readCount'] ?? 0}',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
                SizedBox(height: 16),

                Text(
                  '💾 MEDIA CACHE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Files: ${mediaInfo['totalFiles'] ?? 0}'),
                if (mediaInfo['totalSizeMB'] != null)
                  Text(
                    'Size: ${(mediaInfo['totalSizeMB'] as double).toStringAsFixed(1)} MB',
                  ),
                if (mediaInfo['byType'] != null) ...[
                  SizedBox(height: 8),
                  ...((mediaInfo['byType'] as Map<String, dynamic>).entries.map(
                    (e) => Text('${e.key}: ${e.value}'),
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Local Data?'),
        content: Text(
          'This will clear all locally stored messages and downloaded media files, then reload from the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear all club data including media
        await MessageStorageService.clearClubData(widget.club.id);

        // Reload from server
        await _loadMessages(forceSync: true);
      } catch (e) {
        // Ignore clear data errors
      }
    }
  }

  /// Insert a message in the correct chronological position without sorting the entire list
  void _insertMessageInOrder(ClubMessage message) {
    // Find the correct position to insert the message (chronological order)
    int insertIndex = _messages.length;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].createdAt.isAfter(message.createdAt)) {
        insertIndex = i;
      } else {
        break;
      }
    }
    _messages.insert(insertIndex, message);
  }

  /// Replace a message and re-position it if the timestamp changed
  void _replaceMessage(ClubMessage oldMessage, ClubMessage newMessage) {
    final messageIndex = _messages.indexWhere((m) => m.id == oldMessage.id);
    if (messageIndex != -1) {
      _messages.removeAt(messageIndex);
      // If timestamp is different, insert in correct position
      if (oldMessage.createdAt != newMessage.createdAt) {
        _insertMessageInOrder(newMessage);
      } else {
        // Same timestamp, insert at same position
        _messages.insert(messageIndex, newMessage);
      }
    }
  }

  void _handleMessageUpdated(ClubMessage oldMessage, ClubMessage newMessage) {
    setState(() {
      final messageIndex = _messages.indexWhere((m) => m.id == oldMessage.id);
      if (messageIndex != -1) {
        // If the message ID changed (temp to real) or timestamp changed, reposition
        if (oldMessage.id != newMessage.id ||
            oldMessage.createdAt != newMessage.createdAt) {
          _replaceMessage(oldMessage, newMessage);
        } else {
          // Just update in place for status changes
          _messages[messageIndex] = newMessage;
        }
      }
    });

    // Clean up pending uploads if message is no longer sending
    if (newMessage.status != MessageStatus.sending) {
      _pendingUploads.remove(oldMessage.id);
      if (oldMessage.id != newMessage.id) {
        _pendingUploads.remove(newMessage.id);
      }
    }
  }

  void _handleMessageFailed(String messageId) {
    // Message failure is handled by the SelfSendingMessageBubble internally
    // This callback can be used for additional UI feedback if needed
    debugPrint('❌ Message failed: $messageId');

    // Keep pending uploads for failed messages so they can be retried
    // They will be cleaned up when message is successfully sent or manually deleted
  }

  /// Handle reaction removal directly from the message bubble
  Future<void> _handleReactionRemoved(
    String messageId,
    String emoji,
    String userId,
  ) async {
    debugPrint(
      '🚀 _handleReactionRemoved called: messageId=$messageId, emoji=$emoji, userId=$userId',
    );

    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.user;

    if (currentUser == null || userId != currentUser.id) {
      debugPrint('❌ Permission denied - not current user or user is null');
      return; // Only allow removing own reactions
    }

    // Store original messages for potential revert
    final originalMessages = List<ClubMessage>.from(_messages);

    // Optimistically remove the reaction for immediate UI feedback
    setState(() {
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final message = _messages[messageIndex];
        final updatedReactions = <MessageReaction>[];

        for (final reaction in message.reactions) {
          if (reaction.emoji == emoji) {
            // Remove current user from this reaction
            if (reaction.users.length <= 1) {
              // Don't add this reaction if current user was the only one
              continue;
            } else {
              // Remove just this user from the reaction
              final updatedUsers = reaction.users
                  .where((u) => u.userId != userId)
                  .toList();
              updatedReactions.add(
                MessageReaction(
                  emoji: reaction.emoji,
                  users: updatedUsers,
                  count: updatedUsers.length,
                  createdAt: reaction.createdAt,
                ),
              );
            }
          } else {
            // Keep other reactions unchanged
            updatedReactions.add(reaction);
          }
        }

        // Update the message with new reactions
        _messages[messageIndex] = message.copyWith(reactions: updatedReactions);
        debugPrint(
          '✅ Updated message reactions: ${updatedReactions.length} reactions remaining',
        );
      }
    });

    try {
      // Make API call to remove the reaction
      final success = await ChatApiService.removeReaction(
        widget.club.id,
        messageId,
      );

      if (!success) {
        throw Exception('API call failed');
      }

      debugPrint('✅ Reaction removed successfully from message bubble');
    } catch (e) {
      debugPrint('❌ Error removing reaction from message bubble: $e');

      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _messages = originalMessages;
        });
      }
    }
  }

  void _handleSlideGesture(
    DragUpdateDetails details,
    ClubMessage message,
    bool isOwn,
  ) {
    // Allow slide-to-reply for all messages - swipe right to reply
    final delta = details.delta.dx;
    final threshold = 20.0; // Minimum slide distance to trigger reply

    // Accumulate the slide offset for smooth animation
    final newOffset = (_slideOffset + delta).clamp(0.0, 100.0);

    setState(() {
      _slideOffset = newOffset;
      _isSliding = _slideOffset > threshold;
      _slidingMessageId = message.id;
    });

    if (_isSliding) {
      debugPrint(
        '➡️ Slide active: offset=$_slideOffset for message: ${message.content}',
      );
    }
  }

  void _handleSlideEnd(
    DragEndDetails details,
    ClubMessage message,
    bool isOwn,
  ) {
    debugPrint(
      '🔄 _handleSlideEnd: isSliding=$_isSliding, slideOffset=$_slideOffset, messageId=${message.id}',
    );

    if (_isSliding && _slidingMessageId == message.id && _slideOffset > 40.0) {
      // Trigger reply if user slid far enough
      debugPrint('✅ Triggering reply for message: ${message.content}');
      HapticFeedback.selectionClick();
      _setReply(message);
    } else {
      debugPrint(
        '❌ Reply not triggered: isSliding=$_isSliding, slideOffset=$_slideOffset',
      );
    }

    // Reset slide state
    setState(() {
      _slideOffset = 0.0;
      _isSliding = false;
      _slidingMessageId = null;
    });
  }

  void _setReply(ClubMessage message) {
    debugPrint(
      '📝 _setReply called for message: ${message.content} from ${message.senderName}',
    );
    setState(() {
      _replyingTo = MessageReply(
        messageId: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        content: message.content,
        messageType: message.messageType,
      );
    });
    debugPrint('📝 Reply state set: $_replyingTo');
    // Only request focus after a small delay to ensure smooth transition
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted && _replyingTo != null) {
        _textFieldFocusNode.requestFocus();
      }
    });
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    try {
      // Store message IDs before clearing them
      final messageIdsToDelete = _selectedMessageIds.toList();

      // Provide immediate feedback before API call
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.user;

      setState(() {
        for (int i = _messages.length - 1; i >= 0; i--) {
          final message = _messages[i];
          if (_selectedMessageIds.contains(message.id)) {
            if (message.deleted) {
              // Already deleted message - remove completely from list
              _messages.removeAt(i);
            } else {
              // Not deleted yet - mark as deleted with user info
              _messages[i] = message.copyWith(
                deleted: true,
                deletedBy: currentUser?.name ?? 'Someone',
              );
            }
          }
        }
        _exitSelectionMode();
      });

      // Make API call in background using stored IDs
      await ChatApiService.deleteMessages(widget.club.id, messageIdsToDelete);

      if (mounted) {
        // Message deletion successful
      }
    } catch (e) {
      // Error deleting messages
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _navigateToCreateMatch() async {
    // Show match selection dialog
    showDialog(
      context: context,
      builder: (context) => MatchSelectionDialog(
        clubId: widget.club.id,
        onExistingMatchSelected: (match) {
          // Send existing match message to chat
          _sendExistingMatchMessage(match);
          // Unfocus text field to prevent keyboard from opening
          _textFieldFocusNode.unfocus();
        },
        onCreateNewMatch: () {
          // Navigate to create new match
          _navigateToCreateNewMatch();
          // Unfocus text field to prevent keyboard from opening
          _textFieldFocusNode.unfocus();
        },
      ),
    );
  }

  void _navigateToCreatePractice() async {
    // Show practice selection dialog
    showDialog(
      context: context,
      builder: (context) => PracticeSelectionDialog(
        clubId: widget.club.id,
        onExistingPracticeSelected: (practice) {
          // Send existing practice message to chat
          _sendExistingPracticeMessage(practice);
          // Unfocus text field to prevent keyboard from opening
          _textFieldFocusNode.unfocus();
        },
        onCreateNewPractice: () {
          // Navigate to create new practice
          _navigateToCreateNewPractice();
          // Unfocus text field to prevent keyboard from opening
          _textFieldFocusNode.unfocus();
        },
      ),
    );
  }

  void _navigateToCreateNewPractice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePracticeScreen(
          clubId: widget.club.id,
          // Server handles practice message posting automatically when notifyMembers: true
        ),
      ),
    );
  }

  void _navigateToCreateNewMatch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateMatchScreen(
          onMatchCreated: () {
            // Match was created successfully, now send match message to chat
            _createMatchMessage();
          },
        ),
      ),
    );
  }

  void _sendExistingPracticeMessage(MatchListItem practice) async {
    // Get user's membership to determine role
    final clubProvider = context.read<ClubProvider>();
    final membership = clubProvider.clubs
        .where((m) => m.club.id == widget.club.id)
        .firstOrNull;

    // Create temporary message for immediate UI feedback with 'sent' status to prevent duplicate sending
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.club.id,
      senderId: 'current_user',
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: membership?.role ?? 'ADMIN',
      content: '⚽ Practice session: ${practice.opponent?.isNotEmpty == true ? practice.opponent! : 'Practice Session'}',
      messageType: 'practice',
      practiceId: practice.id,
      practiceDetails: {
        'title': practice.opponent?.isNotEmpty == true ? practice.opponent! : 'Practice Session',
        'description': 'Join our training session',
        'date': practice.matchDate.toIso8601String().split('T')[0],
        'time': '${practice.matchDate.hour.toString().padLeft(2, '0')}:${practice.matchDate.minute.toString().padLeft(2, '0')}',
        'venue': practice.location.isNotEmpty ? practice.location : 'Training Ground',
        'duration': '2 hours',
        'type': 'Training',
        'maxParticipants': practice.spots,
        'currentParticipants': practice.confirmedPlayers,
        'isJoined': practice.userRsvp != null && practice.userRsvp!.status == 'YES',
      },
      createdAt: DateTime.now(),
      status: MessageStatus.sent, // Use 'sent' to prevent SelfSendingMessageBubble from sending again
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
    );

    // Add to local messages immediately for UI feedback
    _handleNewMessage(tempMessage);

    // Send practice message to backend directly
    try {
      final practiceData = {
        'content': '⚽ Practice session: ${practice.opponent?.isNotEmpty == true ? practice.opponent! : 'Practice Session'}',
        'practiceId': practice.id,
        'practiceDetails': {
          'title': practice.opponent?.isNotEmpty == true ? practice.opponent! : 'Practice Session',
          'description': 'Join our training session',
          'date': practice.matchDate.toIso8601String().split('T')[0],
          'time': '${practice.matchDate.hour.toString().padLeft(2, '0')}:${practice.matchDate.minute.toString().padLeft(2, '0')}',
          'venue': practice.location.isNotEmpty ? practice.location : 'Training Ground',
          'duration': '2 hours',
          'type': 'Training',
          'maxParticipants': practice.spots,
          'currentParticipants': practice.confirmedPlayers,
          'isJoined': practice.userRsvp != null && practice.userRsvp!.status == 'YES',
        },
      };

      await ChatApiService.sendPracticeMessage(widget.club.id, practiceData);
      
    } catch (e) {
      print('❌ Error sending practice message: $e');
      // Handle error - show snackbar or retry
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send practice announcement'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendExistingPracticeMessage(practice),
            ),
          ),
        );
      }
    }
  }

  void _sendExistingMatchMessage(MatchListItem match) async {
    // Get user's membership to determine role
    final clubProvider = context.read<ClubProvider>();
    final membership = clubProvider.clubs
        .where((m) => m.club.id == widget.club.id)
        .firstOrNull;

    // Create temporary message for immediate UI feedback with 'sent' status to prevent duplicate sending
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.club.id,
      senderId: 'current_user',
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: membership?.role ?? 'ADMIN',
      content: '📅 Match announcement: ${match.club.name} vs ${match.opponent ?? "TBD"}',
      messageType: 'match',
      matchId: match.id,
      matchDetails: {
        'homeTeam': {
          'name': match.club.name,
          'logo': match.club.logo,
        },
        'opponentTeam': {
          'name': match.opponent ?? 'TBD',
          'logo': null,
        },
        'dateTime': match.matchDate.toIso8601String(),
        'venue': {
          'name': match.location.isNotEmpty ? match.location : 'Venue TBD',
          'address': match.location,
        },
      },
      createdAt: DateTime.now(),
      status: MessageStatus.sent, // Use 'sent' to prevent SelfSendingMessageBubble from sending again
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
    );

    // Add to local messages immediately for UI feedback
    _handleNewMessage(tempMessage);

    // Send match message to backend directly
    try {
      final matchData = {
        'content': '📅 Match announcement: ${match.club.name} vs ${match.opponent ?? "TBD"}',
        'matchId': match.id,
        'matchDetails': {
          'homeTeam': {
            'name': match.club.name,
            'logo': match.club.logo,
          },
          'opponentTeam': {
            'name': match.opponent ?? 'TBD',
            'logo': null,
          },
          'dateTime': match.matchDate.toIso8601String(),
          'venue': {
            'name': match.location.isNotEmpty ? match.location : 'Venue TBD',
            'address': match.location,
          },
        },
      };

      await ChatApiService.sendMatchMessage(widget.club.id, matchData);
      
    } catch (e) {
      print('❌ Error sending existing match message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send match announcement'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendExistingMatchMessage(match),
            ),
          ),
        );
      }
    }
  }

  void _createMatchMessage() async {
    // Get user's membership to determine role
    final clubProvider = context.read<ClubProvider>();
    final membership = clubProvider.clubs
        .where((m) => m.club.id == widget.club.id)
        .firstOrNull;

    // Create temporary message for immediate UI feedback with 'sent' status to prevent duplicate sending
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.club.id,
      senderId: 'current_user',
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: membership?.role ?? 'ADMIN',
      content: '📅 New match created! Check your matches to view details and RSVP.',
      messageType: 'match',
      matchId: 'placeholder_match_id',
      matchDetails: {
        'homeTeam': {
          'name': 'Home Team',
          'logo': null,
        },
        'opponentTeam': {
          'name': 'Opponent Team', 
          'logo': null,
        },
        'dateTime': DateTime.now().add(Duration(days: 1)).toIso8601String(),
        'venue': {
          'name': 'Cricket Ground',
          'address': 'TBD',
        },
      },
      createdAt: DateTime.now(),
      status: MessageStatus.sent, // Use 'sent' to prevent SelfSendingMessageBubble from sending again
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
    );

    // Add to local messages immediately for UI feedback
    _handleNewMessage(tempMessage);

    // Send match message to backend directly
    try {
      final matchData = {
        'content': '📅 New match created! Check your matches to view details and RSVP.',
        'matchId': 'placeholder_match_id', // In real implementation, this would come from CreateMatchScreen
        'matchDetails': {
          'homeTeam': {
            'name': 'Home Team',
            'logo': null,
          },
          'opponentTeam': {
            'name': 'Opponent Team', 
            'logo': null,
          },
          'dateTime': DateTime.now().add(Duration(days: 1)).toIso8601String(),
          'venue': {
            'name': 'Cricket Ground',
            'address': 'TBD',
          },
        },
      };

      await ChatApiService.sendMatchMessage(widget.club.id, matchData);
      
      // Update message status to sent
      // In a real implementation, you'd update the message in your state management
      
    } catch (e) {
      print('❌ Error sending match message: $e');
      // Handle error - show snackbar or retry
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send match announcement'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _createMatchMessage(),
            ),
          ),
        );
      }
    }
  }


  void _handleNewMessage(ClubMessage tempMessage) {
    debugPrint(
      '🔍 ClubChat: _handleNewMessage called with tempMessage id: ${tempMessage.id}',
    );
    debugPrint('🔍 ClubChat: tempMessage replyTo: ${tempMessage.replyTo}');
    debugPrint('🔍 ClubChat: _replyingTo state: $_replyingTo');

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) {
      debugPrint('🔍 ClubChat: User is null, returning');
      return;
    }

    debugPrint('🔍 ClubChat: User found: ${user.name} (${user.id})');

    // Fill in user information
    final message = ClubMessage(
      id: tempMessage.id,
      clubId: tempMessage.clubId,
      senderId: user.id,
      senderName: user.name,
      senderProfilePicture: user.profilePicture,
      senderRole: tempMessage.senderRole,
      content: tempMessage.content,
      messageType: tempMessage.messageType,
      createdAt: tempMessage.createdAt,
      status: tempMessage.status,
      errorMessage: tempMessage.errorMessage,
      starred: tempMessage.starred,
      pin: tempMessage.pin,
      // ✅ MEDIA FIELDS - Critical for video/audio/document uploads
      images: tempMessage.images,
      document: tempMessage.document,
      audio: tempMessage.audio,
      linkMeta: tempMessage.linkMeta,
      gifUrl: tempMessage.gifUrl,
      // ✅ RICH MESSAGE TYPE FIELDS - Critical for practice/match/poll messages
      practiceId: tempMessage.practiceId,
      practiceDetails: tempMessage.practiceDetails,
      matchId: tempMessage.matchId,
      matchDetails: tempMessage.matchDetails,
      locationDetails: tempMessage.locationDetails,
      pollId: tempMessage.pollId,
      pollDetails: tempMessage.pollDetails,
      // ✅ OTHER FIELDS
      reactions: tempMessage.reactions,
      deleted: tempMessage.deleted,
      deletedBy: tempMessage.deletedBy,
      deliveredAt: tempMessage.deliveredAt,
      readAt: tempMessage.readAt,
      replyTo: _replyingTo, // Add reply if replying
    );

    debugPrint(
      '🔍 ClubChat: Created final message with replyTo: ${message.replyTo}',
    );

    // Clear reply state
    _cancelReply();

    // Add to messages list optimistically
    setState(() {
      _messages.add(message);
    });

    debugPrint(
      '🔍 ClubChat: Added message to _messages list. Total messages: ${_messages.length}',
    );
  }

  Future<void> _triggerAudioRecordingFromPull() async {
    HapticFeedback.heavyImpact();
    debugPrint('🎤 Triggering audio recording from pull gesture');

    // Immediately hide the indicator when recording is triggered
    _resetAudioPullState();

    // Start audio recording via the audio widget
    final audioWidgetState = _audioRecordingKey.currentState;
    if (audioWidgetState != null && !audioWidgetState.isRecording) {
      try {
        // Start recording programmatically using the new public method
        await audioWidgetState.startRecordingProgrammatically();
        debugPrint('✅ Audio recording started successfully from pull gesture');
      } catch (e) {
        debugPrint('❌ Error starting audio recording: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final footerHeight = 80.0; // Approximate height of message input footer

    // Get user's membership to determine role
    final clubProvider = Provider.of<ClubProvider>(context);
    final membership = clubProvider.clubs
        .where((m) => m.club.id == widget.club.id)
        .firstOrNull;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: ChatAppBar(
        club: widget.club,
        userRole: membership?.role,
        isSelectionMode: _isSelectionMode,
        selectedMessageIds: _selectedMessageIds,
        refreshAnimationController: _refreshAnimationController,
        onBackPressed: () => Navigator.of(context).pop(),
        onShowClubInfo: _showClubInfoDialog,
        onManageClub: membership != null && 
            (membership.role.toLowerCase() == 'admin' || 
             membership.role.toLowerCase() == 'owner')
            ? () => _navigateToManageClub(membership)
            : null,
        onExitSelectionMode: _exitSelectionMode,
        onDeleteSelectedMessages: _deleteSelectedMessages,
        onRefreshMessages: () {
          debugPrint('🔄 App bar refresh pressed, forcing sync...');
          _loadMessages(forceSync: true);
        },
        onShowMoreOptions: _showMoreOptions,
      ),
      body: Stack(
        children: [
          // Fixed background that never moves
          Positioned.fill(
            child: Image.asset(
              isDarkTheme
                  ? 'assets/images/chat-bg-dark.png'
                  : 'assets/images/chat-bg-light.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Messages area that adjusts for keyboard
          SafeArea(
            child: Column(
              children: [
                // Messages List - Takes all available space above input
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: keyboardHeight + footerHeight,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onPanStart: (details) {
                          // Track where the pan/scroll gesture starts
                          final messagesHeight =
                              MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom -
                              keyboardHeight -
                              footerHeight;
                          final startY = details.localPosition.dy;
                          final bottom30Percent =
                              messagesHeight * 0.7; // 70% from top = bottom 30%

                          setState(() {
                            _canActivateRecording = startY > bottom30Percent;
                          });

                          debugPrint(
                            '🎯 Pan gesture started at ${startY}px, bottom 30% starts at ${bottom30Percent}px, can activate: $_canActivateRecording',
                          );
                        },
                        onPanEnd: (details) {
                          // Reset recording activation when pan gesture ends
                          setState(() {
                            _canActivateRecording = false;
                          });
                          debugPrint(
                            '🎯 Pan gesture ended, recording activation reset',
                          );
                        },
                        onTap: () {
                          // Close keyboard when tapping in messages area
                          FocusScope.of(context).unfocus();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: _error != null
                            ? _buildErrorState(_error!)
                            : _messages.isEmpty
                            ? _buildEmptyState()
                            : _buildMessagesList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Circular progress indicator for pull-to-record (overlay)
          // Only show if pulling for audio and not already recording
          if (_isPullingForAudio &&
              !(_audioRecordingKey.currentState?.isRecording ?? false))
            Positioned(
              bottom: keyboardHeight + 100,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular progress with mic icon - no container
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Circular progress indicator
                          CircularProgressIndicator(
                            value: _audioRecordingPullProgress,
                            strokeWidth: 3,
                            backgroundColor: Colors.grey.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _audioRecordingPullProgress >= 1.0
                                  ? Colors.green
                                  : Color(0xFF06aeef),
                            ),
                          ),
                          // Microphone icon
                          Icon(
                            Icons.mic,
                            color: _audioRecordingPullProgress >= 1.0
                                ? Colors.green
                                : Color(0xFF06aeef),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    // Text below the circle in single line - three states
                    Text(
                      _audioRecordingPullProgress >= 1.0
                          ? 'Release to talk'
                          : _isInRecordingMode
                          ? 'Keep holding to talk'
                          : 'Swipe up to talk',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Footer with reply preview and input - always at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: isDarkTheme ? Color(0xFF1e2428) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDarkTheme
                        ? Colors.grey[700]!.withOpacity(0.3)
                        : Colors.grey[300]!.withOpacity(0.5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply preview (if replying to a message)
                  if (_replyingTo != null) _buildReplyPreview(),

                  // Message Input - Fixed at bottom (hidden during recording mode)
                  if (!_isInRecordingMode)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: MessageInput(
                        messageController: _messageController,
                        textFieldFocusNode: _textFieldFocusNode,
                        clubId: widget.club.id,
                        audioRecordingKey: _audioRecordingKey,
                        onSendMessage: _handleNewMessage,
                        upiId: widget.club.upiId,
                        userRole: membership?.role,
                        onCreateMatch: _navigateToCreateMatch,
                        onCreatePractice: _navigateToCreatePractice,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    // Derived set of currently pinned messages (for top navigation section)
    final pinnedMessages = _messages
        .where((m) => _isCurrentlyPinned(m))
        .toList();

    // All messages in chronological order (including pinned ones)
    final allMessages = List<ClubMessage>.from(_messages);
    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Build list items including date headers
    final List<dynamic> listItems = _buildListItemsWithDateHeaders(allMessages);

    return Column(
      children: [
        // Top section: Derived set of pinned messages (tap to navigate to actual message)
        if (pinnedMessages.isNotEmpty)
          PinnedMessagesSection(
            messages: _messages,
            onScrollToMessage: _scrollToMessage,
            onHighlightMessage: _highlightMessage,
            onTogglePin: _togglePin,
            canPinMessages: () => _cachedCanPinMessages ?? false,
            clubId: widget.club.id,
          ),

        // Chat flow: ALL messages including pinned ones in chronological order
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                itemCount: listItems.length,
                itemBuilder: (context, index) {
                  final item = listItems[index];

                  // Check if item is a date header
                  if (item is DateTime) {
                    return ChatHeader.date(date: item);
                  }

                  // Otherwise it's a message
                  final message = item as ClubMessage;
                  final messageIndex = allMessages.indexOf(message);
                  final previousMessage = messageIndex > 0
                      ? allMessages[messageIndex - 1]
                      : null;
                  final nextMessage = messageIndex < allMessages.length - 1
                      ? allMessages[messageIndex + 1]
                      : null;

                  final showSenderInfo =
                      previousMessage == null ||
                      previousMessage.senderId != message.senderId ||
                      !_isSameDate(
                        message.createdAt,
                        previousMessage.createdAt,
                      );

                  final isLastFromSender =
                      nextMessage == null ||
                      nextMessage.senderId != message.senderId ||
                      !_isSameDate(message.createdAt, nextMessage.createdAt);

                  return Container(
                    key: ValueKey('message_${message.id}'),
                    child: MessageVisibilityDetector(
                      itemId: message.id,
                      onVisible: _markMessageAsSeen,
                      skipTracking:
                          message.senderId ==
                          context.read<UserProvider>().user?.id,
                      child: MessageBubbleWrapper(
                        message: message,
                        showSenderInfo: showSenderInfo,
                        isLastFromSender: isLastFromSender,
                        clubId: widget.club.id,
                        isSelectionMode: _isSelectionMode,
                        selectedMessageIds: _selectedMessageIds,
                        onToggleSelection: _toggleSelection,
                        highlightedMessageId: _highlightedMessageId,
                        isSliding: _isSliding,
                        slidingMessageId: _slidingMessageId,
                        slideOffset: _slideOffset,
                        onSlideUpdate: _handleSlideGesture,
                        onSlideEnd: _handleSlideEnd,
                        onMessageUpdated: _handleMessageUpdated,
                        onMessageFailed: _handleMessageFailed,
                        onReactionRemoved: _handleReactionRemoved,
                        canPinMessages: _cachedCanPinMessages ?? false,
                        isCurrentlyPinned: _isCurrentlyPinned,
                        onReplyTap: _scrollToMessage,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Handle pull-to-refresh at top of screen
  Future<void> _handleRefresh() async {
    debugPrint('🔄 Pull-to-refresh triggered');
    await _loadMessages();
  }

  // Handle scroll notifications for bottom refresh detection and audio recording pull
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final scrollPosition = notification.metrics.pixels;
      final maxScroll = notification.metrics.maxScrollExtent;

      // Check if user is overscrolling at the bottom (beyond max scroll)
      // Only allow pull-to-record if user tapped in bottom 20% first and not already recording
      // Require minimum overscroll to distinguish from just reaching bottom
      final minOverscrollRequired = 8.0;
      if (scrollPosition > maxScroll + minOverscrollRequired &&
          _canActivateRecording &&
          !(_audioRecordingKey.currentState?.isRecording ?? false)) {
        final overscroll = scrollPosition - maxScroll;
        final showThreshold =
            30.0 +
            minOverscrollRequired; // 38px total: 8px buffer + 30px to show

        debugPrint('🎤 Overscroll detected: ${overscroll}px beyond bottom');

        setState(() {
          _isPullingForAudio = overscroll > showThreshold;
          _isInRecordingMode =
              overscroll > 5.0; // Enter recording mode with minimal pull
          // Calculate progress from the show threshold, not from zero
          _audioRecordingPullProgress = _isPullingForAudio
              ? ((overscroll - showThreshold) /
                        (_audioRecordingPullThreshold - showThreshold))
                    .clamp(0.0, 1.0)
              : 0.0;
        });

        if (_audioRecordingPullProgress >= 1.0) {
          // Trigger audio recording when pull is complete
          _triggerAudioRecordingFromPull();
        }
      } else {
        // Reset pull state when not overscrolling or when recording is active
        if (_isPullingForAudio || _isInRecordingMode) {
          _resetAudioPullState();
        }
      }
    } else if (notification is ScrollEndNotification) {
      final scrollPosition = notification.metrics.pixels;
      final maxScroll = notification.metrics.maxScrollExtent;

      // Regular bottom refresh for message sync (only if not in audio pull mode and not recording)
      if (scrollPosition >= maxScroll - 50 &&
          !_isPullingForAudio &&
          !(_audioRecordingKey.currentState?.isRecording ?? false)) {
        debugPrint('🔄 Bottom pull detected, refreshing messages...');
        _handleBottomRefresh();
      }

      // Reset pull state on scroll end (user let go) - but only if not recording
      if (_isPullingForAudio &&
          !(_audioRecordingKey.currentState?.isRecording ?? false)) {
        _resetAudioPullState();
      }
    }

    return false; // Allow other listeners to receive the notification
  }

  void _resetAudioPullState() {
    setState(() {
      _isPullingForAudio = false;
      _audioRecordingPullProgress = 0.0;
      _isInRecordingMode = false;
    });
  }

  // Handle bottom pull refresh with debouncing
  void _handleBottomRefresh() {
    // Don't refresh if already loading
    if (_isLoading) return;

    // Debounce rapid scroll events (wait 1 second between refreshes)
    _bottomRefreshTimer?.cancel();
    _bottomRefreshTimer = Timer(Duration(seconds: 1), () {
      // Trigger refresh with haptic feedback
      HapticFeedback.lightImpact();
      _loadMessages();
    });
  }

  // Helper method to build list items with date headers
  List<dynamic> _buildListItemsWithDateHeaders(List<ClubMessage> messages) {
    final List<dynamic> items = [];
    DateTime? lastDate;

    for (final message in messages) {
      final messageDate = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );

      // Add date header if this is a new date
      if (lastDate == null || !_isSameDate(messageDate, lastDate)) {
        items.add(messageDate);
        lastDate = messageDate;
      }

      // Add the message
      items.add(message);
    }

    return items;
  }

  // Async method to check if user can share UPI QR

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return SizedBox.shrink();

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkTheme
                ? Colors.grey[700]!.withOpacity(0.3)
                : Colors.grey[300]!.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 40, color: Color(0xFF06aeef)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: Color(0xFF06aeef)),
                    SizedBox(width: 4),
                    Text(
                      'Replying to ${_replyingTo!.senderName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF06aeef),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  _replyingTo!.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
            icon: Icon(
              Icons.close,
              size: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              'Unable to load messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(onPressed: _loadMessages, child: Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start the conversation with ${widget.club.name}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClubInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => ClubInfoDialog(
        club: widget.club,
        detailedClubInfo: _detailedClubInfo,
      ),
    );
  }

  void _navigateToManageClub(ClubMembership membership) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageClubScreen(
          club: widget.club, 
          membership: membership,
        ),
      ),
    );
  }

  void _togglePin(ClubMessage message) async {
    if (_isCurrentlyPinned(message)) {
      // If already pinned, just unpin
      await _unpinMessage(message);
    } else {
      // If not pinned, show duration picker
      _showPinDurationPicker(message);
    }
  }

  void _showPinDurationPicker(ClubMessage message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2D3748)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose how long your new\npin lasts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'You can unpin at any time.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),

              // Duration options
              _buildPinDurationOption('24 hours', 24, message),
              _buildPinDurationOption('7 days', 24 * 7, message),
              _buildPinDurationOption('30 days', 24 * 30, message),

              SizedBox(height: 24),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDurationOption(String label, int hours, ClubMessage message) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      child: TextButton(
        onPressed: () {
          Navigator.pop(context);
          _pinMessageWithDuration(message, hours);
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
      ),
    );
  }

  Future<void> _pinMessageWithDuration(ClubMessage message, int hours) async {
    try {
      final requestData = {'durationHours': hours};
      await ChatApiService.pinMessage(widget.club.id, message.id, requestData);
      // Sync from server to get authoritative pinned status for all users
      await _syncMessagesFromServer(forceSync: false);
    } catch (e) {
      // Error pinning message
    }
  }

  Future<void> _unpinMessage(ClubMessage message) async {
    try {
      await ChatApiService.unpinMessage(widget.club.id, message.id);

      // Sync from server to get authoritative pinned status for all users
      await _syncMessagesFromServer(forceSync: false);
    } catch (e) {
      // Error unpinning message
    }
  }

  bool _isMarkingDelivered =
      false; // Lock to prevent concurrent delivery marking
  final Set<String> _processingDelivery =
      <String>{}; // Track messages currently being marked as delivered

  // Helper method to check if current user can pin messages
  Future<bool> _canPinMessages() async {
    if (_detailedClubInfo == null) return false;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return false;

    // Get the allowed roles for pinning messages from club settings
    final allowedRoles = _detailedClubInfo!.pinMessagePermissions;

    // Use the new UserProvider method to check if user has any of the allowed roles
    try {
      return await userProvider.hasRoleInClub(widget.club.id, allowedRoles);
    } catch (e) {
      debugPrint('Error checking pin permissions: $e');
      // Fallback to the old method if UserProvider fails
      final userMessages = _messages
          .where((m) => m.senderId == user.id)
          .toList();
      if (userMessages.isNotEmpty) {
        final userRole = userMessages.first.senderRole ?? 'MEMBER';
        return allowedRoles.contains(userRole);
      }
      return allowedRoles.contains('MEMBER');
    }
  }

  // Update cached permissions
  Future<void> _updatePermissions() async {
    final canPin = await _canPinMessages();

    if (mounted) {
      setState(() {
        _cachedCanPinMessages = canPin;
      });
    }
  }

  // Helper method to check if two timestamps are on the same date
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Helper method to check if a message is currently pinned
  // Uses the authoritative pin status from the API (pin.isPinned)
  bool _isCurrentlyPinned(ClubMessage message) {
    return message.pin.isPinned;
  }

  // Push notification callback handles real-time message updates instead of polling

  void _scrollToMessage(String messageId) {
    debugPrint('🎯 Attempting to scroll to message: $messageId');

    // Sort messages by creation time to match the ListView order
    final allMessages = List<ClubMessage>.from(_messages);
    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final sortedIndex = allMessages.indexWhere((m) => m.id == messageId);
    if (sortedIndex == -1) {
      debugPrint('❌ Message not found: $messageId');
      return;
    }

    // Highlight the message temporarily
    setState(() {
      _highlightedMessageId = messageId;
    });

    // Clear highlight after 3 seconds
    _highlightTimer?.cancel();
    _highlightTimer = Timer(Duration(seconds: 3), () {
      setState(() {
        _highlightedMessageId = null;
      });
    });

    // Calculate scroll position with better handling for end messages
    final itemHeight = 100.0; // Approximate height per message
    final targetOffset = sortedIndex * itemHeight;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;

    // Ensure we don't scroll beyond the maximum extent
    final adjustedOffset = targetOffset > maxScrollExtent
        ? maxScrollExtent
        : targetOffset;

    // For messages at the very end, scroll to bottom with some padding
    final isNearEnd = sortedIndex >= allMessages.length - 3;
    final finalOffset = isNearEnd ? maxScrollExtent : adjustedOffset;

    _scrollController.animateTo(
      finalOffset,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );

    debugPrint('✅ Scrolling to message at index $sortedIndex');
  }

  void _highlightMessage(String messageId) {
    // Set the highlighted message ID for visual feedback
    setState(() {
      _highlightedMessageId = messageId;
    });

    // Remove highlight after 2 seconds
    Timer(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });

    debugPrint('🎯 Highlighted message: $messageId');
  }
}
