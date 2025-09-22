import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../utils/text_utils.dart';
import 'base_message_bubble.dart';

/// Emoji message bubble - displays large emojis without background
class EmojiMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;

  const EmojiMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
    this.showSenderInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      isTransparent: true,
      showMetaOverlay: false,
      content: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sender name for received messages
        if (!isOwn && showSenderInfo) ...[
          _buildSenderInfo(context),
          SizedBox(height: 4),
        ],

        // Large emoji display
        Text(TextUtils.safeEmoji(message.content), style: TextStyle(fontSize: 48, height: 1.0)),
      ],
    );
  }

  Widget _buildSenderInfo(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TextUtils.safeText(message.senderName),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF06aeef)
                  : Color(0xFF003f9b),
            ),
          ),
          // Role icon for Admin and Owner only
          if (message.senderRole != null &&
              (message.senderRole!.toUpperCase() == 'ADMIN' ||
                  message.senderRole!.toUpperCase() == 'OWNER')) ...[
            SizedBox(width: 4),
            Icon(
              message.senderRole!.toUpperCase() == 'OWNER'
                  ? Icons.star
                  : Icons.shield,
              size: 12,
              color: message.senderRole!.toUpperCase() == 'OWNER'
                  ? Colors.orange
                  : Colors.purple,
            ),
          ],
        ],
      ),
    );
  }
}
