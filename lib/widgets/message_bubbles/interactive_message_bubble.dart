import 'package:duggy/models/club.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/message_reaction.dart';
import '../../models/starred_info.dart';
import '../../services/chat_api_service.dart';
import '../../providers/user_provider.dart';
import '../../screens/clubs/message_info_screen.dart';
import '../inline_reaction_picker.dart';
import 'message_bubble_factory.dart';

/// A wrapper for BaseMessageBubble that adds interactive functionality
class InteractiveMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final Club club;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final bool isLastFromSender;
  final bool isTransparent;
  final Color? customColor;
  final bool showMetaOverlay;
  final bool showShadow;
  final double? overlayBottomPosition;
  final List<Map<String, dynamic>> clubMembers;

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
  final Function(String messageId, int mediaIndex)? onMediaTap;

  const InteractiveMessageBubble({
    super.key,
    required this.message,
    required this.club,
    required this.isOwn,
    required this.isPinned,
    required this.showSenderInfo,
    this.isLastFromSender = false,
    this.clubMembers = const [],
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
    this.onMediaTap,
  });

  @override
  State<InteractiveMessageBubble> createState() =>
      _InteractiveMessageBubbleState();
}

class _InteractiveMessageBubbleState extends State<InteractiveMessageBubble> {
  // Local state for immediate UI feedback
  late bool _localIsStarred;
  late List<MessageReaction> _localReactions;

  @override
  void initState() {
    super.initState();
    _localIsStarred = widget.message.starred.isStarred;
    _localReactions = List.from(widget.message.reactions);
  }

