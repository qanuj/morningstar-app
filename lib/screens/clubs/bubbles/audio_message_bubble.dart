import 'package:flutter/material.dart';
import '../../../models/club_message.dart';
import '../../../models/message_status.dart';
import '../../../widgets/audio_player_widget.dart';

class AudioMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isFromCurrentUser;
  final VoidCallback? onReply;
  final VoidCallback? onReact;

  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.onReply,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment:
            isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromCurrentUser) ...[
            // Sender's profile picture
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage: message.senderProfilePicture?.isNotEmpty == true
                  ? NetworkImage(message.senderProfilePicture!)
                  : null,
              child: message.senderProfilePicture?.isNotEmpty != true
                  ? Text(
                      message.senderName.isNotEmpty
                          ? message.senderName[0].toUpperCase()
                          : '?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            SizedBox(width: 8),
          ],
          
          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isFromCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Sender name (for group chats)
                if (!isFromCurrentUser)
                  Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // Audio player bubble
                GestureDetector(
                  onLongPress: onReact,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                      minWidth: 200,
                    ),
                    child: message.audio != null
                        ? AudioPlayerWidget(
                            audioPath: message.audio!.url,
                            isFromCurrentUser: isFromCurrentUser,
                          )
                        : Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isFromCurrentUser
                                  ? Color(0xFF003f9b)
                                  : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: isFromCurrentUser
                                      ? Colors.white
                                      : (isDarkMode ? Colors.white : Colors.black87),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Audio unavailable',
                                  style: TextStyle(
                                    color: isFromCurrentUser
                                        ? Colors.white
                                        : (isDarkMode ? Colors.white : Colors.black87),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                // Message timestamp and status
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: isFromCurrentUser ? 0 : 12,
                    right: isFromCurrentUser ? 12 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Timestamp
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      
                      // Message status (for sent messages)
                      if (isFromCurrentUser) ...[
                        SizedBox(width: 4),
                        Icon(
                          message.status == MessageStatus.sent
                              ? Icons.check
                              : message.status == MessageStatus.delivered
                                  ? Icons.done_all
                                  : message.status == MessageStatus.read
                                      ? Icons.done_all
                                      : Icons.schedule,
                          size: 14,
                          color: message.status == MessageStatus.read
                              ? Color(0xFF06aeef)
                              : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (isFromCurrentUser) ...[
            SizedBox(width: 8),
            // Current user's profile picture
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF003f9b),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Today - show time
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour == 0 ? 12 : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      // Yesterday
      return 'Yesterday';
    } else {
      // Other dates
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}