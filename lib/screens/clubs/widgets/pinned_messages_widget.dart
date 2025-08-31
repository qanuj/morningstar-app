import 'package:duggy/models/message_image.dart';
import 'package:flutter/material.dart';
import '../../../models/club_message.dart';

class PinnedMessagesWidget extends StatelessWidget {
  final List<ClubMessage> pinnedMessages;
  final Function(ClubMessage) onMessageTap;
  final Function(ClubMessage) onUnpinMessage;

  const PinnedMessagesWidget({
    super.key,
    required this.pinnedMessages,
    required this.onMessageTap,
    required this.onUnpinMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (pinnedMessages.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: pinnedMessages.length,
              itemBuilder: (context, index) {
                return _buildPinnedMessageItem(
                  context,
                  pinnedMessages[index],
                  index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.push_pin, size: 18, color: Color(0xFF06aeef)),
          SizedBox(width: 8),
          Text(
            'Pinned Messages',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF06aeef),
            ),
          ),
          Spacer(),
          Text(
            '${pinnedMessages.length}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageItem(
    BuildContext context,
    ClubMessage message,
    int index,
  ) {
    return GestureDetector(
      onTap: () => onMessageTap(message),
      child: Container(
        width: 200,
        margin: EdgeInsets.only(right: 12, bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF06aeef).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with sender info and unpin button
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF06aeef),
                        ),
                      ),
                      if (message.senderRole != null &&
                          (message.senderRole!.toUpperCase() == 'ADMIN' ||
                              message.senderRole!.toUpperCase() ==
                                  'OWNER')) ...[
                        SizedBox(width: 4),
                        Icon(
                          message.senderRole!.toUpperCase() == 'OWNER'
                              ? Icons.star
                              : Icons.shield,
                          size: 10,
                          color: message.senderRole!.toUpperCase() == 'OWNER'
                              ? Colors.orange
                              : Colors.purple,
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onUnpinMessage(message),
                  child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Message content
            Expanded(child: _buildMessageContent(message, context)),

            // Footer with timestamp and indicator
            Row(
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Spacer(),
                _buildPinnedIndicator(pinnedMessages.length, index),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ClubMessage message, BuildContext context) {
    if (message.pictures.isNotEmpty) {
      return _buildPinnedMessageImages(message.pictures);
    } else if (message.content.isNotEmpty) {
      return Text(
        message.content,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    } else if (message.documents.isNotEmpty) {
      return Row(
        children: [
          Icon(Icons.insert_drive_file, size: 16, color: Colors.grey[600]),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              message.documents.first.filename,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      return Text(
        'No content',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }

  Widget _buildPinnedMessageImages(List<MessageImage> pictures) {
    if (pictures.isEmpty) return SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Image.network(
            pictures.first.url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: Icon(Icons.broken_image, color: Colors.grey[600]),
              );
            },
          ),
          if (pictures.length > 1)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${pictures.length - 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPinnedIndicator(int totalCount, int currentIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalCount > 5 ? 5 : totalCount, (index) {
        return Container(
          margin: EdgeInsets.only(left: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: index == currentIndex
                ? Color(0xFF06aeef)
                : Colors.grey.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.push_pin_outlined, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No pinned messages',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Long press on any message to pin it',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
