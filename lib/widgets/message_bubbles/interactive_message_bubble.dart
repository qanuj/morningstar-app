import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/message_reaction.dart';
import '../../models/starred_info.dart';
import '../../services/chat_api_service.dart';
import '../../providers/user_provider.dart';
import 'message_bubble_factory.dart';

/// A wrapper for BaseMessageBubble that adds interactive functionality
class InteractiveMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final String clubId;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
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
    required this.clubId,
    required this.isOwn,
    required this.isPinned,
    required this.showSenderInfo,
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
  State<InteractiveMessageBubble> createState() => _InteractiveMessageBubbleState();
}

class _InteractiveMessageBubbleState extends State<InteractiveMessageBubble> {
  // Local state for immediate UI feedback
  late bool _localIsStarred;
  
  @override
  void initState() {
    super.initState();
    _localIsStarred = widget.message.starred.isStarred;
  }
  
  @override
  void didUpdateWidget(InteractiveMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state when widget updates
    if (oldWidget.message.starred.isStarred != widget.message.starred.isStarred) {
      _localIsStarred = widget.message.starred.isStarred;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleMessageTap(context),
      onLongPress: () => _handleMessageLongPress(context),
      child: MessageBubbleFactory(
        message: _createMessageWithLocalState(),
        isOwn: widget.isOwn,
        isDeleted: widget.message.deleted,
        isPinned: widget.isPinned,
        isSelected: widget.isSelected,
        showSenderInfo: widget.showSenderInfo,
        onReactionRemoved: _handleReactionRemoved,
        onReactionAdded: _handleReactionAdded,
        onReplyToMessage: _handleReplyToMessage,
        onToggleStarMessage: _handleToggleStarMessage,
        onTogglePinMessage: _handleTogglePinMessage,
        onDeleteMessage: _handleDeleteMessage,
        onShowMessageInfo: _handleShowMessageInfo,
        canPinMessages: widget.canPinMessages,
        canDeleteMessages: widget.canDeleteMessages,
        isSelectionMode: widget.isSelectionMode,
      ),
    );
  }
  
  ClubMessage _createMessageWithLocalState() {
    // Create a message with local starred state for immediate UI feedback
    if (_localIsStarred != widget.message.starred.isStarred) {
      return widget.message.copyWith(
        starred: StarredInfo(
          isStarred: _localIsStarred,
          starredAt: _localIsStarred ? DateTime.now().toIso8601String() : null,
        ),
      );
    }
    return widget.message;
  }

  void _handleMessageTap(BuildContext context) {
    if (widget.message.deleted) return;

    if (widget.isSelectionMode) {
      // In selection mode, tap to select/deselect
      if (widget.onToggleSelection != null) {
        widget.onToggleSelection!(widget.message.id);
      }
    } else if (widget.message.status == MessageStatus.failed) {
      // Failed messages show retry dialog
      _showRetryDialog(context);
    } else if (widget.onMessageTap != null) {
      // Custom tap handler
      widget.onMessageTap!(widget.message);
    } else {
      // Default behavior - show message options
      _showMessageOptions(context);
    }
  }

