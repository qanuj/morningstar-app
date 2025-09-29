import 'package:duggy/models/club.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../utils/text_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/club_message.dart';
import '../models/message_reply.dart';
import '../models/message_status.dart';
import '../providers/user_provider.dart';
import 'message_bubbles/self_sending_message_bubble.dart';
import 'message_bubbles/interactive_message_bubble.dart';

/// A complete wrapper widget for displaying message bubbles
/// Handles animations, interactions, slide gestures, and message states
class MessageBubbleWrapper extends StatelessWidget {
  final ClubMessage message;
  final bool showSenderInfo;
  final bool isFirstFromSender;
  final bool isLastFromSender;
  final Club club;

  // Selection mode
  final bool isSelectionMode;
  final Set<String> selectedMessageIds;
  final Function(String messageId) onToggleSelection;

  // Highlighting
  final String? highlightedMessageId;

  // Slide to reply
  final bool isSliding;
  final String? slidingMessageId;
  final double slideOffset;
  final Function(DragUpdateDetails details, ClubMessage message, bool isOwn)
  onSlideUpdate;
  final Function(DragEndDetails details, ClubMessage message, bool isOwn)
  onSlideEnd;

  // Message actions - removed, handled by bubbles themselves

  // Self-sending message callbacks
  final Function(ClubMessage oldMessage, ClubMessage newMessage)?
  onMessageUpdated;
  final Function(String messageId)? onMessageFailed;
  final Function(String messageId)? onRetryMessage;

  // Pending uploads for self-sending messages
  final List<PlatformFile>? pendingUploads;

  // Message interaction callbacks - only keep onReactionRemoved for BaseMessageBubble compatibility
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;
  final Function(ClubMessage message, String emoji)? onReactionAdded;
  final bool canPinMessages;
  final bool canDeleteMessages;
  final List<Map<String, dynamic>> clubMembers;

  // Utility functions
  final Function(ClubMessage message) isCurrentlyPinned;

  // Reply tap callback
  final Function(String messageId)? onReplyTap;

  const MessageBubbleWrapper({
    super.key,
    required this.message,
    required this.showSenderInfo,
    required this.isFirstFromSender,
    required this.isLastFromSender,
    required this.club,
    required this.isSelectionMode,
    required this.selectedMessageIds,
    required this.onToggleSelection,
    this.highlightedMessageId,
    required this.isSliding,
    this.slidingMessageId,
    required this.slideOffset,
    required this.onSlideUpdate,
    required this.onSlideEnd,
    // Removed message option callbacks
    this.onMessageUpdated,
    this.onMessageFailed,
    this.onRetryMessage,
    this.pendingUploads,
    this.onReactionRemoved,
    this.onReactionAdded,
    this.canPinMessages = false,
    this.canDeleteMessages = false,
    this.clubMembers = const [],
    required this.isCurrentlyPinned,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final isOwn = message.senderId == userProvider.user?.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: isLastFromSender ? 12 : 4),
      decoration: highlightedMessageId == message.id
          ? BoxDecoration(
              color: const Color(0xFF06aeef).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: highlightedMessageId == message.id
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: isOwn
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!isOwn && isLastFromSender) _buildSenderAvatar(context),
              if (!isOwn && !isLastFromSender) const SizedBox(width: 34),

              // Message bubble column
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.of(context).size.width *
                        0.65, // Reduced width to make room for error icon
                  ),
                  child: Stack(
                    children: [
                      // Reply icon background (shown during slide)
                      if (isSliding && slidingMessageId == message.id)
                        Positioned(
                          left: 10,
                          top: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF06aeef).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            alignment: Alignment.center,
                            child: AnimatedScale(
                              scale: slideOffset > 40.0 ? 1.2 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              child: Icon(
                                Icons.reply,
                                color: const Color(
                                  0xFF06aeef,
                                ).withOpacity(slideOffset > 40.0 ? 1.0 : 0.7),
                                size: slideOffset > 40.0 ? 32 : 28,
                              ),
                            ),
                          ),
                        ),

