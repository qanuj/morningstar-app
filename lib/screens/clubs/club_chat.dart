import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../../providers/user_provider.dart';
import '../../models/club.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/message_image.dart';
import '../../models/message_document.dart';
import '../../models/message_reaction.dart';
import '../../models/message_reply.dart';
import '../../models/starred_info.dart';
import '../../models/message_audio.dart';
import '../../services/chat_api_service.dart';
import '../../services/message_storage_service.dart';
import '../../services/media_storage_service.dart';
import '../../widgets/club_info_dialog.dart';
import '../../widgets/image_caption_dialog.dart';
import '../../widgets/audio_recording_widget.dart';
import '../../widgets/pinned_messages_section.dart';
import '../../widgets/message_visibility_detector.dart';
import '../../widgets/chat_app_bar.dart';
import '../../widgets/message_bubble_wrapper.dart';
import '../../widgets/message_input.dart';
import '../../widgets/chat_header.dart';

class ClubChatScreen extends StatefulWidget {
  final Club club;

  const ClubChatScreen({super.key, required this.club});

  @override
  ClubChatScreenState createState() => ClubChatScreenState();
}

class ClubChatScreenState extends State<ClubChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ClubMessage> _messages = [];
  bool _isLoading = true;
  bool _isComposing = false;
  String? _error;
  late AnimationController _refreshAnimationController;
  DetailedClubInfo? _detailedClubInfo;
  final FocusNode _textFieldFocusNode = FocusNode();
  MessageReply? _replyingTo;
  ClubMessage? _selectedMessageForReaction;

  // Slide-to-reply state
  double _slideOffset = 0.0;
  bool _isSliding = false;
  String? _slidingMessageId;

  // Paste image detection
  String? _lastTextValue;

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
  bool? _cachedCanShareUPIQR;

  // Map to store pending file uploads by message ID
  final Map<String, List<PlatformFile>> _pendingUploads = {};

  // Highlighted message state
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  // Bottom refresh debounce timer
  Timer? _bottomRefreshTimer;

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
    _startMessagePolling();

    // Add focus listener to trigger UI updates
    _textFieldFocusNode.addListener(() {
      setState(() {});
    });
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

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _messagePollingTimer?.cancel();
    _bottomRefreshTimer?.cancel();
    _refreshAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
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
      _error = 'Unable to load messages. Please check your connection.';
      setState(() => _isLoading = false);

      // Stop refresh animation on error and reset to 0
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
            '🔵 Making POST request to: https://duggy.app/api/conversations/${widget.club.id}/messages/${message.id}/delivered',
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
      // Skip messages sent by current user
      if (message.senderId == currentUserId) continue;

      // Check if message has delivery information for current user
      // This relies on the updated backend API that includes status.delivered
      if (message.status == MessageStatus.delivered ||
          message.deliveredAt != null) {
        if (!_deliveredMessages.contains(message.id)) {
          _deliveredMessages.add(message.id);
          syncedCount++;
        }
      }

      // Also sync read status
      if (message.status == MessageStatus.read || message.readAt != null) {
        if (!_seenMessages.contains(message.id)) {
          _seenMessages.add(message.id);
        }
      }
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
    final newMessages = comparison['new'] as List<ClubMessage>;
    final updatedMessages = comparison['updated'] as List<ClubMessage>;
    final deletedMessageIds = comparison['deleted'] as List<String>;

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
          // Preserve local read/delivered status
          final currentMsg = updatedMessagesList[index];
          updatedMessagesList[index] = updatedMsg.copyWith(
            deliveredAt: currentMsg.deliveredAt,
            readAt: currentMsg.readAt,
          );
          hasChanges = true;
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
      final response = await ChatApiService.getMessages(widget.club.id);

      if (response != null &&
          (response['success'] == true || response['messages'] != null)) {
        final List<dynamic> messageData = response['messages'] ?? [];
        final serverMessages = messageData
            .map((json) => ClubMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        // Compare messages to identify changes
        final comparison = MessageStorageService.compareMessages(
          _messages,
          serverMessages,
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
        _error = response?['message'] ?? 'Failed to load messages';
        setState(() {});
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

  Future<void> _toggleOfflineMode(bool enabled) async {
    await MessageStorageService.setOfflineMode(widget.club.id, enabled);
  }

  Future<void> _downloadAllMedia() async {
    try {
      // Extract media URLs from current messages
      final mediaUrls = <Map<String, dynamic>>[];
      for (final message in _messages) {
        // Images
        for (final picture in message.pictures) {
          mediaUrls.add({
            'url': picture.url,
            'type': 'image',
            'messageId': message.id,
          });
        }

        // Documents
        for (final document in message.documents) {
          mediaUrls.add({
            'url': document.url,
            'type': 'document',
            'messageId': message.id,
            'filename': document.filename,
          });
        }

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
            child: Text('Clear All'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  Future<void> _sendMessage() async {
    if (!_isComposing) return;

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    // Generate temporary message ID
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Create optimistic message (add immediately to list)
    final optimisticMessage = ClubMessage(
      id: tempMessageId,
      clubId: widget.club.id,
      senderId: user.id,
      senderName: user.name,
      senderProfilePicture: user.profilePicture,
      senderRole: 'MEMBER', // Default role for current user
      content: content,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      replyTo: _replyingTo,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
    );

    // Clear input and reply state, add message to list immediately
    _messageController.clear();
    setState(() {
      _isComposing = false;
      _insertMessageInOrder(optimisticMessage);
      _replyingTo = null; // Clear reply after sending
    });
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

  void _handleTextChanged(String value) {
    // Check if the text contains an image URL (simple detection for paste events)
    if (value.trim() != _lastTextValue?.trim()) {
      final newText = value.trim();
      if (_isImageUrl(newText) && newText.isNotEmpty) {
        // Clear the text field and show image paste dialog
        _messageController.clear();
        setState(() {
          _isComposing = false;
        });
        _showImagePasteDialog(newText);
      }
      _lastTextValue = value;
    }
  }

  bool _isImageUrl(String url) {
    if (url.isEmpty) return false;

    // Check if it's a valid URL
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) return false;

      // Check common image extensions
      final path = uri.path.toLowerCase();
      final imageExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp',
        '.svg',
      ];
      return imageExtensions.any((ext) => path.endsWith(ext));
    } catch (e) {
      return false;
    }
  }

  Future<void> _showImagePasteDialog(String imageUrl) async {
    Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (context) => ImageCaptionDialog(
          imageUrl: imageUrl,
          title: 'Send Image',
          onSend: (caption, croppedPath) =>
              _sendImageFromUrl(imageUrl, caption),
        ),
      ),
    );
  }

  Future<void> _sendImageFromUrl(String imageUrl, String caption) async {
    try {
      // Download the image first
      final imageBytes = await ChatApiService.fetchImageFromUrl(imageUrl);
      if (imageBytes == null) {
        throw Exception('Failed to download image from URL');
      }

      // Create a temporary file
      final tempDir = await getApplicationDocumentsDirectory();
      final fileName = imageUrl
          .split('/')
          .last
          .split('?')
          .first; // Remove query params
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      // Create PlatformFile for upload
      final platformFile = PlatformFile(
        name: fileName,
        size: imageBytes.length,
        path: tempFile.path,
        bytes: Uint8List.fromList(imageBytes),
      );

      // Use existing upload function
      final uploadedUrl = await _uploadFile(platformFile);
      if (uploadedUrl != null && caption.isNotEmpty) {
        // Send a text message with caption
        _messageController.text = caption;
        setState(() {
          _isComposing = true;
        });
        await _sendMessage();
      }

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    } catch (e) {
      // Failed to process image
    }
  }

  Future<void> _sendAudioMessage(String audioPath) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    if (user == null) {
      debugPrint('❌ Cannot send audio message - user not logged in');
      return;
    }

    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Create temporary audio file info
    final audioFile = File(audioPath);
    final fileName = audioFile.path.split('/').last;
    final fileSize = await audioFile.length();

    // Create optimistic message with audio structure
    final optimisticMessage = ClubMessage(
      id: tempMessageId,
      clubId: widget.club.id,
      senderId: user.id,
      senderName: user.name,
      senderProfilePicture: user.profilePicture,
      senderRole: 'MEMBER',
      content: '',
      messageType: 'audio',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      // Add audio structure for the bubble
      audio: MessageAudio(
        url: audioPath, // Use local path initially
        filename: fileName,
        duration: 0, // Will be updated when upload completes
        size: fileSize,
      ),
    );

    // Add message to list immediately
    setState(() {
      _insertMessageInOrder(optimisticMessage);
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      // Create fake PlatformFile for upload function
      final platformFile = PlatformFile(
        name: fileName,
        size: fileSize,
        path: audioPath,
      );

      // Upload audio file first
      debugPrint('🔄 Starting audio file upload...');
      final uploadedUrl = await _uploadFile(platformFile);
      debugPrint('📁 Upload result: $uploadedUrl');
      if (uploadedUrl == null) {
        throw Exception('Failed to upload audio file');
      }

      // Create message with uploaded audio
      final messageData = {
        'senderId': user.id,
        'content': {
          'type': 'audio',
          'url': uploadedUrl,
          'duration': 0,
          'size': _formatFileSize(fileSize),
        },
      };

      debugPrint('📤 Sending message data: $messageData');
      final response = await ChatApiService.sendMessageWithDocuments(
        widget.club.id,
        messageData,
      );

      debugPrint('📥 API Response: $response');
      debugPrint('✅ Audio message sent successfully');
      // The response is the message object directly, not wrapped in success
      final newMessage = ClubMessage.fromJson(response!);
      await MessageStorageService.addMessage(widget.club.id, newMessage);

      // Update UI
      setState(() {
        // Remove temp message and add real message in correct order
        _messages.removeWhere((m) => m.id == tempMessageId);
        _insertMessageInOrder(newMessage);
      });

      // Clean up local file
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    } catch (e) {
      debugPrint('❌ Error sending audio message: $e');

      // Mark optimistic message as failed
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.failed,
            errorMessage: 'Failed to send audio message',
          );
        }
      });

      // Error handled by optimistic message state
    }
  }

  void _handleSlideGesture(
    DragUpdateDetails details,
    ClubMessage message,
    bool isOwn,
  ) {
    // Only allow slide-to-reply for non-own messages (swipe right) and own messages (swipe left)
    final delta = details.delta.dx;
    final threshold = 30.0; // Minimum slide distance to trigger reply

    setState(() {
      if (isOwn && delta < 0) {
        // Own messages: slide left to reply
        _slideOffset = delta.abs().clamp(0.0, 80.0);
        _isSliding = _slideOffset > threshold;
        _slidingMessageId = message.id;
      } else if (!isOwn && delta > 0) {
        // Other messages: slide right to reply
        _slideOffset = delta.clamp(0.0, 80.0);
        _isSliding = _slideOffset > threshold;
        _slidingMessageId = message.id;
      }
    });
  }

  void _handleSlideEnd(
    DragEndDetails details,
    ClubMessage message,
    bool isOwn,
  ) {
    if (_isSliding && _slidingMessageId == message.id && _slideOffset > 50.0) {
      // Trigger reply if user slid far enough
      HapticFeedback.selectionClick();
      _setReply(message);
    }

    // Reset slide state
    setState(() {
      _slideOffset = 0.0;
      _isSliding = false;
      _slidingMessageId = null;
    });
  }

  void _setReply(ClubMessage message) {
    setState(() {
      _replyingTo = MessageReply(
        messageId: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        content: message.content,
        messageType: message.messageType,
      );
    });
    _textFieldFocusNode.requestFocus();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.grey[100],
      resizeToAvoidBottomInset: true,
      appBar: ChatAppBar(
        club: widget.club,
        isSelectionMode: _isSelectionMode,
        selectedMessageIds: _selectedMessageIds,
        refreshAnimationController: _refreshAnimationController,
        onBackPressed: () => Navigator.of(context).pop(),
        onShowClubInfo: _showClubInfoDialog,
        onExitSelectionMode: _exitSelectionMode,
        onDeleteSelectedMessages: _deleteSelectedMessages,
        onRefreshMessages: () => _loadMessages(),
        onShowMoreOptions: _showMoreOptions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List - Takes all available space
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
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

            // Reply preview (if replying to a message)
            if (_replyingTo != null) _buildReplyPreview(),

            // Message Input - Sticks to bottom footer
            MessageInput(
              messageController: _messageController,
              textFieldFocusNode: _textFieldFocusNode,
              isComposing: _isComposing,
              audioRecordingKey: _audioRecordingKey,
              onSendMessage: _sendMessage,
              onShowUploadOptions: _showUploadOptions,
              onCapturePhoto: _capturePhotoWithCamera,
              onSendAudioMessage: _sendAudioMessage,
              onTextChanged: _handleTextChanged,
              onComposingChanged: (isComposing) {
                setState(() {
                  _isComposing = isComposing;
                });
              },
              onRecordingStateChanged: () {
                setState(() {
                  // This will trigger a rebuild with the new recording state
                });
              },
            ),
          ],
        ),
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
                        // Message options now handled by bubbles
                        // Error handling now in bubbles
                        onMessageUpdated: _handleMessageUpdated,
                        onMessageFailed: _handleMessageFailed,
                        isCurrentlyPinned: _isCurrentlyPinned,
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

  // Handle scroll notifications for bottom refresh detection
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      final scrollPosition = notification.metrics.pixels;
      final maxScroll = notification.metrics.maxScrollExtent;

      // Check if user scrolled to the very bottom (with a small threshold)
      if (scrollPosition >= maxScroll - 50) {
        debugPrint('🔄 Bottom pull detected, refreshing messages...');
        _handleBottomRefresh();
      }
    }

    return false; // Allow other listeners to receive the notification
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

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // First row - Photos, Document, Location, Audio
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGridOption(
                            icon: Icons.photo_library,
                            iconColor: Color(0xFF2196F3),
                            title: 'Photos',
                            onTap: () {
                              Navigator.pop(context);
                              _pickImages();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.description,
                            iconColor: Color(0xFF2196F3),
                            title: 'Document',
                            onTap: () {
                              Navigator.pop(context);
                              _pickDocuments();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.location_on,
                            iconColor: Color(0xFF00C853),
                            title: 'Location',
                            onTap: () {
                              Navigator.pop(context);
                              // Location sharing coming soon
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: 30),

                      // Second row - Contact, Catalog, Quick replies, Poll
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGridOption(
                            icon: Icons.person,
                            iconColor: Colors.grey[700]!,
                            title: 'Contact',
                            onTap: () {
                              Navigator.pop(context);
                              // Contact sharing coming soon
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.storefront,
                            iconColor: Colors.black,
                            title: 'Catalog',
                            onTap: () {
                              Navigator.pop(context);
                              // Catalog coming soon
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.bolt,
                            iconColor: Color(0xFFFFB300),
                            title: 'Quick replies',
                            onTap: () {
                              Navigator.pop(context);
                              // Quick replies coming soon
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.poll,
                            iconColor: Color(0xFFFFB300),
                            title: 'Poll',
                            onTap: () {
                              Navigator.pop(context);
                              // Poll creation coming soon
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: 30),

                      // Third row - Event, Share UPI QR (conditional)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGridOption(
                            icon: Icons.event,
                            iconColor: Color(0xFFE53935),
                            title: 'Event',
                            onTap: () {
                              Navigator.pop(context);
                              // Event creation coming soon
                            },
                          ),
                          if (_canShareUPIQR())
                            _buildGridOption(
                              icon: Icons.qr_code_2,
                              iconColor: Color(0xFF2196F3),
                              title: 'Share UPI QR',
                              onTap: () {
                                Navigator.pop(context);
                                _shareClubUPIQR();
                              },
                            ),
                          // Empty spacers to maintain alignment
                          if (!_canShareUPIQR()) ...[
                            SizedBox(width: 70),
                            SizedBox(width: 70),
                          ],
                          SizedBox(
                            width: 70,
                          ), // Always add one spacer for balance
                        ],
                      ),

                      SizedBox(
                        height: 50,
                      ), // Extra space at bottom for future additions
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  bool _canShareUPIQR() {
    // Use cached value if available
    return _cachedCanShareUPIQR ?? false;
  }

  // Async method to check if user can share UPI QR
  Future<bool> _checkCanShareUPIQR() async {
    // First check if UPI ID is configured
    if (widget.club.upiId == null || widget.club.upiId!.isEmpty) {
      return false;
    }

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return false;

    // Check if user has admin privileges (OWNER, ADMIN, or CAPTAIN can share payment QR)
    try {
      return await userProvider.hasRoleInClub(widget.club.id, [
        'OWNER',
        'ADMIN',
        'CAPTAIN',
      ]);
    } catch (e) {
      print('Error checking UPI QR share permissions: $e');
      // Fallback: only allow if user seems to be admin based on messages
      final userMessages = _messages
          .where((m) => m.senderId == user.id)
          .toList();
      if (userMessages.isNotEmpty) {
        final userRole = userMessages.first.senderRole ?? 'MEMBER';
        return ['OWNER', 'ADMIN', 'CAPTAIN'].contains(userRole);
      }
      return false;
    }
  }

  void _shareClubUPIQR() {
    // For now, show a placeholder message
    // In the future, this would fetch the club's UPI QR code from the server
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share Club UPI QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code, size: 64, color: Color(0xFF9C27B0)),
            SizedBox(height: 16),
            Text(
              'Club UPI QR Code sharing coming soon!',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Members will be able to scan and pay directly to the club.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF003f9b)),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        _startImageUpload(result.files);
      }
    } catch (e) {
      // Error picking images
    }
  }

  Future<void> _capturePhotoWithCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        // Convert XFile to PlatformFile for compatibility with existing flow
        final File imageFile = File(image.path);
        final List<int> imageBytes = await imageFile.readAsBytes();

        final PlatformFile platformFile = PlatformFile(
          name: image.name.isNotEmpty
              ? image.name
              : 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
          path: image.path,
          size: imageBytes.length,
          bytes: null, // Keep as null since we have path
        );

        // Use the existing image upload flow which includes caption dialog
        _startImageUpload([platformFile]);
      }
    } catch (e) {
      // Error capturing photo
    }
  }

  Future<void> _pickDocuments() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        _uploadDocuments(result.files);
      }
    } catch (e) {
      // Error picking documents
    }
  }

  Future<void> _startImageUpload(List<PlatformFile> files) async {
    // Show caption dialog for single image, immediate upload for multiple
    if (files.length == 1) {
      _showSingleImageCaptionDialog(files.first);
    } else {
      _uploadImagesWithProgress(files, {});
    }
  }

  void _showSingleImageCaptionDialog(PlatformFile file) {
    Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (context) => ImageCaptionDialog(
          imageFile: file,
          title: 'Send Image',
          onSend: (caption, croppedPath) {
            // If image was cropped, use the cropped version
            if (croppedPath != null) {
              final croppedFile = PlatformFile(
                name: file.name,
                size: File(croppedPath).lengthSync(),
                path: croppedPath,
              );
              _uploadImagesWithProgress(
                [croppedFile],
                {croppedFile.name: caption},
              );
            } else {
              _uploadImagesWithProgress([file], {file.name: caption});
            }
          },
        ),
      ),
    );
  }

  Future<void> _uploadImagesWithProgress(
    List<PlatformFile> files,
    Map<String, String> captions,
  ) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    // Generate temporary message ID
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Get the caption (message body) - use first non-empty caption or empty string
    String messageBody = '';
    for (String caption in captions.values) {
      if (caption.isNotEmpty) {
        messageBody = caption;
        break;
      }
    }

    // Create optimistic message with image previews
    final List<MessageImage> tempImages = files.map((file) {
      return MessageImage(
        url: file.path ?? '', // Use local path for preview
        caption: null, // Caption becomes the message body
      );
    }).toList();

    // Create optimistic message
    final optimisticMessage = ClubMessage(
      id: tempMessageId,
      clubId: widget.club.id,
      senderId: user.id,
      senderName: user.name,
      senderProfilePicture: user.profilePicture,
      senderRole: 'MEMBER',
      content: messageBody,
      pictures: tempImages,
      messageType: files.length == 1 ? 'image' : 'text_with_images',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
    );

    // Add message to list immediately with previews
    setState(() {
      _insertMessageInOrder(optimisticMessage);
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      // Upload images one by one with progress tracking
      List<MessageImage> uploadedImages = [];
      for (int i = 0; i < files.length; i++) {
        final file = files[i];

        // Update message with current upload progress
        setState(() {
          final messageIndex = _messages.indexWhere(
            (m) => m.id == tempMessageId,
          );
          if (messageIndex != -1) {
            // Update message to show which image is currently uploading
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.sending,
              errorMessage: 'Uploading image ${i + 1}/${files.length}...',
            );
          }
        });

        final uploadedUrl = await _uploadFile(file);
        if (uploadedUrl != null) {
          uploadedImages.add(
            MessageImage(
              url: uploadedUrl,
              caption: null, // Caption is now the message body
            ),
          );
        } else {
          // If any upload fails, mark message as failed immediately
          setState(() {
            final messageIndex = _messages.indexWhere(
              (m) => m.id == tempMessageId,
            );
            if (messageIndex != -1) {
              _messages[messageIndex] = _messages[messageIndex].copyWith(
                status: MessageStatus.failed,
                errorMessage: 'Failed to upload image ${i + 1}/${files.length}',
              );
            }
          });
          return; // Stop upload process on first failure
        }
      }

      if (uploadedImages.isNotEmpty) {
        // Send the message with uploaded images
        await _sendMessageWithUploadedMedia(
          tempMessageId,
          messageBody,
          uploadedImages,
          [], // Empty videos array for now
        );
      } else {
        // Mark as failed if no images uploaded
        setState(() {
          final messageIndex = _messages.indexWhere(
            (m) => m.id == tempMessageId,
          );
          if (messageIndex != -1) {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.failed,
              errorMessage: 'Failed to upload images',
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error uploading images: $e');
      // Mark as failed
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.failed,
            errorMessage: 'Upload failed: $e',
          );
        }
      });
    }
  }

  Future<void> _sendMessageWithUploadedMedia(
    String tempMessageId,
    String messageBody,
    List<MessageImage> uploadedImages,
    List<String> uploadedVideos,
  ) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    try {
      // Updated schema now supports images and videos arrays in text messages
      final Map<String, dynamic> contentMap = {
        'type': 'text',
        'body': messageBody.trim().isEmpty ? ' ' : messageBody,
      };

      // Add images array if there are images
      if (uploadedImages.isNotEmpty) {
        contentMap['images'] = uploadedImages.map((img) => img.url).toList();
      }

      // Add videos array if there are videos
      if (uploadedVideos.isNotEmpty) {
        contentMap['videos'] = uploadedVideos;
      }

      final requestData = {'senderId': user.id, 'content': contentMap};

      final response = await ChatApiService.sendMessageWithMedia(
        widget.club.id,
        requestData,
      );

      debugPrint('✅ Message with media sent successfully');
      debugPrint('📡 Server response: $response');

      // Remove temporary message and reload all messages to get the server version
      setState(() {
        _messages.removeWhere((m) => m.id == tempMessageId);
      });

      // Add new message to local storage
      final newMessage = ClubMessage.fromJson(response!);
      await MessageStorageService.addMessage(widget.club.id, newMessage);

      // Update UI
      setState(() {
        // Remove temp message and add real message in correct order
        _messages.removeWhere((m) => m.id == tempMessageId);
        _insertMessageInOrder(newMessage);
      });
    } catch (e) {
      debugPrint('❌ Error sending message with media: $e');
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.failed,
            errorMessage: 'Failed to send message with media',
          );
        }
      });
    }
  }

  Future<void> _sendMessageWithDocuments(
    List<MessageDocument> uploadedDocs,
  ) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    try {
      final response = await ChatApiService.sendMessageWithDocuments(
        widget.club.id,
        {
          'senderId': user.id,
          'content': {
            'type': 'document',
            'url': uploadedDocs.first.url,
            'name': uploadedDocs.first.filename,
            'size': uploadedDocs.first.size,
          },
        },
      );

      final newMessage = ClubMessage.fromJson(response!);

      setState(() {
        _insertMessageInOrder(newMessage);
      });

      debugPrint('✅ Message with documents sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending message with documents: $e');
      // Error sending documents
    }
  }

  Future<void> _uploadDocuments(List<PlatformFile> files) async {
    try {
      List<MessageDocument> uploadedDocs = [];

      for (PlatformFile file in files) {
        final uploadedUrl = await _uploadFile(file);
        if (uploadedUrl != null) {
          final extension = file.extension?.toLowerCase() ?? '';
          final fileSize = _formatFileSize(file.size);
          uploadedDocs.add(
            MessageDocument(
              url: uploadedUrl,
              filename: file.name,
              type: extension,
              size: fileSize,
            ),
          );
        }
      }

      if (uploadedDocs.isNotEmpty) {
        await _sendMessageWithDocuments(uploadedDocs);
      }
    } catch (e) {
      // Error uploading documents
    }
  }

  Future<String?> _uploadFile(PlatformFile file) async {
    return await ChatApiService.uploadFile(file);
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1e2428)
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
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

  Timer? _messagePollingTimer;
  int _currentPollingInterval = 30; // Start with 30 seconds
  bool _isMarkingDelivered =
      false; // Lock to prevent concurrent delivery marking
  final Set<String> _processingDelivery =
      <String>{}; // Track messages currently being marked as delivered

  // Helper method to check if a message belongs to the current user
  bool _isOwnMessage(ClubMessage message) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.user;
    return currentUser != null && message.senderId == currentUser.id;
  }

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
      print('Error checking pin permissions: $e');
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
    final canShareUPI = await _checkCanShareUPIQR();

    if (mounted) {
      setState(() {
        _cachedCanPinMessages = canPin;
        _cachedCanShareUPIQR = canShareUPI;
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

  // Start adaptive polling for new messages
  void _startMessagePolling() {
    _messagePollingTimer?.cancel();
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    _messagePollingTimer?.cancel();

    _messagePollingTimer = Timer(
      Duration(seconds: _currentPollingInterval),
      () async {
        if (mounted && !_isLoading) {
          try {
            // Only check for new messages if we need sync
            final needsSync = await MessageStorageService.needsSync(
              widget.club.id,
            );
            if (needsSync) {
              final previousMessageCount = _messages.length;
              await _syncMessagesFromServer(forceSync: false);

              // Check if new messages were received
              final newMessageCount = _messages.length;
              if (newMessageCount > previousMessageCount) {
                // Found new messages - decrease interval (more frequent polling)
                _currentPollingInterval = 5;
                debugPrint(
                  '📨 New messages found, increasing polling frequency to ${_currentPollingInterval}s',
                );
              } else {
                // No new messages - increase interval (less frequent polling)
                _adjustPollingInterval();
              }
            } else {
              // No sync needed - increase interval
              _adjustPollingInterval();
            }

            // Schedule next poll
            if (mounted) {
              _scheduleNextPoll();
            }
          } catch (e) {
            // Silently handle errors to avoid disrupting user experience
            debugPrint('Message polling failed: $e');
            // Schedule next poll even on error
            if (mounted) {
              _scheduleNextPoll();
            }
          }
        }
      },
    );
  }

  void _adjustPollingInterval() {
    // Adaptive intervals: 5s -> 10s -> 15s -> 20s -> 25s -> 30s -> 25s -> 20s -> 15s -> 10s -> 5s (cycle)
    const intervals = [5, 10, 15, 20, 25, 30, 25, 20, 15, 10];
    final currentIndex = intervals.indexOf(_currentPollingInterval);

    if (currentIndex == -1) {
      // If current interval is not in list (e.g., first run), start from beginning
      _currentPollingInterval = intervals.first;
    } else {
      // Move to next interval in sequence
      _currentPollingInterval =
          intervals[(currentIndex + 1) % intervals.length];
    }

    debugPrint(
      '📡 No new messages, adjusting polling interval to ${_currentPollingInterval}s',
    );
  }

  void _scrollToMessage(String messageId) {
    // Sort messages by creation time to match the ListView order
    final allMessages = List<ClubMessage>.from(_messages);
    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final sortedIndex = allMessages.indexWhere((m) => m.id == messageId);
    if (sortedIndex == -1) return;

    // Scroll to the message
    final itemHeight = 100.0; // Approximate height per message
    final targetOffset = sortedIndex * itemHeight;

    _scrollController.animateTo(
      targetOffset,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
}