  void _handleMessageLongPress(BuildContext context) {
    if (widget.message.deleted || widget.isSelectionMode) return;

    if (widget.onMessageLongPress != null) {
      widget.onMessageLongPress!(widget.message);
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
    if (widget.message.deleted) return;

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
                          } else {
                            _handleReactionAdded(widget.message, emoji);
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
                _handleReplyToMessage(widget.message);
              },
            ),
            _buildOptionTile(
              context: context,
              icon: Icons.copy,
              title: 'Copy',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: widget.message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            // Only show Info option for user's own messages
            if (widget.isOwn)
              _buildOptionTile(
                context: context,
                icon: Icons.info_outline,
                title: 'Info',
                onTap: () {
                  Navigator.pop(context);
                  _handleShowMessageInfo(widget.message);
                },
              ),
            _buildOptionTile(
              context: context,
              icon: _localIsStarred ? Icons.star : Icons.star_outline,
              title: _localIsStarred ? 'Unstar' : 'Star',
              onTap: () {
                Navigator.pop(context);
                _handleToggleStarMessage(widget.message);
              },
            ),
            // Only show pin option if user has permission
            if (widget.canPinMessages)
              _buildOptionTile(
                context: context,
                icon: widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                title: widget.isPinned ? 'Unpin' : 'Pin',
                onTap: () {
                  Navigator.pop(context);
                  _handleTogglePinMessage(widget.message);
                },
              ),
            // Show delete option if: 1) User has general delete permissions, OR 2) It's their own message, OR 3) User is admin/owner
            if (_canDeleteThisMessage())
              _buildOptionTile(
                context: context,
                icon: Icons.delete,
                title: 'Delete',
                titleColor: Colors.red,
                iconColor: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _handleDeleteMessage(widget.message);
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

  // Handler methods for self-contained interactions
  Future<void> _handleReactionAdded(ClubMessage message, String emoji) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    try {
      final reaction = MessageReaction(
        emoji: emoji,
        users: [ReactionUser(userId: user.id, name: user.name)],
        count: 1,
      );

      await ChatApiService.addReaction(widget.clubId, message.id, reaction);
      
      // Show success feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $emoji reaction'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error adding reaction: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reaction'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleReactionRemoved(String messageId, String emoji, String userId) async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.user;
    
    if (currentUser == null || userId != currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can only remove your own reactions'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await ChatApiService.removeReaction(widget.clubId, messageId, emoji);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $emoji reaction'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error removing reaction: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove reaction'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleReplyToMessage(ClubMessage message) {
    // Show a snackbar since we don't have direct access to reply functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reply functionality requires parent widget integration'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleToggleStarMessage(ClubMessage message) async {
    // Provide immediate UI feedback by updating local state
    setState(() {
      _localIsStarred = !_localIsStarred;
    });
    
    try {
      if (message.starred.isStarred) {
        await ChatApiService.unstarMessage(widget.clubId, message.id);
      } else {
        await ChatApiService.starMessage(widget.clubId, message.id);
      }
      
      // Success - the UI already shows the updated state
      debugPrint('✅ Star toggled successfully for message: ${message.id}');
    } catch (e) {
      debugPrint('❌ Error toggling star: $e');
      // On error, revert the local state
      setState(() {
        _localIsStarred = !_localIsStarred;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${message.starred.isStarred ? 'unstar' : 'star'} message'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleTogglePinMessage(ClubMessage message) async {
    try {
      if (widget.isPinned) {
        await ChatApiService.unpinMessage(widget.clubId, message.id);
      } else {
        // Show pin duration dialog
        final duration = await _showPinDurationDialog(context);
        if (duration != null) {
          await ChatApiService.pinMessage(widget.clubId, message.id, {'durationHours': duration});
        }
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isPinned ? 'Message unpinned' : 'Message pinned'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error toggling pin: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update pin'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleDeleteMessage(ClubMessage message) {
    // Trigger selection mode and select this message
    if (widget.onToggleSelection != null) {
      widget.onToggleSelection!(message.id);
    }
  }

  void _handleShowMessageInfo(ClubMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sent: ${_formatDateTime(message.createdAt)}'),
              if (message.deliveredAt != null)
                Text('Delivered: ${_formatDateTime(message.deliveredAt!)}'),
              if (message.readAt != null)
                Text('Read: ${_formatDateTime(message.readAt!)}'),
              Text('Status: ${message.status.name}'),
              if (message.reactions.isNotEmpty) ...[
                SizedBox(height: 8),
                Text('Reactions: ${message.reactions.length}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<int?> _showPinDurationDialog(BuildContext context) async {
    return await showDialog<int>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2D3748)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose pin duration',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 20),
              _buildPinDurationOption('24 hours', 24),
              _buildPinDurationOption('7 days', 24 * 7),
              _buildPinDurationOption('30 days', 24 * 30),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDurationOption(String label, int hours) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      child: TextButton(
        onPressed: () => Navigator.pop(context, hours),
        child: Text(label),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Check if the current user can delete this message
  /// Returns true if:
  /// 1. User has general delete permissions (canDeleteMessages - for admins/owners), OR
  /// 2. It's the user's own message
  bool _canDeleteThisMessage() {
    // Admins and owners can delete any message
    if (widget.canDeleteMessages) {
      return true;
    }

    // Users can always delete their own messages
    if (widget.isOwn) {
      return true;
    }
    
    return false;
  }
}