                      // Message content with slide animation
                      Transform.translate(
                        offset: Offset(
                          slidingMessageId == message.id ? slideOffset : 0.0,
                          0.0,
                        ),
                        child: Column(
                          crossAxisAlignment: isOwn
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Reply info (if this message is a reply)
                            if (message.replyTo != null) ...[
                              _buildReplyInfo(context, message.replyTo!, isOwn),
                            ] else if (message.content.isNotEmpty) ...[
                              // Debug: Log when a message has no reply
                              Builder(
                                builder: (context) {
                                  return SizedBox.shrink();
                                },
                              ),
                            ],

                            GestureDetector(
                              // Gesture handling moved to individual bubbles
                              onPanUpdate: (isSelectionMode || message.deleted)
                                  ? null
                                  : (details) =>
                                        onSlideUpdate(details, message, isOwn),
                              onPanEnd: (isSelectionMode || message.deleted)
                                  ? null
                                  : (details) =>
                                        onSlideEnd(details, message, isOwn),
                              child:
                                  (message.status == MessageStatus.sending ||
                                      message.status == MessageStatus.failed)
                                  ? SelfSendingMessageBubble(
                                      message: message,
                                      isOwn: isOwn,
                                      isPinned: isCurrentlyPinned(message),
                                      isDeleted: message.deleted,
                                      isSelected: selectedMessageIds.contains(
                                        message.id,
                                      ),
                                      showSenderInfo:
                                          isFirstFromSender || isLastFromSender,
                                      club: club,
                                      pendingUploads: pendingUploads,
                                      onMessageUpdated: onMessageUpdated,
                                      onMessageFailed: onMessageFailed,
                                    )
                                  : _buildInteractiveMessage(isOwn),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Error icon column (only shown for failed messages)
              if (message.status == MessageStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Transform.translate(
                    offset: Offset(
                      slidingMessageId == message.id
                          ? (isOwn ? -slideOffset : slideOffset)
                          : 0.0,
                      0.0,
                    ),
                    child: GestureDetector(
                      onTap: () => onRetryMessage?.call(message.id),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMessage(bool isOwn) {
    return InteractiveMessageBubble(
      message: message,
      club: club,
      isOwn: isOwn,
      isPinned: isCurrentlyPinned(message),
      isSelected: selectedMessageIds.contains(message.id),
      canPinMessages: canPinMessages,
      canDeleteMessages: canDeleteMessages,
      isSelectionMode: isSelectionMode,
      showSenderInfo: isFirstFromSender || isLastFromSender,
      isLastFromSender: isLastFromSender,
      clubMembers: clubMembers,
      onReactionRemoved: onReactionRemoved,
      onReactionAdded: onReactionAdded,
      onToggleSelection: (messageId) {
        onToggleSelection(messageId);
      },
    );
  }

  Widget _buildSenderAvatar(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 6, bottom: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child:
                message.senderProfilePicture != null &&
                    message.senderProfilePicture!.isNotEmpty
                ? _buildProfilePicture(context, message.senderProfilePicture!)
                : _buildDefaultSenderAvatar(context),
          ),
        ),
        // Role badge
        if (_shouldShowRoleBadge(message.senderRole))
          Positioned(
            right: 2,
            bottom: 0,
            child: Text(
              _getRoleBadgeEmoji(message.senderRole),
              style: const TextStyle(fontSize: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildProfilePicture(BuildContext context, String profilePictureUrl) {
    // Check if the URL is an SVG
    if (profilePictureUrl.toLowerCase().contains('.svg') ||
        profilePictureUrl.toLowerCase().contains('svg?')) {
      return SvgPicture.network(
        profilePictureUrl,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildDefaultSenderAvatar(context),
      );
    } else {
      // Regular image (PNG, JPG, etc.)
      return Image.network(
        profilePictureUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultSenderAvatar(context);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildDefaultSenderAvatar(context);
        },
      );
    }
  }

  Widget _buildDefaultSenderAvatar(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          message.senderName != null && message.senderName!.isNotEmpty
              ? message.senderName!.substring(0, 1).toUpperCase()
              : 'U',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getRoleColor(context, message.senderRole ?? 'MEMBER'),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyInfo(BuildContext context, MessageReply reply, bool isOwn) {
    return GestureDetector(
      onTap: () {
        if (onReplyTap != null) {
          onReplyTap!(reply.messageId);
        }
      },
      child: Container(
        // Remove bottom margin to eliminate gap with message bubble
        margin: EdgeInsets.zero,
        width: double.infinity, // Ensure same width as message bubble
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1)),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
              // No bottom radius to connect with message bubble
            ),
            border: const Border(
              left: BorderSide(color: Color(0xFF06aeef), width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reply.senderName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF06aeef),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                reply.content,
                style: TextStyle(
                  fontSize: 13,
                  color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black.withOpacity(0.6)),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get the color associated with a user role
  Color _getRoleColor(BuildContext context, String? role) {
    switch (role?.toUpperCase()) {
      case 'OWNER':
        return Colors.purple;
      case 'ADMIN':
        return Colors.red;
      case 'CAPTAIN':
        return Colors.orange;
      case 'VICE_CAPTAIN':
        return Colors.amber;
      case 'COACH':
        return Colors.blue;
      case 'MEMBER':
      default:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]!
            : Colors.grey[600]!;
    }
  }

  /// Check if role badge should be shown
  bool _shouldShowRoleBadge(String? role) {
    final upperRole = role?.toUpperCase();
    return upperRole == 'OWNER' || upperRole == 'ADMIN';
  }

  /// Get the emoji badge for the user role
  String _getRoleBadgeEmoji(String? role) {
    try {
      final cleanRole = TextUtils.sanitizeText(role);
      switch (cleanRole?.toUpperCase()) {
        case 'OWNER':
          return '👑'; // Crown emoji
        case 'ADMIN':
          return '🛡️'; // Shield emoji
        default:
          return '';
      }
    } catch (e) {
      // Fallback for any UTF-16 issues
      debugPrint('UTF-16 error in role badge: $e');
      return '';
    }
  }
}
