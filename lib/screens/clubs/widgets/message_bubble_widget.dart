import 'package:duggy/models/message_reply.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/club_message.dart';
import '../../../models/message_status.dart';
import '../../../providers/user_provider.dart';
import 'message_content_widget.dart';
import 'message_status_widget.dart';
import 'message_reactions_widget.dart';

class MessageBubbleWidget extends StatelessWidget {
  final ClubMessage message;
  final bool showSenderInfo;
  final bool isLastFromSender;
  final Function(ClubMessage) onShowMessageOptions;
  final Function(String) onToggleSelection;
  final Function(ClubMessage) onShowErrorDialog;
  final Function(dynamic, ClubMessage, bool) onHandleSlideGesture;
  final Function(dynamic, ClubMessage, bool) onHandleSlideEnd;
  final bool isSelectionMode;
  final Set<String> selectedMessageIds;
  final String? slidingMessageId;
  final double slideOffset;
  final Function(ClubMessage) isCurrentlyPinned;
  final String Function(DateTime) formatMessageTime;

  const MessageBubbleWidget({
    Key? key,
    required this.message,
    required this.showSenderInfo,
    required this.isLastFromSender,
    required this.onShowMessageOptions,
    required this.onToggleSelection,
    required this.onShowErrorDialog,
    required this.onHandleSlideGesture,
    required this.onHandleSlideEnd,
    required this.isSelectionMode,
    required this.selectedMessageIds,
    required this.slidingMessageId,
    required this.slideOffset,
    required this.isCurrentlyPinned,
    required this.formatMessageTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOwn =
        message.senderId ==
        Provider.of<UserProvider>(context, listen: false).user?.id;

    return Transform.translate(
      offset: Offset(
        slidingMessageId == message.id
            ? (isOwn ? -slideOffset : slideOffset)
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
            _buildReplyInfo(message.replyTo!, isOwn, context),

          GestureDetector(
            onTap: message.deleted
                ? null
                : isSelectionMode
                ? () => onToggleSelection(message.id)
                : message.status == MessageStatus.failed
                ? () => onShowErrorDialog(message)
                : () => onShowMessageOptions(message),
            onLongPress: (isSelectionMode || message.deleted)
                ? null
                : () => onShowMessageOptions(message),
            onPanUpdate: (isSelectionMode || message.deleted)
                ? null
                : (details) => onHandleSlideGesture(details, message, isOwn),
            onPanEnd: (isSelectionMode || message.deleted)
                ? null
                : (details) => onHandleSlideEnd(details, message, isOwn),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: selectedMessageIds.contains(message.id)
                    ? Color(0xFF003f9b).withOpacity(0.3)
                    : _getBubbleColor(context, isOwn, message),
                borderRadius: _getBubbleBorderRadius(
                  showSenderInfo,
                  isLastFromSender,
                  isOwn,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 1,
                    spreadRadius: 0.5,
                    offset: Offset(0, 1),
                  ),
                ],
                border: message.status == MessageStatus.failed
                    ? Border.all(color: Colors.red.withOpacity(0.5), width: 1)
                    : null,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 80, // Minimum width for timestamp overlay
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: 18,
                      ), // Space for timestamp overlay
                      child: Column(
                        crossAxisAlignment: isOwn
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          // Sender name inside bubble for received messages
                          if (!isOwn && showSenderInfo)
                            _buildSenderInfo(context, message),

                          // Message content
                          MessageContentWidget(message: message, isOwn: isOwn),
                        ],
                      ),
                    ),
                    // Timestamp/Status overlay at bottom right
                    Positioned(
                      bottom: 4,
                      right: 8,
                      child: _buildTimestampOverlay(context, message, isOwn),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Reactions display (not shown for deleted messages)
          if (message.reactions.isNotEmpty && !message.deleted) ...[
            SizedBox(height: 4),
            MessageReactionsWidget(message: message),
          ],
        ],
      ),
    );
  }

  Widget _buildSenderInfo(BuildContext context, ClubMessage message) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.senderName,
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
    );
  }

  Widget _buildTimestampOverlay(
    BuildContext context,
    ClubMessage message,
    bool isOwn,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Star icon (first)
          if (isOwn && message.starred.isStarred) ...[
            Icon(Icons.star, size: 10, color: Colors.white.withOpacity(0.9)),
            SizedBox(width: 3),
          ],
          // Pin icon (second)
          if (isOwn && isCurrentlyPinned(message)) ...[
            Icon(
              Icons.push_pin,
              size: 10,
              color: Colors.white.withOpacity(0.9),
            ),
            SizedBox(width: 3),
          ],
          // Time (third)
          Text(
            formatMessageTime(message.createdAt),
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          // Status ticks (fourth) - only for own messages
          if (isOwn) ...[
            SizedBox(width: 3),
            MessageStatusWidget(
              message: message,
              overrideColor: Colors.white.withOpacity(0.9),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyInfo(MessageReply reply, bool isOwn, BuildContext context) {
    // Implementation for reply info - this would need to be extracted from original file
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      child: Text(
        'Reply to: ${reply.senderName}',
        style: TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }

  Color _getBubbleColor(BuildContext context, bool isOwn, ClubMessage message) {
    if (isOwn) {
      if (message.status == MessageStatus.failed) {
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.red[800]!
            : Colors.red.withOpacity(0.7);
      }
      return Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF1E3A8A)
          : Color(0xFFE3F2FD);
    } else {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]!
          : Theme.of(context).cardColor;
    }
  }

  BorderRadius _getBubbleBorderRadius(
    bool showSenderInfo,
    bool isLastFromSender,
    bool isOwn,
  ) {
    return BorderRadius.only(
      topLeft: Radius.circular(showSenderInfo && !isOwn ? 2 : 7.5),
      topRight: Radius.circular(showSenderInfo && isOwn ? 2 : 7.5),
      bottomLeft: Radius.circular(isOwn ? 7.5 : (isLastFromSender ? 7.5 : 2)),
      bottomRight: Radius.circular(isOwn ? (isLastFromSender ? 7.5 : 2) : 7.5),
    );
  }
}
