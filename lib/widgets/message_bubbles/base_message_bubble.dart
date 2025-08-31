import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';

/// Base message bubble that provides the container and meta overlay for all message types
class BaseMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final Widget content;
  final bool isPinned;
  final bool isSelected;
  final bool isTransparent;
  final Color? customColor;
  final bool showMetaOverlay;

  const BaseMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.content,
    required this.isPinned,
    this.isSelected = false,
    this.isTransparent = false,
    this.customColor,
    this.showMetaOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isOwn
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Message bubble
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: isTransparent
              ? null
              : BoxDecoration(
                  color: _getBubbleColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: message.status == MessageStatus.failed
                      ? Border.all(color: Colors.red, width: 1)
                      : null,
                ),
          child: Stack(
            children: [
              // Message content
              Padding(
                padding: showMetaOverlay
                    ? EdgeInsets.only(bottom: 20) // Space for meta overlay
                    : EdgeInsets.zero, // No extra space if no overlay
                child: content,
              ),

              // Meta overlay (pin, star, time, tick) at bottom right
              if (showMetaOverlay)
                Positioned(
                  bottom: 25,
                  right: 5,
                  child: _buildMetaOverlay(context),
                ),
            ],
          ),
        ),

        // Reactions display (below the bubble)
        if (message.reactions.isNotEmpty) ...[
          SizedBox(height: 4),
          _buildReactionsDisplay(context),
        ],
      ],
    );
  }

  Color _getBubbleColor(BuildContext context) {
    // Transparent bubbles have no background color
    if (isTransparent) {
      return Colors.transparent;
    }

    // Custom color overrides everything except transparent
    if (customColor != null) {
      return customColor!;
    }

    // Selection state overrides other colors
    if (isSelected) {
      return Color(0xFF003f9b).withOpacity(0.3);
    }

    if (message.status == MessageStatus.failed) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.red[800]!
          : Colors.red.withOpacity(0.7);
    }

    return isOwn
        ? (Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E3A8A)
              : Color(0xFFE3F2FD))
        : (Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : Colors.white);
  }

  Widget _buildMetaOverlay(BuildContext context) {
    final iconColor = isOwn
        ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.7)
              : Colors.black.withOpacity(0.65))
        : (Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.7)
              : Colors.black.withOpacity(0.6));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Star icon (first)
          if (isOwn && message.starred.isStarred) ...[
            Icon(Icons.star, size: 10, color: iconColor),
            SizedBox(width: 4),
          ],

          // Pin icon (second)
          if (isOwn && isPinned) ...[
            Icon(Icons.push_pin, size: 10, color: iconColor),
            SizedBox(width: 4),
          ],

          // Time (third)
          Text(
            _formatMessageTime(message.createdAt),
            style: TextStyle(fontSize: 10, color: iconColor),
          ),

          // Status tick (fourth - rightmost) - only for own messages
          if (isOwn) ...[SizedBox(width: 4), _buildStatusIcon(iconColor)],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Color iconColor) {
    IconData icon;
    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        iconColor = Colors.blue;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        iconColor = Colors.red;
        break;
    }

    return Icon(icon, size: 10, color: iconColor);
  }

  Widget _buildReactionsDisplay(BuildContext context) {
    if (message.reactions.isEmpty) return SizedBox.shrink();

    // Group reactions by emoji
    Map<String, List<String>> groupedReactions = {};
    for (var reaction in message.reactions) {
      if (groupedReactions.containsKey(reaction.emoji)) {
        groupedReactions[reaction.emoji]!.add(reaction.userName);
      } else {
        groupedReactions[reaction.emoji] = [reaction.userName];
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: groupedReactions.entries.map((entry) {
        final emoji = entry.key;
        final users = entry.value;
        final count = users.length;

        return GestureDetector(
          onTap: () {
            // TODO: Add reaction tap functionality (show users who reacted)
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[600]!
                    : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: TextStyle(fontSize: 14)),
                if (count > 1) ...[
                  SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.8)
                          : Colors.black.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
