import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import 'text_message_bubble.dart';
import 'audio_message_bubble.dart';
import 'link_message_bubble.dart';
import 'gif_message_bubble.dart';
import 'emoji_message_bubble.dart';
import 'base_message_bubble.dart';

/// Factory widget that creates the appropriate message bubble based on content type
class MessageBubbleFactory extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isDeleted;
  final bool isSelected;
  final bool showSenderInfo;
  final VoidCallback? onRetryUpload;
  final Function(String messageId, String emoji, String userId)? onReactionRemoved;

  const MessageBubbleFactory({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.isDeleted,
    this.isSelected = false,
    this.showSenderInfo = false,
    this.onRetryUpload,
    this.onReactionRemoved,
  });

  @override
  Widget build(BuildContext context) {
    // Handle deleted messages first
    if (isDeleted) {
      return _buildDeletedMessage(context);
    }

    // Determine message type and render appropriate bubble
    if (message.messageType == 'audio' && message.audio != null) {
      // AUDIO MESSAGE: Just audio player
      return AudioMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        onRetryUpload: onRetryUpload,
        onReactionRemoved: onReactionRemoved,
      );
    } else if (message.linkMeta.isNotEmpty) {
      // LINK MESSAGE: Thumbnail, title, full link
      return LinkMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        onReactionRemoved: onReactionRemoved,
      );
    } else if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
      // GIF MESSAGE: GIF with optional text below
      return GifMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        onReactionRemoved: onReactionRemoved,
      );
    } else if (message.messageType == 'emoji') {
      // EMOJI MESSAGE: Large emoji without background
      return EmojiMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
        onReactionRemoved: onReactionRemoved,
      );
    } else {
      // TEXT MESSAGE: Images/videos first, then body below
      return TextMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
        onReactionRemoved: onReactionRemoved,
      );
    }
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      customColor: Colors.grey[300],
      showMetaOverlay: false,
      showShadow: true,
      onReactionRemoved: onReactionRemoved,
      content: Container(
        padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.do_not_disturb_on_outlined,
              size: 16,
              color: Colors.black87,
            ),
            SizedBox(width: 8),
            Text(
              'This message was deleted',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
