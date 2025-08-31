import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import 'text_message_bubble.dart';
import 'audio_message_bubble.dart';
import 'link_message_bubble.dart';
import 'gif_message_bubble.dart';
import 'base_message_bubble.dart';

/// Factory widget that creates the appropriate message bubble based on content type
class MessageBubbleFactory extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;

  const MessageBubbleFactory({
    Key? key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Handle deleted messages first
    if (message.deleted) {
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
      );
    } else if (message.linkMeta.isNotEmpty) {
      // LINK MESSAGE: Thumbnail, title, full link
      return LinkMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
      );
    } else if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
      // GIF MESSAGE: GIF with optional text below
      return GifMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
      );
    } else {
      // TEXT MESSAGE: Images/videos first, then body below
      return TextMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
      );
    }
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      content: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.do_not_disturb_on_outlined,
              size: 16,
              color: isOwn
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey[600],
            ),
            SizedBox(width: 8),
            Text(
              'This message was deleted',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isOwn
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}