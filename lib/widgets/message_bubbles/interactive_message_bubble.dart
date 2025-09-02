import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import 'base_message_bubble.dart';

/// A wrapper for BaseMessageBubble that adds interactive functionality
class InteractiveMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final Widget content;
  final bool isPinned;
  final bool isSelected;
  final bool isTransparent;
  final Color? customColor;
  final bool showMetaOverlay;
  final bool showShadow;
  final double? overlayBottomPosition;

  // Message interaction callbacks
  final Function(ClubMessage message)? onMessageTap;
  final Function(ClubMessage message)? onMessageLongPress;
  final Function(ClubMessage message, String emoji)? onReactionAdded;
  final Function(ClubMessage message)? onReplyToMessage;
  final Function(ClubMessage message)? onToggleStarMessage;
  final Function(ClubMessage message)? onTogglePinMessage;
  final Function(ClubMessage message)? onDeleteMessage;
  final Function(ClubMessage message)? onShowMessageInfo;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;
  final bool canPinMessages;
  final bool canDeleteMessages;
  final bool isSelectionMode;
  final Function(String messageId)? onToggleSelection;

  const InteractiveMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.content,
    required this.isPinned,
    this.isSelected = false,
    this.isTransparent = false,
    this.customColor,
    this.showMetaOverlay = true,
    this.showShadow = false,
    this.overlayBottomPosition,
    this.onMessageTap,
    this.onMessageLongPress,
    this.onReactionAdded,
    this.onReplyToMessage,
    this.onToggleStarMessage,
    this.onTogglePinMessage,
    this.onDeleteMessage,
    this.onShowMessageInfo,
    this.onReactionRemoved,
    this.canPinMessages = false,
    this.canDeleteMessages = false,
    this.isSelectionMode = false,
    this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleMessageTap(context),
      onLongPress: () => _handleMessageLongPress(context),
      child: BaseMessageBubble(
        message: message,
        isOwn: isOwn,
        content: content,
        isPinned: isPinned,
        isSelected: isSelected,
        isTransparent: isTransparent,
        customColor: customColor,
        showMetaOverlay: showMetaOverlay,
        showShadow: showShadow,
        overlayBottomPosition: overlayBottomPosition,
        onReactionRemoved: onReactionRemoved,
        onReactionAdded: onReactionAdded,
        onReplyToMessage: onReplyToMessage,
        onToggleStarMessage: onToggleStarMessage,
        onTogglePinMessage: onTogglePinMessage,
        onDeleteMessage: onDeleteMessage,
        onShowMessageInfo: onShowMessageInfo,
        canPinMessages: canPinMessages,
        canDeleteMessages: canDeleteMessages,
      ),
    );
  }

  void _handleMessageTap(BuildContext context) {
    if (message.deleted) return;

    if (isSelectionMode) {
      // In selection mode, tap to select/deselect
      if (onToggleSelection != null) {
        onToggleSelection!(message.id);
      }
    } else if (message.status == MessageStatus.failed) {
      // Failed messages show retry dialog
      _showRetryDialog(context);
    } else if (onMessageTap != null) {
      // Custom tap handler
      onMessageTap!(message);
    } else {
      // Default behavior - show message options
      _showMessageOptions(context);
    }
  }

  void _handleMessageLongPress(BuildContext context) {
    if (message.deleted || isSelectionMode) return;

    if (onMessageLongPress != null) {
      onMessageLongPress!(message);
    } else {
      // Default behavior - show message options
      _showMessageOptions(context);
    }
  }

  void _showRetryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message Failed'),
        content: Text('This message failed to send. Would you like to retry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              //Navigator.pop(context);
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    if (message.deleted) return;

    HapticFeedback.lightImpact();
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
                            _showReactionPicker(context);
                          } else if (onReactionAdded != null) {
                            onReactionAdded!(message, emoji);
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
              context: context,
              icon: Icons.reply,
              title: 'Reply',
              onTap: () {
                Navigator.pop(context);
                if (onReplyToMessage != null) {
                  onReplyToMessage!(message);
                }
              },
            ),
            _buildOptionTile(
              context: context,
              icon: Icons.copy,
              title: 'Copy',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            // Only show Info option for user's own messages
            if (isOwn && onShowMessageInfo != null)
              _buildOptionTile(
                context: context,
                icon: Icons.info_outline,
                title: 'Info',
                onTap: () {
                  Navigator.pop(context);
                  onShowMessageInfo!(message);
                },
              ),
            _buildOptionTile(
              context: context,
              icon: message.starred.isStarred ? Icons.star : Icons.star_outline,
              title: message.starred.isStarred ? 'Unstar' : 'Star',
              onTap: () {
                Navigator.pop(context);
                if (onToggleStarMessage != null) {
                  onToggleStarMessage!(message);
                }
              },
            ),
            // Only show pin option if user has permission
            if (canPinMessages)
              _buildOptionTile(
                context: context,
                icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                title: isPinned ? 'Unpin' : 'Pin',
                onTap: () {
                  Navigator.pop(context);
                  if (onTogglePinMessage != null) {
                    onTogglePinMessage!(message);
                  }
                },
              ),
            if (canDeleteMessages)
              _buildOptionTile(
                context: context,
                icon: Icons.delete,
                title: 'Delete',
                titleColor: Colors.red,
                iconColor: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  if (onDeleteMessage != null) {
                    onDeleteMessage!(message);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    // TODO: Implement emoji picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reaction picker coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
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
}
