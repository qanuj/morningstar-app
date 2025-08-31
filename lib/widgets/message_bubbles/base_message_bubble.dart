import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';

/// Base message bubble that provides the container and meta overlay for all message types
class BaseMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final Widget content;
  final bool isPinned;

  const BaseMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.content,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
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
            padding: EdgeInsets.only(bottom: 20), // Space for meta overlay
            child: content,
          ),

          // Meta overlay (pin, star, time, tick) at bottom right
          Positioned(bottom: 4, right: 4, child: _buildMetaOverlay(context)),
        ],
      ),
    );
  }

  Color _getBubbleColor(BuildContext context) {
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
          // Pin icon (first)
          if (isOwn && isPinned) ...[
            Icon(Icons.push_pin, size: 10, color: iconColor),
            SizedBox(width: 4),
          ],

          // Star icon (second)
          if (isOwn && message.starred.isStarred) ...[
            Icon(Icons.star, size: 10, color: iconColor),
            SizedBox(width: 4),
          ],

          // Time (third)
          Text(
            _formatMessageTime(message.createdAt),
            style: TextStyle(fontSize: 10, color: iconColor),
          ),

          // Status tick (fourth) - only for own messages
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
