import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:async';
import '../../providers/user_provider.dart';
import '../../models/club.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/message_reply.dart';
import '../../models/message_reaction.dart';
import '../../services/chat_api_service.dart';
import '../../services/message_storage_service.dart';
import '../../services/api_service.dart';
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
import '../manage/club_matches.dart';
import '../manage/club_transactions.dart';
import '../manage/club_teams_screen.dart';
import '../manage/add_members_screen.dart';
import '../../providers/club_provider.dart';
import '../../models/shared_content.dart';

// Wrapper class to pre-calculate expensive properties and avoid rebuilds
class _MessageWrapper {
  final ClubMessage message;
  final bool showSenderInfo;
  final bool isLastFromSender;
  final bool isFirstFromSender;

  _MessageWrapper({
    required this.message,
    required this.showSenderInfo,
    required this.isLastFromSender,
    required this.isFirstFromSender,
  });
}

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

  // Message input widget key
  final GlobalKey<MessageInputState> _messageInputKey =
      GlobalKey<MessageInputState>();

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
  bool _previousFocusState =
      false; // Track previous focus state to prevent unwanted focus changes
  bool _allowProgrammaticFocus =
      false; // Flag to control when programmatic focus is allowed
  bool _isModalOpen = false; // Track when modals are open to prevent focus
  bool _showScrollToBottomButton =
      false; // Show scroll-to-bottom floating button

  @override
  void initState() {
    super.initState();
    // Initialize refresh animation controller
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Load persistent delivered/read status flags
    _loadPersistentStatusFlags();
    // Load messages (cache-first approach)
    _loadMessages();

    // Setup push notification callback instead of polling
    _setupPushNotificationCallback();

    // Add focus listener to scroll to bottom when keyboard opens
    _textFieldFocusNode.addListener(() {
      final currentFocusState = _textFieldFocusNode.hasFocus;

      // Only react to actual focus state changes to prevent reaction-triggered focus issues
      if (currentFocusState != _previousFocusState) {
        _previousFocusState = currentFocusState;

        // Prevent unwanted focus when modals are open or programmatic focus is not allowed
        if (currentFocusState && !_allowProgrammaticFocus && _isModalOpen) {
          debugPrint('🚫 Prevented unwanted focus while modal is open');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _textFieldFocusNode.unfocus();
            }
          });
          return;
        }

        // Only scroll to bottom when gaining focus (keyboard opens)
        if (currentFocusState && _messages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }

        // Note: Removed setState() call here as it's not needed and causes unwanted focus events
        // The UI will update naturally when the keyboard appears/disappears
      }
    });

    // Add scroll listener to track scroll position for scroll-to-bottom button
    _scrollController.addListener(_onScrollChanged);

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
    debugPrint(
      '🔔 Setting up push notification callback for club: ${widget.club.id}',
    );

    NotificationService.setClubMessageCallback(widget.club.id, (
      Map<String, dynamic> data,
    ) {
      debugPrint('💬 Received push notification data: $data');

      // Check if this is a message update notification
      final isUpdate = data['isUpdate'] == true;
      final messageId = data['messageId'] as String?;

      if (isUpdate && messageId != null) {
        debugPrint(
          '📝 Received message update notification for message: $messageId',
        );
        // Handle message update by patching the specific message
        _handleMessageUpdate(data);
      } else {
        // This is a new message notification - refresh normally
        debugPrint(
          '✅ Push notification received for current club, refreshing messages',
        );

        // Use a slight delay to ensure the server has processed the message
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            debugPrint('🔄 Callback triggered: Refreshing messages now...');
            // Force a fresh sync to ensure we get the new message
            _loadMessages(forceSync: true);
          } else {
            debugPrint('⚠️ Widget not mounted, skipping message refresh');
          }
        });
      }
    });
  }

  /// Handle message update notifications by patching the specific message
  void _handleMessageUpdate(Map<String, dynamic> data) {
    debugPrint('📝 Handling message update: $data');

    final messageId = data['messageId'] as String?;
    final updatedContent = data['messageContent'] as String?;

    if (messageId == null) {
      debugPrint('⚠️ No messageId in update notification');
      return;
    }

    if (updatedContent == null) {
      debugPrint('⚠️ No updated content in notification');
      return;
    }

    // Find the message in the current list
    final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) {
      debugPrint('⚠️ Message with ID $messageId not found in current list');
      // Message not in current view, trigger a full refresh
      debugPrint('🔄 Message not in view, triggering full refresh...');
      _loadMessages(forceSync: true);
      return;
    }

    // Create a new ClubMessage with updated content
    final originalMessage = _messages[messageIndex];
    final updatedMessage = ClubMessage(
      id: originalMessage.id,
      clubId: originalMessage.clubId,
      senderId: originalMessage.senderId,
      senderName: originalMessage.senderName,
      senderProfilePicture: originalMessage.senderProfilePicture,
      senderRole: originalMessage.senderRole,
      content: updatedContent, // Update the content
      images: originalMessage.images,
      document: originalMessage.document,
      audio: originalMessage.audio,
      linkMeta: originalMessage.linkMeta,
      gifUrl: originalMessage.gifUrl,
      messageType: originalMessage.messageType,
      createdAt: originalMessage.createdAt,
      status: originalMessage.status,
      errorMessage: originalMessage.errorMessage,
      reactions: originalMessage.reactions,
      reactionsCount: originalMessage.reactionsCount,
      replyTo: originalMessage.replyTo,
      deleted: originalMessage.deleted,
      deletedBy: originalMessage.deletedBy,
      starred: originalMessage.starred,
      matchId: originalMessage.matchId,
      practiceId: originalMessage.practiceId,
      meta: originalMessage.meta,
      pollId: originalMessage.pollId,
      pin: originalMessage.pin,
      deliveredAt: originalMessage.deliveredAt,
      readAt: originalMessage.readAt,
      deliveredTo: originalMessage.deliveredTo,
      readBy: originalMessage.readBy,
    );

    // Update the message in place
    setState(() {
      _messages[messageIndex] = updatedMessage;
    });

    debugPrint('✅ Successfully updated message $messageId content in UI');
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _bottomRefreshTimer?.cancel();
    _refreshAnimationController.dispose();
    _messageController.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _textFieldFocusNode.dispose();

    // Clear push notification callback for this club
    NotificationService.clearClubMessageCallback(widget.club.id);

    super.dispose();
  }

  Future<void> _loadMessages({bool forceSync = false}) async {
    try {
      debugPrint(
        '🚀 _loadMessages called - forceSync: $forceSync, mounted: $mounted',
      );

      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Start refresh animation
      _refreshAnimationController.repeat();

      debugPrint('🚀 Loading messages efficiently (Telegram-style)...');

      // Load existing messages from cache first (for instant UI)
      final cachedMessages = await MessageStorageService.loadMessages(
        widget.club.id,
      );

      // For bottom refreshes, skip the cached setState to avoid double rebuild
      // Only update state with cached messages if this is not a bottom refresh
      if (cachedMessages.isNotEmpty && !forceSync && _messages.isEmpty) {
        setState(() {
          _messages = cachedMessages;
          _isLoading = false;
        });

        // Stop refresh animation and reset to 0
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
      }

      // Fetch only new messages efficiently using enhanced ChatApiService
      final lastMessageId = cachedMessages.isNotEmpty && !forceSync
          ? cachedMessages.last.id
          : null;

      final response = await ChatApiService.getMessagesEfficient(
        widget.club.id,
        lastMessageId: lastMessageId,
        forceFullSync: forceSync,
        limit: 50,
      );

      List<ClubMessage> newMessages = [];
      if (response != null) {
        final messagesData = response['messages'] as List<dynamic>;
        newMessages = messagesData
            .map((json) => ClubMessage.fromJson(json))
            .toList();

        // Apply local soft delete filter - remove locally deleted messages
        // TODO: This could be moved to a utility method if needed elsewhere
        // For now, just return all messages since soft delete is handled server-side
      }

      if (newMessages.isNotEmpty) {
        debugPrint('🆕 Got ${newMessages.length} new messages');

        // Use existing messages as base to avoid rebuilding all widgets
        List<ClubMessage> currentMessages = List.from(_messages);
        bool hasNewAdditions = false;

        // Only add truly new messages (avoid duplicates with smart matching)
        for (final newMessage in newMessages) {
          final existingIndex = _findExistingMessageIndex(
            currentMessages,
            newMessage,
          );
          if (existingIndex != -1) {
            // Update existing message (replace temp with real message)
            currentMessages[existingIndex] = newMessage;
          } else {
            // Add new message - this is a true addition
            currentMessages.add(newMessage);
            hasNewAdditions = true;
          }
        }

        // Only sort and setState if there are actual new additions
        if (hasNewAdditions) {
          // Sort by creation time
          currentMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          // Update state with incremental changes
          debugPrint(
            '📱 Updating UI state with ${currentMessages.length} messages',
          );
          setState(() {
            _messages = currentMessages;
            _isLoading = false;
          });
          debugPrint('✅ UI state updated successfully');
        } else {
          // No new messages, just update loading state
          debugPrint('ℹ️ No new messages found, just updating loading state');
          setState(() {
            _isLoading = false;
          });
        }

        // Save to local cache
        await MessageStorageService.saveMessages(
          widget.club.id,
          currentMessages,
        );

        // Media will be cached lazily when widgets display them

        // Mark new messages as delivered
        await _markNewMessagesAsDelivered();

        debugPrint(
          '✅ Successfully loaded and cached ${currentMessages.length} total messages',
        );
      } else {
        // No new messages, just stop loading state if needed
        if (_isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
        debugPrint('📭 No new messages found');
      }

      // Stop refresh animation
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();
    } catch (e) {
      debugPrint('❌ Error in efficient message loading: $e');

      // Fallback to cache if available
      if (_messages.isEmpty) {
        final cachedMessages = await MessageStorageService.loadMessages(
          widget.club.id,
        );
        if (cachedMessages.isNotEmpty) {
          setState(() {
            _messages = cachedMessages;
            _isLoading = false;
          });
          debugPrint(
            '📱 Fallback: Loaded ${cachedMessages.length} cached messages',
          );
        } else {
          _error = 'Unable to load messages. Please check your connection.';
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }

      // Stop refresh animation on error
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();
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

    // Find messages from other users that need to be marked as delivered
    final messagesToMark = _messages
        .where(
          (message) =>
              message.senderId != currentUserId && // Not own message
              message.status == MessageStatus.sent,
        ) // Still in sent status
        .map((message) => message.id)
        .toList();

    if (messagesToMark.isNotEmpty) {
      debugPrint(
        '📧 Marking ${messagesToMark.length} messages as delivered efficiently',
      );

      // Mark messages as delivered individually
      bool success = true;
      for (final messageId in messagesToMark) {
        try {
          final delivered = await ChatApiService.markAsDelivered(
            widget.club.id,
            messageId,
          );
          if (!delivered) success = false;
        } catch (e) {
          print('❌ Failed to mark message $messageId as delivered: $e');
          success = false;
        }
      }

      if (success) {
        // Update local message status for immediate UI feedback
        setState(() {
          for (final message in _messages) {
            if (messagesToMark.contains(message.id)) {
              final updatedMessage = message.copyWith(
                status: MessageStatus.delivered,
                deliveredAt: DateTime.now(),
              );
              final index = _messages.indexOf(message);
              _messages[index] = updatedMessage;
            }
          }
        });

        // Save updated messages to cache
        await MessageStorageService.saveMessages(widget.club.id, _messages);
      }
    }
  }

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
      if (newMessages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }

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

      debugPrint(
        '🌐 Fetching messages from server for club: ${widget.club.id}',
      );
      final response = await ChatApiService.getMessages(widget.club.id);
      debugPrint(
        '🌐 Server response received: ${response != null ? 'success' : 'null'}',
      );

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

  void _handleMoreOptionSelected(String option) async {
    // Unfocus any active input to prevent keyboard issues
    FocusScope.of(context).unfocus();

    // Get user's membership to determine role
    final clubProvider = Provider.of<ClubProvider>(context, listen: false);
    final membership = clubProvider.clubs
        .where((m) => m.club.id == widget.club.id)
        .firstOrNull;

    // Handle menu selection
    switch (option) {
      case 'add_members':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddMembersScreen(
              club: widget.club,
              onContactsSelected: _processSelectedContacts,
              onSyncedContactsSelected: _processSelectedSyncedContacts,
              showSuccessToast:
                  false, // No toast in chat, system messages will appear
            ),
          ),
        );
        break;

      case 'manage_club':
        if (membership != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ManageClubScreen(club: widget.club, membership: membership),
            ),
          );
        }
        break;

      case 'matches':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubMatchesScreen(club: widget.club),
          ),
        );
        break;

      case 'transactions':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubTransactionsScreen(club: widget.club),
          ),
        );
        break;

      case 'teams':
        final isAdminOrOwner =
            membership?.role.toLowerCase() == 'admin' ||
            membership?.role.toLowerCase() == 'owner';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ClubTeamsScreen(club: widget.club, isReadOnly: !isAdminOrOwner),
          ),
        );
        break;

      case 'clear_messages':
        _showClearMessagesDialog();
        break;
    }
  }

  void _showClearMessagesDialog() {
    // Use platform-specific dialog
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      _showIOSClearMessagesDialog();
    } else {
      _showAndroidClearMessagesDialog();
    }
  }

  void _showIOSClearMessagesDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        bool keepStarredAndPinned = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: Text('Clear Messages'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'This will delete all messages from your device. This action cannot be undone.',
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        keepStarredAndPinned = !keepStarredAndPinned;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          keepStarredAndPinned
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          color: keepStarredAndPinned
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.inactiveGray,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Keep starred and pinned',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: Text('Clear Messages'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearMessages(keepStarredAndPinned);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAndroidClearMessagesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool keepStarredAndPinned = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.clear_all, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Clear Messages'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will delete all messages from your device. This action cannot be undone.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text('Keep starred and pinned'),
                    subtitle: Text('Preserve important messages'),
                    value: keepStarredAndPinned,
                    onChanged: (bool? value) {
                      setState(() {
                        keepStarredAndPinned = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearMessages(keepStarredAndPinned);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Clear Messages'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearMessages(bool keepStarredAndPinned) async {
    try {
      debugPrint(
        '🗑️ Starting to clear messages. Keep starred/pinned: $keepStarredAndPinned',
      );

      List<ClubMessage> messagesToKeep = [];

      if (keepStarredAndPinned) {
        // Filter messages to keep starred and pinned ones
        messagesToKeep = _messages.where((message) {
          return message.starred.isStarred || _isCurrentlyPinned(message);
        }).toList();

        debugPrint(
          '🌟 Keeping ${messagesToKeep.length} starred/pinned messages',
        );
      }

      // Clear messages from local storage
      await MessageStorageService.clearMessages(widget.club.id);

      // If keeping some messages, save them back
      if (messagesToKeep.isNotEmpty) {
        for (var message in messagesToKeep) {
          await MessageStorageService.addMessage(widget.club.id, message);
        }
      }

      // Update UI
      setState(() {
        _messages = messagesToKeep;
        _selectedMessageIds.clear();
        _isSelectionMode = false;
      });

      debugPrint('✅ Messages cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing messages: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Text('Failed to clear messages'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _processSelectedContacts(List<Contact> contacts) {
    // This method will be called when members are successfully added
    // The actual member addition logic is handled in AddMembersScreen
    // Refresh messages to show system messages for added members
    if (mounted) {
      _loadMessages(forceSync: true);
    }
  }

  void _processSelectedSyncedContacts(List<SyncedContact> syncedContacts) {
    // This method will be called when synced contacts are successfully added
    // The actual member addition logic is handled in AddMembersScreen
    // Refresh messages to show system messages for added members
    if (mounted) {
      _loadMessages(forceSync: true);
    }
  }

  /// Find existing message index with smart matching for temp messages
  int _findExistingMessageIndex(
    List<ClubMessage> messages,
    ClubMessage newMessage,
  ) {
    // First try exact ID match
    final exactMatch = messages.indexWhere((m) => m.id == newMessage.id);
    if (exactMatch != -1) return exactMatch;

    // For server messages, also check if we have a temp message that matches
    // This handles the case where optimistic message becomes real server message
    if (!newMessage.id.startsWith('temp_')) {
      final tempMatch = messages.indexWhere(
        (m) =>
            m.id.startsWith('temp_') &&
            m.senderId == newMessage.senderId &&
            m.content == newMessage.content &&
            m.messageType == newMessage.messageType &&
            // For practice/match messages, also match by practiceId/matchId
            (newMessage.messageType == 'practice'
                ? m.practiceId == newMessage.practiceId
                : true) &&
            (newMessage.messageType == 'match'
                ? m.matchId == newMessage.matchId
                : true) &&
            // Match within 30 seconds to account for server processing time
            (newMessage.createdAt.difference(m.createdAt).inSeconds.abs() < 30),
      );
      if (tempMatch != -1) return tempMatch;
    }

    return -1; // No match found
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
  }

  void _handleSlideEnd(
    DragEndDetails details,
    ClubMessage message,
    bool isOwn,
  ) {
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
    // Allow programmatic focus for reply action and request focus after a small delay
    _allowProgrammaticFocus = true;
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted && _replyingTo != null) {
        _textFieldFocusNode.requestFocus();
      }
      // Reset flag after a short delay to prevent other unwanted focus requests
      Future.delayed(Duration(milliseconds: 100), () {
        _allowProgrammaticFocus = false;
      });
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

  void _handleNewMessage(ClubMessage tempMessage) {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) {
      return;
    }

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
      matchId: tempMessage.matchId,
      pollId: tempMessage.pollId,
      meta: tempMessage.meta,
      // ✅ OTHER FIELDS
      reactions: tempMessage.reactions,
      deleted: tempMessage.deleted,
      deletedBy: tempMessage.deletedBy,
      deliveredAt: tempMessage.deliveredAt,
      readAt: tempMessage.readAt,
      replyTo: _replyingTo, // Add reply if replying
    );

    // Clear reply state
    _cancelReply();

    // Add to messages list optimistically (avoid duplicates)
    setState(() {
      final existingIndex = _findExistingMessageIndex(_messages, message);
      if (existingIndex != -1) {
        // Update existing message
        _messages[existingIndex] = message;
      } else {
        // Add new message
        _messages.add(message);
      }
    });

    // Auto-scroll to bottom after new message is added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  /// Scroll to the bottom of the messages list with animation
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Track scroll position to show/hide scroll-to-bottom button
  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Show button when user has scrolled up more than 200px from bottom
    final scrollThreshold = 200.0;
    final shouldShowButton = (maxScroll - currentScroll) > scrollThreshold;

    if (shouldShowButton != _showScrollToBottomButton) {
      setState(() {
        _showScrollToBottomButton = shouldShowButton;
      });
    }
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
        onManageClub:
            membership != null &&
                (membership.role.toLowerCase() == 'admin' ||
                    membership.role.toLowerCase() == 'owner')
            ? () => _navigateToManageClub(membership)
            : null,
        onExitSelectionMode: _exitSelectionMode,
        onDeleteSelectedMessages: _deleteSelectedMessages,
        onRefreshMessages: () {
          debugPrint('🔄 App bar refresh pressed, fetching new messages...');
          _loadMessages(forceSync: false);
        },
        onMoreOptionSelected: _handleMoreOptionSelected,
      ),
      body: Stack(
        children: [
          // Fixed background that never moves
          Positioned.fill(
            child: Container(
              color: isDarkTheme
                  ? Color(
                      0xFF0D1117,
                    ) // Dark background that complements blue sender bubbles
                  : Color(
                      0xFFE5DDD5,
                    ), // WhatsApp's signature light yellow/cream background
              child: Opacity(
                opacity: 0.15, // Subtle opacity for the pattern
                child: Image.asset(
                  isDarkTheme
                      ? 'assets/images/chat-bg-dark.png'
                      : 'assets/images/chat-bg-light.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),

          // Main content using Column layout
          SafeArea(
            child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Messages List - Takes all available space above input
                  Expanded(
                    child: GestureDetector(
                      onPanStart: (details) {
                        // Track where the pan/scroll gesture starts
                        final startY = details.localPosition.dy;
                        final widgetHeight = context.size?.height ?? 0;
                        final bottom30Percent =
                            widgetHeight * 0.7; // 70% from top = bottom 30%

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
                        // Close attachment menu when user taps on chat area
                        _messageInputKey.currentState?.closeAttachmentMenu();
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

                  // Footer with reply preview and input - positioned above keyboard
                  Transform.translate(
                    offset: Offset(0, -keyboardHeight),
                    child: Container(
                      // No padding - input positioned above keyboard
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

                          // Message Input - Positioned above keyboard (hidden during recording mode)
                          if (!_isInRecordingMode)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: MessageInput(
                                key: _messageInputKey,
                                messageController: _messageController,
                                textFieldFocusNode: _textFieldFocusNode,
                                clubId: widget.club.id,
                                audioRecordingKey: _audioRecordingKey,
                                onSendMessage: _handleNewMessage,
                                upiId: widget.club.upiId,
                                userRole: membership?.role,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom safe area background extension (iOS only) - positioned above keyboard
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardHeight,
            height: MediaQuery.of(context).padding.bottom,
            child: Container(
              color: isDarkTheme ? Color(0xFF1e2428) : Colors.white,
            ),
          ),

          // Circular progress indicator for pull-to-record (overlay)
          // Only show if pulling for audio and not already recording
          if (_isPullingForAudio &&
              !(_audioRecordingKey.currentState?.isRecording ?? false))
            Positioned(
              bottom: 150, // Fixed position above input area
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

          // Floating scroll-to-bottom button
          if (_showScrollToBottomButton)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom +
                        100 // Position above keyboard
                  : 120, // Position above message input when keyboard is hidden
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF2A2A2A)
                    : Colors.white,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                elevation: 6,
                onPressed: _scrollToBottom,
                child: Icon(Icons.keyboard_arrow_down, size: 24),
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
                padding: EdgeInsets.only(
                  left: 4,
                  right: 4,
                  top: 2,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? MediaQuery.of(context).viewInsets.bottom + 10
                      : 2,
                ),
                itemCount: listItems.length,
                itemBuilder: (context, index) {
                  final item = listItems[index];

                  // Check if item is a date header
                  if (item is DateTime) {
                    return ChatHeader.date(date: item);
                  }

                  // Otherwise it's a message wrapper with pre-calculated properties
                  final messageWrapper = item as _MessageWrapper;
                  final message = messageWrapper.message;
                  final showSenderInfo = messageWrapper.showSenderInfo;

                  final isLastFromSender = messageWrapper.isLastFromSender;
                  final isFirstFromSender = messageWrapper.isFirstFromSender;

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
                        isFirstFromSender: isFirstFromSender,
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
                        canDeleteMessages:
                            true, // Any user can delete messages (local cache only)
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

  // Helper method to build list items with date headers and pre-calculated properties
  List<dynamic> _buildListItemsWithDateHeaders(List<ClubMessage> messages) {
    final List<dynamic> items = [];
    DateTime? lastDate;

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
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

      // Pre-calculate expensive properties to avoid indexOf() in itemBuilder
      final previousMessage = i > 0 ? messages[i - 1] : null;
      final nextMessage = i < messages.length - 1 ? messages[i + 1] : null;

      final showSenderInfo =
          previousMessage == null ||
          previousMessage.senderId != message.senderId ||
          message.createdAt.difference(previousMessage.createdAt).inMinutes > 5;

      final isLastFromSender =
          nextMessage == null ||
          nextMessage.senderId != message.senderId ||
          nextMessage.createdAt.difference(message.createdAt).inMinutes > 5;

      final isFirstFromSender =
          previousMessage == null ||
          previousMessage.senderId != message.senderId ||
          !_isSameDate(message.createdAt, previousMessage.createdAt);

      // Create wrapper with pre-calculated properties
      final messageWrapper = _MessageWrapper(
        message: message,
        showSenderInfo: showSenderInfo,
        isLastFromSender: isLastFromSender,
        isFirstFromSender: isFirstFromSender,
      );

      items.add(messageWrapper);
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
        builder: (_) =>
            ManageClubScreen(club: widget.club, membership: membership),
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