  @override
  void didUpdateWidget(InteractiveMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state when widget updates
    if (oldWidget.message.starred.isStarred !=
        widget.message.starred.isStarred) {
      _localIsStarred = widget.message.starred.isStarred;
    }
    if (oldWidget.message.reactions != widget.message.reactions) {
      _localReactions = List.from(widget.message.reactions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MessageOptionsOverlay(
      isOwnMessage: widget.isOwn,
      message: _createMessageWithLocalState(),
      clubMembers: widget.clubMembers,
      onReactionSelected: (emoji) =>
          _handleReactionAdded(_createMessageWithLocalState(), emoji),
      onReply: () =>
          widget.onReplyToMessage?.call(_createMessageWithLocalState()),
      onForward: () => {}, // TODO: implement forward
      onSelectMessage: () => {}, // TODO: implement select
      onCopy: () => _handleCopyMessage(),
      onStar: () => _handleToggleStarMessage(_createMessageWithLocalState()),
      onDelete: () => _handleDeleteMessage(_createMessageWithLocalState()),
      onMore: () => _showMessageOptions(context),
      onInfo: () => _handleShowMessageInfoScreen(),
      onPin: () => _handleTogglePinMessage(_createMessageWithLocalState()),
      canDelete: widget.canDeleteMessages,
      isDeleted: widget.message.deleted,
      messageContent: _createMessageWithLocalState().content,
      child: GestureDetector(
        onTap: () => _handleMessageTap(context),
        child: MessageBubbleFactory(
          message: _createMessageWithLocalState(),
          isOwn: widget.isOwn,
          isDeleted: widget.message.deleted,
          isPinned: widget.isPinned,
          isSelected: widget.isSelected,
          showSenderInfo: widget.showSenderInfo,
          isLastFromSender: widget.isLastFromSender,
          onReactionRemoved: _handleReactionRemoved,
          onReactionAdded: _handleReactionAdded,
          onReplyToMessage: _handleReplyToMessage,
          onToggleStarMessage: _handleToggleStarMessage,
          onTogglePinMessage: _handleTogglePinMessage,
          onDeleteMessage: _handleDeleteMessage,
          onShowMessageInfo: _handleShowMessageInfo,
          onPinMessage: widget.onTogglePinMessage,
          canPinMessages: widget.canPinMessages,
          canDeleteMessages: widget.canDeleteMessages,
          isSelectionMode: widget.isSelectionMode,
          club: widget.club,
          onMediaTap: widget.onMediaTap,
        ),
      ),
    );
  }

  ClubMessage _createMessageWithLocalState() {
    // Create a message with local starred state and reactions for immediate UI feedback
    bool needsUpdate = false;
    ClubMessage updatedMessage = widget.message;

    if (_localIsStarred != widget.message.starred.isStarred) {
      updatedMessage = updatedMessage.copyWith(
        starred: StarredInfo(
          isStarred: _localIsStarred,
          starredAt: _localIsStarred ? DateTime.now().toIso8601String() : null,
        ),
      );
      needsUpdate = true;
    }

    if (_localReactions != widget.message.reactions) {
      updatedMessage = updatedMessage.copyWith(reactions: _localReactions);
      needsUpdate = true;
    }

    return needsUpdate ? updatedMessage : widget.message;
  }

  void _handleMessageTap(BuildContext context) {
    if (widget.message.deleted) return;

    if (widget.isSelectionMode) {
      // In selection mode, tap to select/deselect
      if (widget.onToggleSelection != null) {
        widget.onToggleSelection!(widget.message.id);
      }
      return; // Don't show options in selection mode
    } else if (widget.message.status == MessageStatus.failed) {
      // Failed messages show retry dialog
      _showRetryDialog(context);
      return; // Don't show options for failed messages
    } else if (widget.onMessageTap != null) {
      // Custom tap handler
      widget.onMessageTap!(widget.message);
      return; // Custom handler takes precedence
    }

    // Default behavior - show reaction drawer/options on tap
    // This will be handled by the outer GestureDetector in _MessageOptionsOverlay
  }

  // Long press behavior has been replaced with inline reaction picker
  // Options menu is now accessible via double tap

  void _handleCopyMessage() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
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
    return;
  }

  // Handler methods for self-contained interactions
  Future<void> _handleReactionAdded(ClubMessage message, String emoji) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    // Store original reactions for potential revert
    final originalReactions = List<MessageReaction>.from(_localReactions);

    // Check if user already has this exact reaction (for toggle behavior)
    final hasThisReaction = _localReactions.any(
      (r) => r.emoji == emoji && r.users.any((u) => u.userId == user.id),
    );

    if (hasThisReaction) {
      // Toggle off: User clicked emoji they already have - remove their reaction
      setState(() {
        _localReactions.removeWhere(
          (r) => r.emoji == emoji && r.users.any((u) => u.userId == user.id),
        );

        // Also remove user from other emoji reactions if they exist
        for (int i = 0; i < _localReactions.length; i++) {
          final reaction = _localReactions[i];
          final updatedUsers = reaction.users
              .where((u) => u.userId != user.id)
              .toList();
          if (updatedUsers.length != reaction.users.length) {
            if (updatedUsers.isEmpty) {
              _localReactions.removeAt(i);
              i--; // Adjust index after removal
            } else {
              _localReactions[i] = MessageReaction(
                emoji: reaction.emoji,
                users: updatedUsers,
                count: updatedUsers.length,
                createdAt: reaction.createdAt,
              );
            }
          }
        }
      });

      try {
        await ChatApiService.removeReaction(widget.club.id, message.id);
        debugPrint('✅ Reaction removed successfully');
      } catch (e) {
        debugPrint('❌ Error removing reaction: $e');
        // Revert optimistic update on error
        setState(() {
          _localReactions = originalReactions;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove reaction'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // Add/Replace: User clicked new emoji - let server handle replacement logic
      final newReaction = MessageReaction(
        emoji: emoji,
        users: [
          ReactionUser(
            userId: user.id,
            name: user.name,
            profilePicture: user.profilePicture,
          ),
        ],
        count: 1,
      );

      // Optimistically update UI: remove user from all reactions, then add new one
      setState(() {
        // Remove user from any existing reactions
        for (int i = 0; i < _localReactions.length; i++) {
          final reaction = _localReactions[i];
          final updatedUsers = reaction.users
              .where((u) => u.userId != user.id)
              .toList();
          if (updatedUsers.length != reaction.users.length) {
            if (updatedUsers.isEmpty) {
              _localReactions.removeAt(i);
              i--; // Adjust index after removal
            } else {
              _localReactions[i] = MessageReaction(
                emoji: reaction.emoji,
                users: updatedUsers,
                count: updatedUsers.length,
                createdAt: reaction.createdAt,
              );
            }
          }
        }

        // Add new reaction
        final existingEmojiIndex = _localReactions.indexWhere(
          (r) => r.emoji == emoji,
        );
        if (existingEmojiIndex != -1) {
          // Add to existing emoji reaction
          final existing = _localReactions[existingEmojiIndex];
          final updatedUsers = [
            ...existing.users,
            ReactionUser(
              userId: user.id,
              name: user.name,
              profilePicture: user.profilePicture,
            ),
          ];
          _localReactions[existingEmojiIndex] = MessageReaction(
            emoji: existing.emoji,
            users: updatedUsers,
            count: updatedUsers.length,
            createdAt: existing.createdAt,
          );
        } else {
          // Create new emoji reaction
          _localReactions.add(newReaction);
        }
      });

      try {
        await ChatApiService.addReaction(
          widget.club.id,
          message.id,
          newReaction,
        );
        debugPrint('✅ Reaction added successfully');
      } catch (e) {
        debugPrint('❌ Error adding reaction: $e');
        // Revert optimistic update on error
        setState(() {
          _localReactions = originalReactions;
        });
        if (mounted) {
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
  }

  Future<void> _handleReactionRemoved(
    String messageId,
    String emoji,
    String userId,
  ) async {
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

    // Store original reactions for potential revert
    final originalReactions = List<MessageReaction>.from(_localReactions);

    // Optimistically remove the reaction for immediate UI feedback
    setState(() {
      final reactionIndex = _localReactions.indexWhere(
        (r) => r.emoji == emoji && r.users.any((u) => u.userId == userId),
      );

      if (reactionIndex != -1) {
        final reaction = _localReactions[reactionIndex];
        if (reaction.users.length <= 1) {
          // Remove entire reaction if this was the only user
          _localReactions.removeAt(reactionIndex);
        } else {
          // Remove just this user from the reaction
          final updatedUsers = reaction.users
              .where((u) => u.userId != userId)
              .toList();
          _localReactions[reactionIndex] = MessageReaction(
            emoji: reaction.emoji,
            users: updatedUsers,
            count: updatedUsers.length,
            createdAt: reaction.createdAt,
          );
        }
      }
    });

    try {
      await ChatApiService.removeReaction(widget.club.id, messageId);

      // Success - no snackbar needed, UI already updated
      debugPrint('✅ Reaction removed successfully');
    } catch (e) {
      debugPrint('❌ Error removing reaction: $e');

      // Revert optimistic update on error
      setState(() {
        _localReactions = originalReactions;
      });

      if (mounted) {
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
        await ChatApiService.unstarMessage(widget.club.id, message.id);
      } else {
        await ChatApiService.starMessage(widget.club.id, message.id);
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
            content: Text(
              'Failed to ${message.starred.isStarred ? 'unstar' : 'star'} message',
            ),
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
        await ChatApiService.unpinMessage(widget.club.id, message.id);
        debugPrint('✅ Message unpinned successfully');
      } else {
        // Show pin duration dialog
        final duration = await _showPinDurationDialog(context);
        if (duration != null) {
          await ChatApiService.pinMessage(widget.club.id, message.id, {
            'durationHours': duration,
          });
          debugPrint('✅ Message pinned successfully');
        }
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
    // For already deleted messages, delete immediately without confirmation (cleanup)
    if (message.deleted) {
      widget.onDeleteMessage?.call(message);
      return;
    }

    // For normal messages, keep existing confirmation behavior
    // Trigger selection mode and select this message
    if (widget.onToggleSelection != null) {
      widget.onToggleSelection!(message.id);
    }
  }

  void _handleShowMessageInfo(ClubMessage message) {
    // Unfocus any text fields to prevent keyboard from appearing
    FocusScope.of(context).unfocus();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageInfoScreen(
          message: message,
          clubMembers: widget.clubMembers,
          club: widget.club,
        ),
      ),
    );
  }

  void _handleShowMessageInfoScreen() {
    // Unfocus any text fields to prevent keyboard from appearing
    FocusScope.of(context).unfocus();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageInfoScreen(
          message: _createMessageWithLocalState(),
          clubMembers: widget.clubMembers,
          club: widget.club,
        ),
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
}

/// Wrapper overlay to handle enhanced message options with blur background
class _MessageOptionsOverlay extends StatefulWidget {
  final Widget child;
  final Function(String emoji) onReactionSelected;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onSelectMessage;
  final VoidCallback onCopy;
  final VoidCallback onStar;
  final VoidCallback onDelete;
  final VoidCallback onMore;
  final VoidCallback onInfo;
  final VoidCallback onPin;
  final bool isOwnMessage;
  final bool canDelete;
  final bool isDeleted;
  final String? messageContent;
  final ClubMessage? message;
  final List<Map<String, dynamic>>? clubMembers;

  const _MessageOptionsOverlay({
    required this.child,
    required this.onReactionSelected,
    required this.onReply,
    required this.onForward,
    required this.onSelectMessage,
    required this.onCopy,
    required this.onStar,
    required this.onDelete,
    required this.onMore,
    required this.onInfo,
    required this.onPin,
    this.isOwnMessage = false,
    this.canDelete = false,
    this.isDeleted = false,
    this.messageContent,
    this.message,
    this.clubMembers,
  });

  @override
  State<_MessageOptionsOverlay> createState() => _MessageOptionsOverlayState();
}

class _MessageOptionsOverlayState extends State<_MessageOptionsOverlay> {
  OverlayEntry? _overlayEntry;
  bool _isOptionsVisible = false;

  void _showOptions() {
    if (_isOptionsVisible) return;

    _isOptionsVisible = true;
    HapticFeedback.mediumImpact();

    // Calculate message position and size
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => InlineMessageOptions(
        onReactionSelected: (emoji) {
          widget.onReactionSelected(emoji);
          _dismissOptions();
        },
        onDismiss: _dismissOptions,
        onReply: widget.onReply,
        onForward: widget.onForward,
        onSelectMessage: widget.onSelectMessage,
        onCopy: widget.onCopy,
        onStar: widget.onStar,
        onDelete: widget.onDelete,
        onMore: widget.onMore,
        onInfo: widget.onInfo,
        onPin: widget.onPin, // Placeholder for pin action
        messagePosition: position,
        messageSize: size,
        isOwnMessage: widget.isOwnMessage,
        canDelete: widget.canDelete,
        isDeleted: widget.isDeleted,
        messageWidget: widget.child,
        messageContent: widget.messageContent,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _dismissOptions() {
    if (!_isOptionsVisible) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOptionsVisible = false;
  }

  @override
  void dispose() {
    _dismissOptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onLongPress: _showOptions, child: widget.child);
  }
}
