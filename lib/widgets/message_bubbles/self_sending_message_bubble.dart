import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/link_metadata.dart';
import '../../services/api_service.dart';
import '../../services/message_storage_service.dart';
import 'message_bubble_factory.dart';

/// A stateful message bubble that handles its own sending process
class SelfSendingMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isDeleted;
  final bool isSelected;
  final bool showSenderInfo;
  final String clubId;
  final Function(ClubMessage oldMessage, ClubMessage newMessage)? onMessageUpdated;
  final Function(String messageId)? onMessageFailed;

  const SelfSendingMessageBubble({
    Key? key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.isDeleted,
    required this.clubId,
    this.isSelected = false,
    this.showSenderInfo = false,
    this.onMessageUpdated,
    this.onMessageFailed,
  }) : super(key: key);

  @override
  _SelfSendingMessageBubbleState createState() => _SelfSendingMessageBubbleState();
}

class _SelfSendingMessageBubbleState extends State<SelfSendingMessageBubble> {
  late ClubMessage currentMessage;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    currentMessage = widget.message;
    
    // If this is a sending message, start the send process
    if (currentMessage.status == MessageStatus.sending && !_isSending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startSendProcess();
      });
    }
  }

  @override
  void didUpdateWidget(SelfSendingMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      setState(() {
        currentMessage = widget.message;
      });
    }
  }

  Future<void> _startSendProcess() async {
    if (_isSending || currentMessage.status != MessageStatus.sending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Fetch link metadata if message contains URLs
      List<LinkMetadata> linkMeta = [];
      final urlPattern = RegExp(r'https?://[^\s]+');
      final urls = urlPattern
          .allMatches(currentMessage.content)
          .map((match) => match.group(0)!)
          .toList();

      if (urls.isNotEmpty) {
        for (String url in urls) {
          final metadata = await _fetchLinkMetadata(url);
          if (metadata != null) {
            linkMeta.add(metadata);
          }
        }
      }

      // Determine message type
      String messageType = _determineMessageType(currentMessage.content, linkMeta);

      // Prepare API request
      final Map<String, dynamic> contentMap = {
        'type': messageType,
        'body': currentMessage.content,
      };

      if (linkMeta.isNotEmpty) {
        contentMap['meta'] = linkMeta.map((meta) => meta.toJson()).toList();
      }

      final requestData = {
        'senderId': currentMessage.senderId,
        'content': contentMap,
        if (currentMessage.replyTo != null) 'replyTo': currentMessage.replyTo!.toJson(),
      };

      // Send to API
      final response = await ApiService.post(
        '/conversations/${widget.clubId}/messages',
        requestData,
      );

      if (response != null) {
        // Handle successful response
        await _handleSuccessResponse(response, linkMeta);
      } else {
        // Handle failure
        await _handleSendFailure('Server response was null');
      }
    } catch (e) {
      // Handle error
      await _handleSendFailure(e.toString());
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _handleSuccessResponse(Map<String, dynamic> response, List<LinkMetadata> linkMeta) async {
    try {
      // Extract message data from response
      Map<String, dynamic>? messageData;
      
      if (response.containsKey('data') && response['data'] is Map) {
        messageData = response['data'] as Map<String, dynamic>;
      } else if (response.containsKey('message') && response['message'] is Map) {
        messageData = response['message'] as Map<String, dynamic>;
      } else {
        messageData = response;
      }

      if (messageData != null) {
        // Create new message from server response
        final newMessage = ClubMessage.fromJson(messageData);
        
        // Save to storage
        await MessageStorageService.addMessage(widget.clubId, newMessage);
        
        // Update current message
        setState(() {
          currentMessage = newMessage;
        });

        // Notify parent of update
        widget.onMessageUpdated?.call(widget.message, newMessage);

        // Mark as delivered
        await _markAsDelivered(newMessage.id);
        
      } else {
        // Fallback: just update status to sent
        final updatedMessage = currentMessage.copyWith(
          status: MessageStatus.sent,
        );
        setState(() {
          currentMessage = updatedMessage;
        });
        widget.onMessageUpdated?.call(widget.message, updatedMessage);
      }
    } catch (e) {
      await _handleSendFailure('Failed to process response: $e');
    }
  }

  Future<void> _handleSendFailure(String errorMessage) async {
    final failedMessage = currentMessage.copyWith(
      status: MessageStatus.failed,
      errorMessage: errorMessage,
    );
    
    setState(() {
      currentMessage = failedMessage;
    });

    widget.onMessageUpdated?.call(widget.message, failedMessage);
    widget.onMessageFailed?.call(currentMessage.id);
  }

  Future<void> _markAsDelivered(String messageId) async {
    try {
      await ApiService.post(
        '/conversations/${widget.clubId}/messages/$messageId/delivered',
        {},
      );
      
      await MessageStorageService.markAsDelivered(widget.clubId, messageId);
      
      // Update message status to delivered
      final deliveredMessage = currentMessage.copyWith(
        status: MessageStatus.delivered,
        deliveredAt: DateTime.now(),
      );
      
      setState(() {
        currentMessage = deliveredMessage;
      });
      
      widget.onMessageUpdated?.call(currentMessage, deliveredMessage);
    } catch (e) {
      print('⚠️ Failed to mark message as delivered: $e');
    }
  }

  Future<LinkMetadata?> _fetchLinkMetadata(String url) async {
    // Simplified link metadata fetching
    // In a real implementation, you'd call a service to get link previews
    try {
      // This should call your actual link preview service
      return null; // Placeholder
    } catch (e) {
      return null;
    }
  }

  String _determineMessageType(String content, List<LinkMetadata> linkMeta) {
    // Check if message is emoji-only
    final emojiOnlyPattern = RegExp(
      r'^(\s*[\p{Emoji}\p{Emoji_Modifier}\p{Emoji_Component}\p{Emoji_Modifier_Base}\p{Emoji_Presentation}\u200d]*\s*)+$',
      unicode: true,
    );
    final isEmojiOnly = emojiOnlyPattern.hasMatch(content) && content.trim().length <= 12;
    
    if (isEmojiOnly) {
      return 'emoji';
    } else if (linkMeta.isNotEmpty) {
      return 'link';
    } else {
      return 'text';
    }
  }

  void _handleRetry() {
    if (currentMessage.status == MessageStatus.failed) {
      final retryMessage = currentMessage.copyWith(
        status: MessageStatus.sending,
        errorMessage: null,
      );
      setState(() {
        currentMessage = retryMessage;
      });
      widget.onMessageUpdated?.call(widget.message, retryMessage);
      _startSendProcess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: currentMessage.status == MessageStatus.failed ? _handleRetry : null,
      child: MessageBubbleFactory(
        message: currentMessage,
        isOwn: widget.isOwn,
        isPinned: widget.isPinned,
        isDeleted: widget.isDeleted,
        isSelected: widget.isSelected,
        showSenderInfo: widget.showSenderInfo,
        onRetryUpload: currentMessage.status == MessageStatus.failed ? _handleRetry : null,
      ),
    );
  }
}