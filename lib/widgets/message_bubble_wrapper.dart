import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final bool isLastFromSender;
  final String clubId;
  
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
  final Function(DragUpdateDetails details, ClubMessage message, bool isOwn) onSlideUpdate;
  final Function(DragEndDetails details, ClubMessage message, bool isOwn) onSlideEnd;
  
  // Message actions - removed, handled by bubbles themselves
  
  // Self-sending message callbacks
  final Function(ClubMessage oldMessage, ClubMessage newMessage)? onMessageUpdated;
  final Function(String messageId)? onMessageFailed;
  
  // Pending uploads for self-sending messages
  final List<PlatformFile>? pendingUploads;
  
  // Message interaction callbacks - only keep onReactionRemoved for BaseMessageBubble compatibility
  final Function(String messageId, String emoji, String userId)? onReactionRemoved;
  final bool canPinMessages;
  final bool canDeleteMessages;

  // Utility functions
  final Function(ClubMessage message) isCurrentlyPinned;

  const MessageBubbleWrapper({
    super.key,
    required this.message,
    required this.showSenderInfo,
    required this.isLastFromSender,
    required this.clubId,
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
    this.pendingUploads,
    this.onReactionRemoved,
    this.canPinMessages = false,
    this.canDeleteMessages = false,
    required this.isCurrentlyPinned,
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOwn && showSenderInfo) _buildSenderAvatar(context),
              if (!isOwn && !showSenderInfo) const SizedBox(width: 34),

              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: Stack(
                    children: [
                      // Reply icon background (shown during slide)
                      if (isSliding && slidingMessageId == message.id)
                        Positioned(
                          right: isOwn ? null : 10,
                          left: isOwn ? 10 : null,
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
                              scale: slideOffset > 50.0 ? 1.2 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              child: Icon(
                                Icons.reply,
                                color: const Color(0xFF06aeff).withOpacity(
                                  slideOffset > 50.0 ? 1.0 : 0.7,
                                ),
                                size: slideOffset > 50.0 ? 32 : 28,
                              ),
                            ),
                          ),
                        ),

                      // Message content with slide animation
                      Transform.translate(
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
                              _buildReplyInfo(context, message.replyTo!, isOwn),

                            GestureDetector(
                              // Gesture handling moved to individual bubbles
                              onPanUpdate: (isSelectionMode || message.deleted)
                                  ? null
                                  : (details) => onSlideUpdate(
                                      details,
                                      message,
                                      isOwn,
                                    ),
                              onPanEnd: (isSelectionMode || message.deleted)
                                  ? null
                                  : (details) => onSlideEnd(
                                      details,
                                      message,
                                      isOwn,
                                    ),
                              child: message.status == MessageStatus.sending
                                  ? SelfSendingMessageBubble(
                                      message: message,
                                      isOwn: isOwn,
                                      isPinned: isCurrentlyPinned(message),
                                      isDeleted: message.deleted,
                                      isSelected: selectedMessageIds.contains(
                                        message.id,
                                      ),
                                      showSenderInfo: showSenderInfo,
                                      clubId: clubId,
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
            ],
          ),
          
          // Error message display below the bubble
          if (message.status == MessageStatus.failed)
            Container(
              margin: EdgeInsets.only(
                top: 4,
                left: isOwn ? 60 : 40,
                right: isOwn ? 40 : 60,
              ),
              child: Row(
                mainAxisAlignment: isOwn 
                    ? MainAxisAlignment.end 
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Failed to send. Tap to retry.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMessage(bool isOwn) {
    return InteractiveMessageBubble(
      message: message,
      clubId: clubId,
      isOwn: isOwn,
      isPinned: isCurrentlyPinned(message),
      isSelected: selectedMessageIds.contains(message.id),
      canPinMessages: canPinMessages,
      canDeleteMessages: canDeleteMessages,
      isSelectionMode: isSelectionMode,
      showSenderInfo: showSenderInfo,
      onReactionRemoved: onReactionRemoved,
      onToggleSelection: (messageId) {
        onToggleSelection(messageId);
      },
    );
  }

  Widget _buildSenderAvatar(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(right: 6, bottom: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border.all(
          color: _getRoleColor(context, message.senderRole ?? 'MEMBER').withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: message.senderProfilePicture != null &&
                message.senderProfilePicture!.isNotEmpty
            ? _buildProfilePicture(context, message.senderProfilePicture!)
            : _buildDefaultSenderAvatar(context),
      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(6),
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
}