import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../../providers/user_provider.dart';
import '../../models/club.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/message_image.dart';
import '../../models/message_document.dart';
import '../../models/link_metadata.dart';
import '../../models/message_reaction.dart';
import '../../models/message_reply.dart';
import '../../models/starred_info.dart';
import '../../models/message_audio.dart';
import '../../services/api_service.dart';
import '../../services/message_storage_service.dart';
// import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // Package not available
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/club_info_dialog.dart';
import '../../widgets/audio_player_widget.dart';
import '../../widgets/message_bubbles/message_bubble_factory.dart';
import '../../widgets/image_caption_dialog.dart';
import '../../widgets/image_gallery_screen.dart';
import '../../widgets/audio_recording_widget.dart';

class ClubChatScreen extends StatefulWidget {
  final Club club;

  const ClubChatScreen({Key? key, required this.club}) : super(key: key);

  @override
  _ClubChatScreenState createState() => _ClubChatScreenState();
}

class _ClubChatScreenState extends State<ClubChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ClubMessage> _messages = [];
  bool _isLoading = true;
  bool _isComposing = false;
  String? _error;
  DetailedClubInfo? _detailedClubInfo;
  final FocusNode _textFieldFocusNode = FocusNode();
  MessageReply? _replyingTo;
  bool _showEmojiReactionPicker = false;
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
  Set<String> _selectedMessageIds = <String>{};

  // Message status tracking
  Set<String> _deliveredMessages = <String>{};
  Set<String> _seenMessages = <String>{};

  // Highlighted message state
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    // Clear cached messages to handle model migration (pin/starred structure changes)
    MessageStorageService.clearCachedMessages(widget.club.id);
    // Remove the listener since we handle it in onChanged now
    _loadMessages();
    _startPinnedRefreshTimer();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _pinnedRefreshTimer?.cancel();
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

      // Load from local storage first (unless forced sync)
      if (!forceSync) {
        final cachedMessages = await MessageStorageService.loadMessages(
          widget.club.id,
        );
        if (cachedMessages.isNotEmpty) {
          setState(() {
            _messages = cachedMessages;
            _isLoading = false;
          });

          // Sort by creation time (oldest first for chat display)
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          // Start pinned refresh timer
          _startPinnedRefreshTimer();

          // Check if we need to sync with server
          final needsSync = await MessageStorageService.needsSync(
            widget.club.id,
          );
          if (needsSync) {
            print('📡 Messages need sync, syncing in background...');
            _syncMessagesFromServer();
          } else {
            print('✅ Messages are up to date');
          }
          return;
        }
      }

      // If no cached messages or forced sync, load from server
      await _syncMessagesFromServer();
    } catch (e) {
      print('Error loading messages: $e');
      _error = 'Unable to load messages. Please check your connection.';
      setState(() => _isLoading = false);
    }
  }

  // Mark messages as delivered when they are received
  Future<void> _markReceivedMessagesAsDelivered() async {
    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.user?.id;
    if (currentUserId == null) return;

    for (final message in _messages) {
      // Only mark messages from other users as delivered
      if (message.senderId != currentUserId &&
          !_deliveredMessages.contains(message.id) &&
          message.status != MessageStatus.delivered &&
          message.status != MessageStatus.read) {
        try {
          final response = await ApiService.post(
            '/conversations/${widget.club.id}/messages/${message.id}/delivered',
            {},
          );

          if (response['success'] == true) {
            _deliveredMessages.add(message.id);
            // Update message status locally
            _updateMessageStatus(message.id, MessageStatus.delivered);
          }
        } catch (e) {
          print('❌ Error marking message ${message.id} as delivered: $e');
        }
      }
    }
  }

  // Mark messages as seen when they come into view
  Future<void> _markMessageAsSeen(String messageId) async {
    if (_seenMessages.contains(messageId)) return;

    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.user?.id;
    if (currentUserId == null) return;

    // Find the message
    final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) return;

    final message = _messages[messageIndex];

    // Only mark messages from other users as seen
    if (message.senderId == currentUserId) return;

    try {
      final response = await ApiService.post(
        '/conversations/${widget.club.id}/messages/${message.id}/read',
        {},
      );

      if (response['success'] == true) {
        _seenMessages.add(messageId);
        // Update message status locally
        _updateMessageStatus(messageId, MessageStatus.read);
      }
    } catch (e) {
      print('❌ Error marking message $messageId as seen: $e');
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

  // Note: Old scroll-based detection replaced with widget-based visibility detection

  Future<void> _syncMessagesFromServer() async {
    try {
      print('🔄 Syncing messages from server...');
      final response = await ApiService.get(
        '/conversations/${widget.club.id}/messages',
      );

      if (response['success'] == true || response['messages'] != null) {
        final List<dynamic> messageData = response['messages'] ?? [];
        final serverMessages = messageData
            .map((json) => ClubMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        final serverPinnedMessages = serverMessages
            .where((m) => _isCurrentlyPinned(m))
            .toList();

        // Merge with local read/delivered status
        final cachedMessages = await MessageStorageService.loadMessages(
          widget.club.id,
        );
        final mergedMessages = _mergeMessagesWithLocalData(
          serverMessages,
          cachedMessages,
        );

        // Save merged messages to local storage
        await MessageStorageService.saveMessages(
          widget.club.id,
          mergedMessages,
        );

        setState(() {
          _messages = mergedMessages;
          _isLoading = false;
        });

        // Parse detailed club info from API response
        if (response['club'] != null) {
          _detailedClubInfo = DetailedClubInfo.fromJson(
            response['club'] as Map<String, dynamic>,
          );
        }

        // Sort by creation time (oldest first for chat display)
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // Restart the pinned refresh timer with new messages
        _startPinnedRefreshTimer();

        // Mark messages as delivered/read using existing methods
        _markReceivedMessagesAsDelivered();
      } else {
        _error = response['message'] ?? 'Failed to load messages';
        setState(() {});
      }
    } catch (e) {
      print('Error syncing messages from server: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to sync messages: $e';
        });
      }
    }
  }

  List<ClubMessage> _mergeMessagesWithLocalData(
    List<ClubMessage> serverMessages,
    List<ClubMessage> cachedMessages,
  ) {
    final Map<String, ClubMessage> cachedMap = {
      for (var msg in cachedMessages) msg.id: msg,
    };

    return serverMessages.map((serverMessage) {
      final cached = cachedMap[serverMessage.id];
      if (cached != null) {
        // Preserve ONLY local read/delivered status
        // Server pinned status is authoritative and should NOT be overridden
        return serverMessage.copyWith(
          deliveredAt: cached.deliveredAt,
          readAt: cached.readAt,
          // DO NOT preserve cached pinned status - server is authoritative
        );
      }
      return serverMessage;
    }).toList();
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Storage Info'),
              onTap: () {
                Navigator.pop(context);
                _showStorageInfo();
              },
            ),
            ListTile(
              leading: Icon(Icons.clear_all),
              title: Text('Clear Local Messages'),
              onTap: () {
                Navigator.pop(context);
                _clearLocalMessages();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStorageInfo() async {
    final storageInfo = await MessageStorageService.getStorageInfo(
      widget.club.id,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message Storage Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Messages: ${storageInfo['messageCount']}'),
            Text('Last Sync: ${storageInfo['lastSync'] ?? 'Never'}'),
            Text('Needs Sync: ${storageInfo['needsSync']}'),
            if (storageInfo['oldestMessage'] != null)
              Text('Oldest: ${storageInfo['oldestMessage']}'),
            if (storageInfo['newestMessage'] != null)
              Text('Newest: ${storageInfo['newestMessage']}'),
          ],
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

  Future<void> _clearLocalMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Local Messages?'),
        content: Text(
          'This will clear all locally stored messages and reload from the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MessageStorageService.clearMessages(widget.club.id);
      await _loadMessages(forceSync: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Local messages cleared and reloaded')),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (!_isComposing) return;

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) {
      print('❌ User is null, cannot send message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generate temporary message ID
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Check if message is emoji-only
    final emojiOnlyPattern = RegExp(
      r'^(\s*[\p{Emoji}\p{Emoji_Modifier}\p{Emoji_Component}\p{Emoji_Modifier_Base}\p{Emoji_Presentation}\u200d]*\s*)+$',
      unicode: true,
    );
    final isEmojiOnly =
        emojiOnlyPattern.hasMatch(content) &&
        content.trim().length <= 12; // Max 4 emojis

    // Detect links and fetch metadata
    List<LinkMetadata> linkMeta = [];
    final urlPattern = RegExp(r'https?://[^\s]+');
    final urls = urlPattern
        .allMatches(content)
        .map((match) => match.group(0)!)
        .toList();

    // Determine message type
    String messageType = 'text';
    if (isEmojiOnly) {
      messageType = 'emoji';
    } else if (urls.isNotEmpty) {
      messageType = 'link';
    }

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
      _messages.add(optimisticMessage);
      _replyingTo = null; // Clear reply after sending
    });

    // Scroll to bottom to show new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    HapticFeedback.lightImpact();

    // Fetch link metadata if URLs found
    if (urls.isNotEmpty) {
      for (String url in urls) {
        final metadata = await _fetchLinkMetadata(url);
        if (metadata != null) {
          linkMeta.add(metadata);
        }
      }
    }

    try {
      // print(
      //   '🔵 Sending message to club ${widget.club.id} from user ${user.id}',
      // );
      print('🔵 Message content: $content');

      final Map<String, dynamic> contentMap = {
        'type': messageType,
        'body': content,
      };

      if (linkMeta.isNotEmpty) {
        contentMap['meta'] = linkMeta.map((meta) => meta.toJson()).toList();
      }

      final requestData = {
        'senderId': user.id,
        'content': contentMap,
        if (_replyingTo != null) 'replyTo': _replyingTo!.toJson(),
      };

      //print('🔵 Request data: $requestData');

      final response = await ApiService.post(
        '/conversations/${widget.club.id}/messages',
        requestData,
      );

      //print('🔵 Full API Response: $response');

      // Check different possible response structures
      bool isSuccess = false;
      String? messageId;

      if (response.containsKey('messageId') && response['messageId'] != null) {
        isSuccess = true;
        messageId = response['messageId'];
      } else if (response.containsKey('success') &&
          response['success'] == true) {
        isSuccess = true;
        messageId = response['messageId'];
      } else if (response.containsKey('id')) {
        // Sometimes the response might use 'id' instead of 'messageId'
        isSuccess = true;
        messageId = response['id'];
      } else if (response.containsKey('data') && response['data'] != null) {
        // Check if response has data wrapper
        final data = response['data'];
        if (data is Map && (data['messageId'] != null || data['id'] != null)) {
          isSuccess = true;
          messageId = data['messageId'] ?? data['id'];
        }
      } else {
        // If we get here without an error being thrown, assume success
        isSuccess = true;
        messageId = DateTime.now().millisecondsSinceEpoch.toString();
      }

      print('🔵 Is success: $isSuccess, Message ID: $messageId');

      if (isSuccess) {
        // Update the optimistic message to sent status with real ID and metadata
        setState(() {
          final messageIndex = _messages.indexWhere(
            (m) => m.id == tempMessageId,
          );
          if (messageIndex != -1) {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.sent,
              linkMeta: linkMeta,
            );
          }
        });

        print('✅ Message sent successfully: $messageId');
      } else {
        // Mark message as failed
        setState(() {
          final messageIndex = _messages.indexWhere(
            (m) => m.id == tempMessageId,
          );
          if (messageIndex != -1) {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.failed,
              errorMessage: 'Server response unclear',
            );
          }
        });

        print('❌ Message send failed - no success indicator in response');
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      print('❌ Error type: ${e.runtimeType}');

      String errorMessage = 'Unable to send message';
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      // Mark message as failed with error message
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.failed,
            errorMessage: errorMessage,
          );
        }
      });
    }
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
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        _showErrorSnackBar('Failed to download image');
        return;
      }

      // Create a temporary file
      final tempDir = await getApplicationDocumentsDirectory();
      final fileName = imageUrl
          .split('/')
          .last
          .split('?')
          .first; // Remove query params
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Create PlatformFile for upload
      final platformFile = PlatformFile(
        name: fileName,
        size: response.bodyBytes.length,
        path: tempFile.path,
        bytes: response.bodyBytes,
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
      _showErrorSnackBar('Failed to process image: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
      content: 'Audio message',
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
      _messages.add(optimisticMessage);
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
          'duration': 0, // TODO: Calculate actual audio duration
          'size': _formatFileSize(fileSize),
        },
      };

      debugPrint('📤 Sending message data: $messageData');
      final response = await ApiService.post(
        '/conversations/${widget.club.id}/messages',
        messageData,
      );

      debugPrint('📥 API Response: $response');
      if (response != null && response is Map<String, dynamic>) {
        debugPrint('✅ Audio message sent successfully');
        // The response is the message object directly, not wrapped in success
        final newMessage = ClubMessage.fromJson(response);
        await MessageStorageService.addMessage(widget.club.id, newMessage);

        // Update UI
        setState(() {
          // Remove temp message and add real message
          _messages.removeWhere((m) => m.id == tempMessageId);
          _messages.add(newMessage);
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });

        // Clean up local file
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } else {
        throw Exception('Unexpected response format');
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

      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send audio message'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      final response = await ApiService.delete(
        '/conversations/${widget.club.id}/messages/delete',
        messageIdsToDelete,
      );

      if (mounted) {
        // Use response message or fall back to default
        final message =
            response['message'] ??
            '${messageIdsToDelete.length} message(s) deleted';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Color(0xFF003f9b)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _showReactionPicker(ClubMessage message) {
    setState(() {
      _selectedMessageForReaction = message;
      _showEmojiReactionPicker = true;
    });
  }

  void _hideReactionPicker() {
    setState(() {
      _showEmojiReactionPicker = false;
      _selectedMessageForReaction = null;
    });
  }

  void _addReaction(String emoji) async {
    if (_selectedMessageForReaction == null) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    final messageId = _selectedMessageForReaction!.id;
    final reaction = MessageReaction(
      emoji: emoji,
      userId: user.id,
      userName: user.name,
      createdAt: DateTime.now(),
    );

    try {
      await ApiService.post(
        '/conversations/${widget.club.id}/messages/$messageId/reactions',
        reaction.toJson(),
      );

      // Update local message with the reaction
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == messageId);
        if (messageIndex != -1) {
          final message = _messages[messageIndex];
          final updatedReactions = List<MessageReaction>.from(
            message.reactions,
          );

          // Remove any existing reaction from this user with the same emoji
          updatedReactions.removeWhere(
            (r) => r.userId == user.id && r.emoji == emoji,
          );

          // Add the new reaction
          updatedReactions.add(reaction);

          _messages[messageIndex] = message.copyWith(
            reactions: updatedReactions,
          );
        }
      });

      _hideReactionPicker();
    } catch (e) {
      print('Error adding reaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add reaction')));
      }
    }
  }

  void _removeReaction(ClubMessage message, MessageReaction reaction) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null || reaction.userId != user.id) return;

    try {
      await ApiService.delete(
        '/conversations/${widget.club.id}/messages/${message.id}/reactions/${reaction.emoji}',
      );

      // Update local message by removing the reaction
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == message.id);
        if (messageIndex != -1) {
          final updatedReactions = message.reactions
              .where((r) => !(r.userId == user.id && r.emoji == reaction.emoji))
              .toList();

          _messages[messageIndex] = message.copyWith(
            reactions: updatedReactions,
          );
        }
      });
    } catch (e) {
      print('Error removing reaction: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.grey[100],
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Color(0xFF003f9b),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSelectionMode
            ? Text(
                '${_selectedMessageIds.length} message${_selectedMessageIds.length == 1 ? '' : 's'} selected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Row(
                children: [
                  // Club Logo
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child:
                          widget.club.logo != null &&
                              widget.club.logo!.isNotEmpty
                          ? Image.network(
                              widget.club.logo!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultClubLogo();
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildDefaultClubLogo();
                                  },
                            )
                          : _buildDefaultClubLogo(),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Club Name and Status
                  Expanded(
                    child: GestureDetector(
                      onTap: _showClubInfoDialog,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.club.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'tap here for club info',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: _exitSelectionMode,
                  tooltip: 'Cancel selection',
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.white),
                  onPressed: _selectedMessageIds.isNotEmpty
                      ? _deleteSelectedMessages
                      : null,
                  tooltip: 'Delete selected messages',
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => _loadMessages(forceSync: true),
                  tooltip: 'Refresh messages',
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showMoreOptions(),
                  tooltip: 'More options',
                ),
              ],
      ),
      body: SafeArea(
        child: Container(
          child: Column(
            children: [
              // Messages List - Takes all available space
              Expanded(
                child: Container(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      // Close keyboard when tapping in messages area
                      FocusScope.of(context).unfocus();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: _isLoading
                        ? _buildLoadingState()
                        : _error != null
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
              _buildMessageInput(),
            ],
          ),
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
          _buildPinnedMessagesSection(pinnedMessages),

        // Chat flow: ALL messages including pinned ones in chronological order
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            itemCount: listItems.length,
            itemBuilder: (context, index) {
              final item = listItems[index];
              
              // Check if item is a date header
              if (item is DateTime) {
                return _buildDateHeader(item);
              }
              
              // Otherwise it's a message
              final message = item as ClubMessage;
              final messageIndex = allMessages.indexOf(message);
              final previousMessage = messageIndex > 0 ? allMessages[messageIndex - 1] : null;
              final nextMessage = messageIndex < allMessages.length - 1
                  ? allMessages[messageIndex + 1]
                  : null;

              final showSenderInfo =
                  previousMessage == null ||
                  previousMessage.senderId != message.senderId ||
                  !_isSameDate(message.createdAt, previousMessage.createdAt);

              final isLastFromSender =
                  nextMessage == null ||
                  nextMessage.senderId != message.senderId ||
                  !_isSameDate(message.createdAt, nextMessage.createdAt);

              return Container(
                key: ValueKey('message_${message.id}'),
                child: _MessageVisibilityDetector(
                  messageId: message.id,
                  message: message,
                  onVisible: _markMessageAsSeen,
                  currentUserId: context.read<UserProvider>().user?.id,
                  child: _buildMessageBubble(
                    message,
                    showSenderInfo,
                    isLastFromSender,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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

  // Helper method to build date header widget
  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    
    String dateText;
    if (_isSameDate(date, today)) {
      dateText = 'Today';
    } else if (_isSameDate(date, yesterday)) {
      dateText = 'Yesterday';
    } else {
      // Format as "Mon, Jan 15, 2024"
      final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      final weekday = weekdays[date.weekday % 7];
      final month = months[date.month - 1];
      
      dateText = '$weekday, $month ${date.day}, ${date.year}';
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.0),
      alignment: Alignment.center,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ClubMessage message,
    bool showSenderInfo,
    bool isLastFromSender,
  ) {
    final userProvider = context.read<UserProvider>();
    final isOwn = message.senderId == userProvider.user?.id;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: isLastFromSender ? 12 : 4),
      decoration: _highlightedMessageId == message.id
          ? BoxDecoration(
              color: Color(0xFF06aeef).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: _highlightedMessageId == message.id
          ? EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: isOwn
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOwn && showSenderInfo) _buildSenderAvatar(message),
              if (!isOwn && !showSenderInfo) SizedBox(width: 34),

              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: Stack(
                    children: [
                      // Reply icon background (shown during slide)
                      if (_isSliding && _slidingMessageId == message.id)
                        Positioned(
                          right: isOwn ? null : 10,
                          left: isOwn ? 10 : null,
                          top: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 100),
                            width: 50,
                            decoration: BoxDecoration(
                              color: Color(0xFF06aeef).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            alignment: Alignment.center,
                            child: AnimatedScale(
                              scale: _slideOffset > 50.0 ? 1.2 : 1.0,
                              duration: Duration(milliseconds: 100),
                              child: Icon(
                                Icons.reply,
                                color: Color(
                                  0xFF06aeff,
                                ).withOpacity(_slideOffset > 50.0 ? 1.0 : 0.7),
                                size: _slideOffset > 50.0 ? 32 : 28,
                              ),
                            ),
                          ),
                        ),

                      // Message content with slide animation
                      Transform.translate(
                        offset: Offset(
                          _slidingMessageId == message.id
                              ? (isOwn ? -_slideOffset : _slideOffset)
                              : 0.0,
                          0.0,
                        ),
                        child: Column(
                          crossAxisAlignment: isOwn
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Reply info (if this message is a reply)
                            if (message.replyTo != null)
                              _buildReplyInfo(message.replyTo!, isOwn),

                            GestureDetector(
                              onTap: message.deleted
                                  ? null
                                  : _isSelectionMode
                                  ? () => _toggleSelection(message.id)
                                  : message.status == MessageStatus.failed
                                  ? () => _showErrorDialog(message)
                                  : () => _showMessageOptions(message),
                              onLongPress: (_isSelectionMode || message.deleted)
                                  ? null
                                  : () => _showMessageOptions(message),
                              onPanUpdate: (_isSelectionMode || message.deleted)
                                  ? null
                                  : (details) => _handleSlideGesture(
                                      details,
                                      message,
                                      isOwn,
                                    ),
                              onPanEnd: (_isSelectionMode || message.deleted)
                                  ? null
                                  : (details) => _handleSlideEnd(
                                      details,
                                      message,
                                      isOwn,
                                    ),
                              child: MessageBubbleFactory(
                                message: message,
                                isOwn: isOwn,
                                isDeleted: message.deleted,
                                isPinned: _isCurrentlyPinned(message),
                                isSelected: _selectedMessageIds.contains(
                                  message.id,
                                ),
                                showSenderInfo: showSenderInfo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(ClubMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Text(
              'Message Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The following message could not be sent:',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[600]!
                      : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                '"${message.content}"',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black.withOpacity(0.7),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Error: ${message.errorMessage ?? "Unknown error"}',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Dismiss',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryMessage(message);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _retryMessage(ClubMessage failedMessage) {
    // Remove the failed message and resend it
    setState(() {
      _messages.removeWhere((m) => m.id == failedMessage.id);
      _messageController.text = failedMessage.content;
      _isComposing = true;
    });

    // Trigger send after a short delay to allow UI to update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendMessage();
    });
  }

  Widget _buildDefaultClubLogo() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.club.name.isNotEmpty
              ? widget.club.name.substring(0, 1).toUpperCase()
              : 'C',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(ClubMessage message) {
    return Container(
      width: 28,
      height: 28,
      margin: EdgeInsets.only(right: 6, bottom: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border.all(
          color: _getRoleColor(message.senderRole ?? 'MEMBER').withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child:
            message.senderProfilePicture != null &&
                message.senderProfilePicture!.isNotEmpty
            ? Image.network(
                message.senderProfilePicture!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultSenderAvatar(message);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildDefaultSenderAvatar(message);
                },
              )
            : _buildDefaultSenderAvatar(message),
      ),
    );
  }

  Widget _buildDefaultSenderAvatar(ClubMessage message) {
    return Container(
      color: _getRoleColor(message.senderRole ?? 'MEMBER').withOpacity(0.1),
      child: Center(
        child: Text(
          message.senderName.isNotEmpty
              ? message.senderName.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _getRoleColor(message.senderRole ?? 'MEMBER'),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return Colors.purple;
      case 'ADMIN':
        return Colors.red;
      case 'CAPTAIN':
        return Colors.orange;
      case 'VICE_CAPTAIN':
        return Colors.amber;
      case 'COACH':
        return Colors.blue;
      case 'MEMBER':
      default:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]!
            : Colors.grey[600]!;
    }
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
                              _shareLocation();
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
                              _showCreateMatch(); // Placeholder for contact sharing
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.storefront,
                            iconColor: Colors.black,
                            title: 'Catalog',
                            onTap: () {
                              Navigator.pop(context);
                              _showCreateTournament(); // Placeholder for catalog
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.bolt,
                            iconColor: Color(0xFFFFB300),
                            title: 'Quick replies',
                            onTap: () {
                              Navigator.pop(context);
                              _showCreateEvent(); // Placeholder for quick replies
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.poll,
                            iconColor: Color(0xFFFFB300),
                            title: 'Poll',
                            onTap: () {
                              Navigator.pop(context);
                              _showCreatePoll();
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
                              _showCreateEvent();
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

  Widget _buildUploadOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
              ),
            ),
          ],
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

  void _showCreatePoll() {
    _showErrorSnackBar('Poll creation coming soon!');
  }

  void _showCreateMatch() {
    _showErrorSnackBar('Match creation coming soon!');
  }

  void _showCreateTournament() {
    _showErrorSnackBar('Tournament creation coming soon!');
  }

  void _showCreateEvent() {
    _showErrorSnackBar('Event creation coming soon!');
  }

  void _shareLocation() {
    _showErrorSnackBar('Location sharing coming soon!');
  }

  bool _canShareUPIQR() {
    // TODO: This should check the current user's role in the club
    // For now, we'll check if UPI ID is available in the club data
    // In a complete implementation, this would verify the user is OWNER or ADMIN
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;

    if (user == null) return false;

    // For demo purposes, return true if club has UPI ID configured
    // In production, this should also check user role in club membership
    return widget.club.upiId != null && widget.club.upiId!.isNotEmpty;
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking documents: $e')));
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

  Widget _buildImagePreview(PlatformFile file) {
    // Check if it's a local file path or bytes
    if (file.bytes != null) {
      // Web platform - use bytes
      return Image.memory(
        file.bytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 150,
            color: Colors.grey[300],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
                  SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (file.path != null) {
      // Mobile platform - use file path
      return Image.file(
        File(file.path!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 150,
            color: Colors.grey[300],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
                  SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Fallback - show placeholder
      return Container(
        height: 150,
        color: Colors.grey[300],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 48, color: Colors.grey[600]),
              SizedBox(height: 8),
              Text('Image preview', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
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
      _messages.add(optimisticMessage);
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
      print('Error uploading images: $e');
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

      final response = await ApiService.post(
        '/conversations/${widget.club.id}/messages',
        requestData,
      );

      print('✅ Message with media sent successfully');
      print('📡 Server response: $response');

      // Remove temporary message and reload all messages to get the server version
      setState(() {
        _messages.removeWhere((m) => m.id == tempMessageId);
      });

      // Add new message to local storage
      final newMessage = ClubMessage.fromJson(response);
      await MessageStorageService.addMessage(widget.club.id, newMessage);

      // Update UI
      setState(() {
        // Remove temp message and add real message
        _messages.removeWhere((m) => m.id == tempMessageId);
        _messages.add(newMessage);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
    } catch (e) {
      print('❌ Error sending message with media: $e');
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
      final response = await ApiService.post(
        '/conversations/${widget.club.id}/messages',
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

      final newMessage = ClubMessage.fromJson(response);

      setState(() {
        _messages.insert(0, newMessage);
      });

      print('✅ Message with documents sent successfully');
    } catch (e) {
      print('❌ Error sending message with documents: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadDocuments(List<PlatformFile> files) async {
    try {
      List<MessageDocument> uploadedDocs = [];

      for (PlatformFile file in files) {
        final uploadedUrl = await _uploadFile(file);
        if (uploadedUrl != null) {
          final extension = file.extension?.toLowerCase() ?? '';
          final fileSize = _formatFileSize(file.size ?? 0);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading documents: $e')));
    }
  }

  Future<LinkMetadata?> _fetchLinkMetadata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final html = response.body;

        // Extract metadata using RegExp
        String? title = _extractMetaContent(
          html,
          r'<title[^>]*>([^<]+)</title>',
        );
        if (title == null) {
          title = _extractMetaContent(
            html,
            r'<meta[^>]*property=["\047]og:title["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>',
          );
        }

        String? description = _extractMetaContent(
          html,
          r'<meta[^>]*name=["\047]description["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>',
        );
        if (description == null) {
          description = _extractMetaContent(
            html,
            r'<meta[^>]*property=["\047]og:description["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>',
          );
        }

        String? image = _extractMetaContent(
          html,
          r'<meta[^>]*property=["\047]og:image["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>',
        );

        String? siteName = _extractMetaContent(
          html,
          r'<meta[^>]*property=["\047]og:site_name["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>',
        );

        // Get favicon
        String? favicon = _extractMetaContent(
          html,
          r'<link[^>]*rel=["\047](?:icon|shortcut icon)["\047][^>]*href=["\047]([^"\047>]*)["\047][^>]*>',
        );
        if (favicon != null && !favicon.startsWith('http')) {
          final uri = Uri.parse(url);
          favicon =
              '${uri.scheme}://${uri.host}${favicon.startsWith('/') ? '' : '/'}$favicon';
        }

        return LinkMetadata(
          url: url,
          title: title,
          description: description,
          image: image,
          siteName: siteName,
          favicon: favicon,
        );
      }
    } catch (e) {
      print('Error fetching metadata for $url: $e');
    }
    return null;
  }

  String? _extractMetaContent(String html, String pattern) {
    final regex = RegExp(pattern, caseSensitive: false);
    final match = regex.firstMatch(html);
    return match?.group(1)?.trim();
  }

  Future<List<int>?> _compressImage(PlatformFile file) async {
    try {
      // Check if file is an image
      final extension = file.extension?.toLowerCase();
      if (extension == null ||
          !['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        // Not an image, return original bytes
        return file.bytes ?? await File(file.path!).readAsBytes();
      }

      final originalSize = file.size ?? 0;
      print(
        '🗜️ Attempting to compress image: ${file.name} (${(originalSize / (1024 * 1024)).toStringAsFixed(2)} MB)',
      );

      // If file is already small (< 1MB), don't compress
      if (originalSize < 1024 * 1024) {
        print('📷 Image is small enough, skipping compression');
        return file.bytes ?? await File(file.path!).readAsBytes();
      }

      List<int>? result;

      try {
        if (file.bytes != null) {
          // Compress from bytes (web)
          result = await FlutterImageCompress.compressWithList(
            file.bytes!,
            minHeight: 1920, // Max height 1920px
            minWidth: 1920, // Max width 1920px
            quality: 70, // 70% quality
            format: CompressFormat.jpeg,
          );
        } else if (file.path != null) {
          // Compress from file path (mobile)
          result = await FlutterImageCompress.compressWithFile(
            file.path!,
            minHeight: 1920, // Max height 1920px
            minWidth: 1920, // Max width 1920px
            quality: 70, // 70% quality
            format: CompressFormat.jpeg,
          );
        }
      } catch (compressionError) {
        print('⚠️ Compression library error: $compressionError');
        result = null;
      }

      // If compression failed or returned null, use original
      if (result == null || result.isEmpty) {
        print('🔄 Compression failed, using original image');
        result = (file.bytes ?? await File(file.path!).readAsBytes())
            .cast<int>();
      }

      final finalSize = result.length;
      if (finalSize < originalSize) {
        final reductionPercent = ((1 - finalSize / originalSize) * 100)
            .toStringAsFixed(1);
        print(
          '✅ Image compressed: ${file.name} (${(finalSize / (1024 * 1024)).toStringAsFixed(2)} MB) - $reductionPercent% reduction',
        );
      } else {
        print(
          '📷 Using original image: ${file.name} (${(finalSize / (1024 * 1024)).toStringAsFixed(2)} MB)',
        );
      }

      return result;
    } catch (e) {
      print('❌ Image processing failed: $e');
      // Return original bytes if everything fails
      try {
        return file.bytes ?? await File(file.path!).readAsBytes();
      } catch (fallbackError) {
        print('❌ Failed to read original file: $fallbackError');
        return null;
      }
    }
  }

  Future<String?> _uploadFile(PlatformFile file) async {
    try {
      // Compress image if it's an image file
      final bytes = await _compressImage(file);
      if (bytes == null) {
        throw Exception('Failed to process file: ${file.name}');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/upload'),
      );

      request.headers.addAll(ApiService.fileHeaders);
      // Determine content type based on file extension
      String? contentType;
      final extension = file.extension?.toLowerCase();
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        case 'pdf':
          contentType = 'application/pdf';
          break;
        case 'txt':
          contentType = 'text/plain';
          break;
        case 'm4a':
          contentType = 'audio/mp4';
          break;
        case 'mp4':
          contentType = 'video/mp4';
          break;
        case 'mp3':
          contentType = 'audio/mpeg';
          break;
        case 'wav':
          contentType = 'audio/wav';
          break;
        case 'aac':
          contentType = 'audio/aac';
          break;
        default:
          contentType = 'application/octet-stream';
      }

      // Debug: Print upload information
      print('Uploading file: ${file.name}');
      print('  Extension: $extension');
      print('  Content Type: $contentType');
      print('  File Size: ${file.size} bytes');

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
          contentType: MediaType.parse(contentType),
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(responseData);
        return result['url'];
      } else {
        throw Exception('Upload failed: $responseData');
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  List<TextSpan> _parseInlineFormatting(
    String text,
    Color baseColor,
    Color codeBackgroundColor,
  ) {
    final List<TextSpan> spans = [];
    int currentIndex = 0;

    // Combined regex for all inline formatting
    final regex = RegExp(r'(\*[^*]+\*)|(_[^_]+_)|(~[^~]+~)|(`[^`]+`)');

    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(color: baseColor),
          ),
        );
      }

      final matchedText = match.group(0)!;

      if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        // Bold: *text*
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: TextStyle(fontWeight: FontWeight.bold, color: baseColor),
          ),
        );
      } else if (matchedText.startsWith('_') && matchedText.endsWith('_')) {
        // Italic: _text_
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: TextStyle(fontStyle: FontStyle.italic, color: baseColor),
          ),
        );
      } else if (matchedText.startsWith('~') && matchedText.endsWith('~')) {
        // Strikethrough: ~text~
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: baseColor,
            ),
          ),
        );
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        // Inline code: `text`
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: codeBackgroundColor,
              color: baseColor,
            ),
          ),
        );
      }

      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: baseColor),
        ),
      );
    }

    return spans;
  }

  Widget _buildImageWidget(MessageImage image, {double height = 200}) {
    // Check if it's a local file path (during upload) or network URL
    final isLocalFile =
        image.url.startsWith('/') ||
        image.url.startsWith('file://') ||
        !image.url.startsWith('http');

    if (isLocalFile && File(image.url).existsSync()) {
      return Image.file(
        File(image.url),
        fit: BoxFit.cover,
        height: height,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: height > 150 ? 48 : 24,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[600],
              ),
            ),
          );
        },
      );
    } else {
      return Image.network(
        image.url,
        fit: BoxFit.cover,
        height: height,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: height > 150 ? 48 : 24,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[600],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildImageGallery(List<MessageImage> images) {
    // Collect all captions to display below images
    final allCaptions = images
        .where((img) => img.caption != null && img.caption!.isNotEmpty)
        .map((img) => img.caption!)
        .toList();

    // If only 1-2 images, show them without borders/background
    if (images.length <= 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          ...images
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _openImageGallery(images, entry.key),
                    child: Hero(
                      tag: 'image_${entry.value.url}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildImageWidget(entry.value),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          // Show all captions below images
          if (allCaptions.isNotEmpty) ...[
            SizedBox(height: 4),
            ...allCaptions.map(
              (caption) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  caption,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // For 3+ images, show gallery grid with +n more
    return Column(
      children: [
        SizedBox(height: 8),
        Container(
          height: 120,
          child: Row(
            children: [
              // Show up to 4 images
              for (int i = 0; i < (images.length > 4 ? 4 : images.length); i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'image_${images[i].url}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImageWidget(images[i], height: 120),
                          ),
                        ),
                        // Show +n more on 4th image if there are more
                        if (i == 3 && images.length > 4)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '+${images.length - 4}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Tap to view all images
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _openImageGallery(images, i),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Show all captions below the grid
        if (allCaptions.isNotEmpty) ...[
          SizedBox(height: 8),
          ...allCaptions.map(
            (caption) => Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                caption,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openImageGallery(List<MessageImage> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageGalleryScreen(
          messages: _messages,
          initialImageIndex: initialIndex,
          initialImageUrl: images[initialIndex].url,
        ),
      ),
    );
  }

  Widget _buildDocumentList(List<MessageDocument> documents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        ...documents
            .map(
              (doc) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[600]!
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        doc.type == 'pdf'
                            ? Icons.picture_as_pdf
                            : Icons.description,
                        color: doc.type == 'pdf' ? Colors.red : Colors.blue,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.filename,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  doc.type.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey[600],
                                  ),
                                ),
                                if (doc.size != null) ...[
                                  Text(
                                    ' • ${doc.size}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.download,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildLinkPreviews(List<LinkMetadata> linkMeta) {
    return Column(
      children: [
        SizedBox(height: 8),
        ...linkMeta
            .map(
              (link) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _launchUrl(link.url),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]!
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image preview if available
                        if (link.image != null && link.image!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              link.image!,
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return SizedBox.shrink(); // Hide if image fails to load
                              },
                            ),
                          ),

                        // Content
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              if (link.title != null && link.title!.isNotEmpty)
                                Text(
                                  link.title!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.black.withOpacity(0.8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                              // Description
                              if (link.description != null &&
                                  link.description!.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Text(
                                  link.description!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.black.withOpacity(0.6),
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              // Site info
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  // Favicon if available
                                  if (link.favicon != null &&
                                      link.favicon!.isNotEmpty) ...[
                                    Image.network(
                                      link.favicon!,
                                      width: 16,
                                      height: 16,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.language,
                                              size: 16,
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white.withOpacity(
                                                      0.6,
                                                    )
                                                  : Colors.grey[600],
                                            );
                                          },
                                    ),
                                    SizedBox(width: 8),
                                  ] else ...[
                                    Icon(
                                      Icons.language,
                                      size: 16,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.grey[600],
                                    ),
                                    SizedBox(width: 8),
                                  ],

                                  Expanded(
                                    child: Text(
                                      link.siteName ?? Uri.parse(link.url).host,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.6)
                                            : Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  Icon(
                                    Icons.open_in_new,
                                    size: 16,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey[600],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  void _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
    }
  }

  void _showImageDialog(List<MessageImage> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        child: Image.network(
                          image.url,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 64,
                                    color: Colors.white54,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (image.caption != null && image.caption!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        color: Colors.black87,
                        child: Text(
                          image.caption!,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]!
              : Colors.grey[50],
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Check if audio recording is active - if so, show full-width recording interface
            if (_audioRecordingKey.currentState?.isRecording == true ||
                _audioRecordingKey.currentState?.hasRecording == true) ...[
              // Full-width audio recording interface
              AudioRecordingWidget(
                key: _audioRecordingKey,
                onAudioRecorded: _sendAudioMessage,
                isComposing: _isComposing,
                onRecordingStateChanged: () {
                  setState(() {
                    // This will trigger a rebuild with the new recording state
                  });
                },
              ),
            ] else ...[
              // Normal input interface
              // Attachment button (+)
              IconButton(
                onPressed: _showUploadOptions,
                icon: Icon(
                  Icons.add,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                iconSize: 28,
              ),

              // Expanded message input area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF2a2f32)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        spreadRadius: 0.5,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Text field
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _textFieldFocusNode,
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                          maxLines: 5,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onChanged: (value) {
                            setState(() {
                              _isComposing = value.trim().isNotEmpty;
                            });
                            _handleTextChanged(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Camera button - hidden when composing
              if (!_isComposing)
                IconButton(
                  onPressed: _capturePhotoWithCamera,
                  icon: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                  iconSize: 28,
                ),

              // Send button or audio recording widget
              if (_isComposing)
                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send, color: Color(0xFF003f9b)),
                  iconSize: 28,
                )
              else
                AudioRecordingWidget(
                  key: _audioRecordingKey,
                  onAudioRecorded: _sendAudioMessage,
                  isComposing: _isComposing,
                  onRecordingStateChanged: () {
                    setState(() {
                      // This will trigger a rebuild with the new recording state
                    });
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _getPopularEmojis() {
    return [
      '😀',
      '😂',
      '😍',
      '🥰',
      '😊',
      '😉',
      '😎',
      '🤔',
      '😢',
      '😭',
      '😡',
      '🤬',
      '🥺',
      '😤',
      '😴',
      '🤤',
      '👍',
      '👎',
      '👏',
      '🙌',
      '👋',
      '✋',
      '👌',
      '🤞',
      '💪',
      '🙏',
      '✨',
      '🔥',
      '💯',
      '❤️',
      '💔',
      '😘',
      '🏏',
      '⚾',
      '🏀',
      '⚽',
      '🎾',
      '🏆',
      '🥇',
      '🎉',
      '🎊',
      '🎈',
      '🎁',
      '🍕',
      '🍔',
      '🍟',
      '🍗',
      '🌮',
    ];
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: TextStyle(
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

  Widget _buildReplyInfo(MessageReply reply, bool isOwn) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: Color(0xFF06aeef), width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF06aeef),
              ),
            ),
            SizedBox(height: 2),
            Text(
              reply.content,
              style: TextStyle(
                fontSize: 13,
                color: (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.6)),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(ClubMessage message) {
    HapticFeedback.lightImpact(); // Add haptic feedback for better UX
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF2a2f32)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick reactions at the top
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '+']
                    .map(
                      (emoji) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          if (emoji == '+') {
                            _showReactionPicker(message);
                          } else {
                            setState(() {
                              _selectedMessageForReaction = message;
                            });
                            _addReaction(emoji);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: emoji == '+'
                                ? Colors.grey.withOpacity(0.2)
                                : null,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: emoji == '+'
                              ? Icon(Icons.add, size: 24, color: Colors.grey)
                              : Text(emoji, style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            Divider(height: 32),

            // Options
            _buildOptionTile(
              icon: Icons.reply,
              title: 'Reply',
              onTap: () {
                Navigator.pop(context);
                _setReply(message);
              },
            ),
            _buildOptionTile(
              icon: Icons.copy,
              title: 'Copy',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Message copied')));
              },
            ),
            // Only show Info option for user's own messages
            if (_isOwnMessage(message))
              _buildOptionTile(
                icon: Icons.info_outline,
                title: 'Info',
                onTap: () {
                  Navigator.pop(context);
                  _showMessageInfo(message);
                },
              ),
            _buildOptionTile(
              icon: message.starred.isStarred ? Icons.star : Icons.star_outline,
              title: message.starred.isStarred ? 'Unstar' : 'Star',
              onTap: () {
                Navigator.pop(context);
                _toggleStar(message);
              },
            ),
            // Only show pin option if user has permission
            if (_canPinMessages())
              _buildOptionTile(
                icon: _isCurrentlyPinned(message)
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                title: _isCurrentlyPinned(message) ? 'Unpin' : 'Pin',
                onTap: () {
                  Navigator.pop(context);
                  _togglePin(message);
                },
              ),
            _buildOptionTile(
              icon: Icons.delete,
              title: 'Delete',
              titleColor: Colors.red,
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isSelectionMode = true;
                  _selectedMessageIds.add(message.id);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color:
            iconColor ??
            (Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.8)
                : Colors.black.withOpacity(0.7)),
      ),
      title: Text(
        title,
        style: TextStyle(
          color:
              titleColor ??
              (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black.withOpacity(0.8)),
        ),
      ),
      onTap: onTap,
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

  void _showMessageInfo(ClubMessage message) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fetching message status...'),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );

    try {
      final response = await ApiService.get(
        '/conversations/${widget.club.id}/messages/${message.id}/status',
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Message Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sent at: ${_formatDateTime(message.createdAt)}'),
                SizedBox(height: 8),
                if (response['deliveredTo'] != null &&
                    response['deliveredTo'].isNotEmpty) ...[
                  Text(
                    'Delivered to:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...response['deliveredTo']
                      .map<Widget>(
                        (user) => Padding(
                          padding: EdgeInsets.only(left: 16, top: 2),
                          child: Text('• ${user['name']}'),
                        ),
                      )
                      .toList(),
                  SizedBox(height: 8),
                ],
                if (response['readBy'] != null &&
                    response['readBy'].isNotEmpty) ...[
                  Text(
                    'Read by:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...response['readBy']
                      .map<Widget>(
                        (user) => Padding(
                          padding: EdgeInsets.only(left: 16, top: 2),
                          child: Text(
                            '• ${user['name']} at ${_formatDateTime(DateTime.parse(user['readAt']))}',
                          ),
                        ),
                      )
                      .toList(),
                ],
              ],
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
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to fetch message status: $e'),
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
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _toggleStar(ClubMessage message) async {
    try {
      final endpoint = message.starred.isStarred ? '/unstar' : '/star';
      await ApiService.post(
        '/conversations/${widget.club.id}/messages/${message.id}$endpoint',
        {},
      );

      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            starred: StarredInfo(
              isStarred: !message.starred.isStarred,
              starredAt: !message.starred.isStarred
                  ? DateTime.now().toIso8601String()
                  : null,
            ),
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.starred.isStarred
                  ? 'Message unstarred'
                  : 'Message starred',
            ),
            backgroundColor: Color(0xFF003f9b),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${message.starred.isStarred ? 'unstar' : 'star'} message: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              Container(
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
      await ApiService.post(
        '/conversations/${widget.club.id}/messages/${message.id}/pin',
        requestData,
      );
      // Sync from server to get authoritative pinned status for all users
      await _syncMessagesFromServer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message pinned for ${_formatDuration(hours)}'),
            backgroundColor: Color(0xFF003f9b),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pin message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unpinMessage(ClubMessage message) async {
    try {
      await ApiService.delete(
        '/conversations/${widget.club.id}/messages/${message.id}/pin',
      );

      // Sync from server to get authoritative pinned status for all users
      await _syncMessagesFromServer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message unpinned'),
            backgroundColor: Color(0xFF003f9b),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unpin message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(int hours) {
    if (hours == 24) {
      return '24 hours';
    } else if (hours == 24 * 7) {
      return '7 days';
    } else if (hours == 24 * 30) {
      return '30 days';
    } else if (hours < 24) {
      return '$hours hours';
    } else {
      final days = hours ~/ 24;
      return '$days days';
    }
  }

  Timer? _pinnedRefreshTimer;

  // Helper method to check if a message belongs to the current user
  bool _isOwnMessage(ClubMessage message) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.user;
    return currentUser != null && message.senderId == currentUser.id;
  }

  // Helper method to check if current user can pin messages
  bool _canPinMessages() {
    if (_detailedClubInfo == null) return false;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return false;

    // Check if user's role is in the allowed pin permissions
    // We need to get the user's role in this club from their messages
    // For now, we can check if they're OWNER or ADMIN based on pinMessagePermissions
    final allowedRoles = _detailedClubInfo!.pinMessagePermissions;

    // Get user's role from their own messages in the conversation
    final userMessages = _messages.where((m) => m.senderId == user.id).toList();
    if (userMessages.isNotEmpty) {
      final userRole = userMessages.first.senderRole ?? 'MEMBER';
      return allowedRoles.contains(userRole);
    }

    // Default to MEMBER role if no messages found
    return allowedRoles.contains('MEMBER');
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

  // Start a timer to refresh pinned messages when pin periods expire and check for new pins
  void _startPinnedRefreshTimer() {
    _pinnedRefreshTimer?.cancel();

    // Check for pin expiry every minute, sync with server every 5 minutes
    _pinnedRefreshTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      if (mounted) {
        final currentPinnedIds = _messages
            .where((m) => _isCurrentlyPinned(m))
            .map((m) => m.id)
            .toSet();
        final previousPinnedIds = _lastKnownPinnedIds ?? <String>{};

        // If the set of pinned messages has changed, refresh the UI
        if (currentPinnedIds.length != previousPinnedIds.length ||
            !currentPinnedIds.containsAll(previousPinnedIds)) {
          setState(() {
            _lastKnownPinnedIds = currentPinnedIds;
            // Reset pinned index when pinned messages change
            _currentPinnedIndex = 0;
          });
        }

        // Periodically sync messages from server (every 5 minutes)
        if (timer.tick % 5 == 0) {
          // Every 5th tick (5 * 1 minute = 5 minutes)
          final needsSync = await MessageStorageService.needsSync(
            widget.club.id,
          );
          if (needsSync) {
            try {
              print('📡 Periodic sync: syncing messages from server...');
              await _syncMessagesFromServer();
            } catch (e) {
              // Silently ignore refresh errors to avoid disrupting user experience
              debugPrint('Failed to sync messages during periodic refresh: $e');
            }
          }
        }
      }
    });

    // Store current pinned message IDs for comparison
    _lastKnownPinnedIds = _messages
        .where((m) => _isCurrentlyPinned(m))
        .map((m) => m.id)
        .toSet();
  }

  Set<String>? _lastKnownPinnedIds;
  int _currentPinnedIndex = 0; // Track current pinned message being displayed

  Widget _buildPinnedMessagesSection(List<ClubMessage> pinnedMessages) {
    if (pinnedMessages.isEmpty) return SizedBox.shrink();

    // Ensure current index is within bounds
    if (_currentPinnedIndex >= pinnedMessages.length) {
      _currentPinnedIndex = 0;
    }

    final currentMessage = pinnedMessages[_currentPinnedIndex];
    final hasMultiple = pinnedMessages.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1)),
      ),
      child: Column(
        children: [
          _buildPinnedMessageItem(
            currentMessage,
            pinnedMessages.length,
            _currentPinnedIndex + 1,
          ),
          if (hasMultiple)
            _buildPinnedIndicator(pinnedMessages.length, _currentPinnedIndex),
        ],
      ),
    );
  }

  /// Helper function to get appropriate display text for pinned messages
  String _getPinnedMessageDisplayText(ClubMessage message) {
    // Handle different message types
    if (message.messageType == 'audio' && message.audio != null) {
      return 'Audio';
    } else if (message.documents.isNotEmpty) {
      return message.documents.length == 1 ? 'Document' : '${message.documents.length} Documents';
    } else if (message.pictures.isNotEmpty) {
      return message.pictures.length == 1 ? 'Photo' : '${message.pictures.length} Photos';
    } else if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
      return 'GIF';
    } else if (message.linkMeta.isNotEmpty) {
      return 'Link';
    } else if (message.messageType == 'emoji') {
      // For emoji messages, show the actual emoji if content is available
      return message.content.trim().isNotEmpty ? message.content.trim() : 'Emoji';
    } else {
      // For text messages, return the content if available
      final content = message.content.trim();
      return content.isNotEmpty ? content : 'Message';
    }
  }

  Widget _buildPinnedMessageItem(
    ClubMessage message,
    int totalCount,
    int currentIndex,
  ) {
    final String displayText = _getPinnedMessageDisplayText(message);
    final String firstLine = displayText.split('\n').first;

    return GestureDetector(
      onTap: () => _cycleToPinnedMessage(message.id),
      onLongPress: () => _showPinnedMessageOptions(message),
      child: Container(
        height: 56, // Fixed height to prevent changes
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pin icon
            Icon(Icons.push_pin, size: 16, color: Color(0xFF6C757D)),
            SizedBox(width: 8),

            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Message preview
                  Text(
                    firstLine,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6C757D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Visual indicator for different message types
            _buildPinnedMessageIndicator(message),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedMessageImages(List<MessageImage> pictures) {
    final imagesToShow = pictures.take(3).toList();

    return Container(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: imagesToShow.asMap().entries.map((entry) {
          final index = entry.key;
          final image = entry.value;
          final isLast = index == imagesToShow.length - 1;
          final remainingCount = pictures.length - 3;

          return Container(
            margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: image.url,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image,
                        color: Colors.grey[600],
                        size: 14,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey[600],
                        size: 14,
                      ),
                    ),
                  ),
                ),
                // Show count overlay on last image if there are more than 3
                if (isLast && remainingCount > 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '+$remainingCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds visual indicator for different message types in pinned messages
  Widget _buildPinnedMessageIndicator(ClubMessage message) {
    // Show images if available
    if (message.pictures.isNotEmpty) {
      return _buildPinnedMessageImages(message.pictures);
    }
    
    // Show icon indicators for other message types
    Widget? iconWidget;
    Color iconColor = Color(0xFF6C757D);
    
    if (message.messageType == 'audio' && message.audio != null) {
      iconWidget = Icon(Icons.audiotrack, size: 20, color: iconColor);
    } else if (message.documents.isNotEmpty) {
      iconWidget = Icon(Icons.description, size: 20, color: iconColor);
    } else if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
      iconWidget = Icon(Icons.gif_box, size: 20, color: iconColor);
    } else if (message.linkMeta.isNotEmpty) {
      iconWidget = Icon(Icons.link, size: 20, color: iconColor);
    } else if (message.messageType == 'emoji') {
      iconWidget = Icon(Icons.emoji_emotions, size: 20, color: iconColor);
    }
    
    // Return icon container if we have an icon to show
    if (iconWidget != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFDEE2E6), width: 1),
        ),
        child: Center(child: iconWidget),
      );
    }
    
    // For regular text messages, don't show any indicator
    return SizedBox.shrink();
  }

  Widget _buildPinnedIndicator(int totalCount, int currentIndex) {
    // Show max 4 indicators as requested
    final indicatorsToShow = totalCount > 4 ? 4 : totalCount;

    return Container(
      padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
      child: Row(
        children: [
          // Current position text (e.g., "1 of 5")
          Text(
            '${currentIndex + 1} of $totalCount',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6C757D),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          // Line indicators
          Expanded(
            child: Row(
              children: List.generate(indicatorsToShow, (index) {
                bool isActive;
                if (totalCount <= 4) {
                  // Show normal indicators for 4 or fewer items
                  isActive = index == currentIndex;
                } else {
                  // For more than 4 items, show progress within the 4 indicators
                  final progress =
                      (currentIndex / (totalCount - 1)) *
                      (indicatorsToShow - 1);
                  isActive = index <= progress.round();
                }

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: index < indicatorsToShow - 1 ? 2 : 0,
                    ),
                    height: 2,
                    decoration: BoxDecoration(
                      color: isActive ? Color(0xFF003f9b) : Color(0xFFDEE2E6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _cycleToPinnedMessage(String currentMessageId) {
    final pinnedMessages = _messages
        .where((m) => _isCurrentlyPinned(m))
        .toList();
    if (pinnedMessages.length <= 1) {
      // If only one pinned message, just scroll to it
      _scrollToMessage(currentMessageId);
      return;
    }

    // Cycle to next pinned message
    setState(() {
      _currentPinnedIndex = (_currentPinnedIndex + 1) % pinnedMessages.length;
    });

    // Scroll to the new current pinned message
    final nextMessage = pinnedMessages[_currentPinnedIndex];
    _scrollToMessage(nextMessage.id);
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

  void _showPinnedMessageOptions(ClubMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF2D3748)
              : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.navigation,
                title: 'Go to message',
                onTap: () {
                  Navigator.pop(context);
                  _scrollToMessage(message.id);
                },
              ),
              // Only show unpin option if user has permission
              if (_canPinMessages())
                _buildOptionTile(
                  icon: Icons.push_pin_outlined,
                  title: 'Unpin',
                  onTap: () {
                    Navigator.pop(context);
                    _togglePin(message);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom visibility detector widget for message seen status
class _MessageVisibilityDetector extends StatefulWidget {
  final String messageId;
  final ClubMessage message;
  final Function(String) onVisible;
  final String? currentUserId;
  final Widget child;

  const _MessageVisibilityDetector({
    Key? key,
    required this.messageId,
    required this.message,
    required this.onVisible,
    required this.currentUserId,
    required this.child,
  }) : super(key: key);

  @override
  _MessageVisibilityDetectorState createState() =>
      _MessageVisibilityDetectorState();
}

class _MessageVisibilityDetectorState
    extends State<_MessageVisibilityDetector> {
  bool _hasBeenSeen = false;

  @override
  Widget build(BuildContext context) {
    // Don't track visibility for own messages
    if (widget.message.senderId == widget.currentUserId) {
      return widget.child;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_hasBeenSeen && notification is ScrollUpdateNotification) {
          // Check if this widget is visible
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkVisibility();
          });
        }
        return false;
      },
      child: widget.child,
    );
  }

  void _checkVisibility() {
    if (_hasBeenSeen || !mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    try {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      final screenHeight = MediaQuery.of(context).size.height;
      final topSafeArea = MediaQuery.of(context).padding.top;
      final bottomSafeArea = MediaQuery.of(context).padding.bottom;

      // Calculate visible screen area (excluding status bar and navigation)
      final visibleTop = topSafeArea + 100; // Account for app bar
      final visibleBottom =
          screenHeight - bottomSafeArea - 150; // Account for input area

      // Check if message is visible in the viewport
      final messageTop = position.dy;
      final messageBottom = position.dy + size.height;

      // Message is considered "seen" if at least 50% of it is visible
      final visibleHeight =
          (messageBottom.clamp(visibleTop, visibleBottom) -
          messageTop.clamp(visibleTop, visibleBottom));
      final visibilityRatio = visibleHeight / size.height;

      if (visibilityRatio >= 0.5) {
        _hasBeenSeen = true;
        widget.onVisible(widget.messageId);
      }
    } catch (e) {
      // Handle any errors in visibility calculation
      print('❌ Error checking message visibility: $e');
    }
  }
}
